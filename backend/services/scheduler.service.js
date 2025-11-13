const Schedule = require('../models/Schedule');
const Song = require('../models/Song');
const Device = require('../models/Device');
const stream = require('./stream.service');
const bus = require('./bus');
const path = require('path');

let schedulerInterval = null;
let currentScheduleId = null;
let currentScheduleTrack = null;
let isSchedulePlaying = false;
let lastPlayedScheduleId = null;
let lastPlayedTime = null; // เก็บเวลาที่เล่นล่าสุด (HH:mm)

// Priority: 1=Mic, 2=Schedule, 3=Playlist/File/YouTube
const PRIORITY = {
    MIC: 1,
    SCHEDULE: 2,
    NORMAL: 3
};

function daysMapping(dayNum) {
    // 0=Sunday, 1=Monday, ... 6=Saturday
    return dayNum;
}

async function checkAndPlaySchedules() {
    try {
        const now = new Date();
        const currentDay = now.getDay(); // 0=Sunday, 1=Monday, etc.
        const currentTime = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;
        
        console.log(`🕐 Schedule check: Day=${currentDay}, Time=${currentTime}`);

        // ดึง schedules ที่ active และตรงกับวันและเวลาปัจจุบัน
        const schedules = await Schedule.find({
            is_active: true,
            days_of_week: currentDay,
            time: currentTime
        }).populate('id_song').lean();

        if (schedules.length === 0) {
            // ถ้าเวลาเปลี่ยนไปแล้ว ให้ reset lastPlayedTime
            if (lastPlayedTime && lastPlayedTime !== currentTime) {
                lastPlayedTime = null;
                lastPlayedScheduleId = null;
                console.log('🔄 Time changed, reset schedule tracking');
            }
            return;
        }

        console.log(`📅 Found ${schedules.length} schedule(s) to play`);

        // เล่น schedule แรกที่เจอ
        const schedule = schedules[0];
        
        // ป้องกันเล่นซ้ำ: ถ้าเคยเล่น schedule นี้ในเวลานี้แล้ว ให้ข้าม
        if (lastPlayedScheduleId === schedule._id.toString() && lastPlayedTime === currentTime) {
            console.log(`⏭️ Already played schedule ${schedule._id} at ${currentTime}, skipping`);
            return;
        }

        // ป้องกันเล่นซ้ำ: ถ้ากำลังเล่น schedule อยู่ ให้ข้าม
        if (isSchedulePlaying && currentScheduleId === schedule._id.toString()) {
            console.log(`⏯️ Schedule ${schedule._id} is already playing, skipping`);
            return;
        }

        // เช็ค priority ก่อนเล่น
        const canPlay = await checkPriority();
        if (!canPlay.allowed) {
            console.log(`⚠️ Schedule skipped: ${canPlay.reason}`);
            return;
        }

        // บันทึกว่าเล่น schedule นี้แล้ว
        lastPlayedScheduleId = schedule._id.toString();
        lastPlayedTime = currentTime;

        await playSchedule(schedule);

    } catch (err) {
        console.error('❌ Error in checkAndPlaySchedules:', err);
    }
}

async function checkPriority() {
    try {
        // เช็คว่าไมค์เปิดอยู่หรือไม่
        const isMicActive = stream.isMicActive();
        
        // Priority 1: ถ้าไมค์เปิดอยู่ ให้ข้าม schedule
        if (isMicActive) {
            return { allowed: false, reason: 'Microphone is active (Priority 1)' };
        }

        return { allowed: true };
    } catch (err) {
        console.error('Error checking priority:', err);
        return { allowed: false, reason: 'Error checking priority' };
    }
}

async function playSchedule(schedule) {
    try {
        if (!schedule.id_song) {
            console.log('⚠️ Schedule has no song attached');
            return;
        }

        const song = schedule.id_song;
        console.log(`🎵 Playing schedule: ${song.name || song.title}`);

        // หยุดการเล่นปัจจุบัน (ถ้ามี) และรอ 8 วินาที
        const currentStatus = stream.getStatus();
        if (currentStatus.isPlaying && currentStatus.activeMode !== 'mic') {
            console.log('⏹️ Stopping current playback for schedule');
            await stream.stop();
            console.log('⏳ Waiting 8 seconds before starting schedule...');
            await sleep(8000); // รอ 8 วินาที
        }

        // กำหนดค่า schedule state
        isSchedulePlaying = true;
        currentScheduleId = schedule._id;
        currentScheduleTrack = {
            scheduleId: schedule._id.toString(),
            songName: song.name || song.title,
            time: schedule.time,
            days: schedule.days_of_week,
            description: schedule.description
        };

        // อัปเดตสถานะ Device
        await updateDeviceStatus(true, 'schedule');

        // เล่นเพลงจาก song
        const songUrl = song.url || song.file || '';
        const filePath = path.join(__dirname, '../uploads', songUrl);
        const displayName = song.name || song.title || songUrl;

        // Emit event ให้ frontend รู้ว่า schedule กำลังเล่น
        emitScheduleStatus('schedule-started', currentScheduleTrack);

        // เล่นเพลง
        await stream.startLocalFile(filePath, 0, { 
            displayName,
            isSchedule: true 
        });

        // เพลงจะจบเมื่อ FFmpeg จบการทำงาน (จะถูกจัดการโดย stream.service)

    } catch (err) {
        console.error('❌ Error playing schedule:', err);
        isSchedulePlaying = false;
        currentScheduleId = null;
        currentScheduleTrack = null;
        await updateDeviceStatus(false, 'none');
        emitScheduleStatus('schedule-error', { error: err.message });
    }
}

async function endSchedulePlayback() {
    try {
        isSchedulePlaying = false;
        const finishedSchedule = currentScheduleTrack;
        currentScheduleId = null;
        currentScheduleTrack = null;

        // อัปเดตสถานะ Device
        await updateDeviceStatus(false, 'none');

        // Emit event
        emitScheduleStatus('schedule-ended', finishedSchedule);

        console.log('🏁 Schedule playback ended, is_playing set to false');
        
        // Note: ไม่ reset lastPlayedScheduleId และ lastPlayedTime ที่นี่
        // เพื่อป้องกันเล่นซ้ำในนาทีเดียวกัน
    } catch (err) {
        console.error('Error ending schedule playback:', err);
    }
}

async function stopSchedulePlayback() {
    try {
        if (!isSchedulePlaying) {
            return { success: false, message: 'No schedule is playing' };
        }

        console.log('⏹️ Manually stopping schedule playback');
        
        await stream.stop();
        await endSchedulePlayback();

        // Reset tracking เมื่อหยุดด้วยตัวเอง
        lastPlayedScheduleId = null;
        lastPlayedTime = null;

        return { success: true, message: 'Schedule stopped' };
    } catch (err) {
        console.error('Error stopping schedule:', err);
        throw err;
    }
}

async function updateDeviceStatus(isPlaying, mode) {
    try {
        // อัปเดตทุก device
        await Device.updateMany(
            {},
            {
                $set: {
                    'status.is_playing': isPlaying,
                    'status.playback_mode': mode
                }
            }
        );
    } catch (err) {
        console.error('Error updating device status:', err);
    }
}

function emitScheduleStatus(event, data) {
    bus.emit('schedule-status', {
        event,
        isPlaying: isSchedulePlaying,
        currentSchedule: currentScheduleTrack,
        ...data
    });
}

function getScheduleStatus() {
    return {
        isPlaying: isSchedulePlaying,
        currentSchedule: currentScheduleTrack,
        currentScheduleId: currentScheduleId
    };
}

function startScheduler() {
    if (schedulerInterval) {
        console.log('⚠️ Scheduler already running');
        return;
    }

    console.log('🚀 Starting schedule checker (smart timing for instant playback)');
    
    // Reset tracking variables
    lastPlayedScheduleId = null;
    lastPlayedTime = null;
    
    // ฟังก์ชันคำนวณเวลาถัดไปที่ต้องเช็ค (ต้นนาทีถัดไป)
    function scheduleNextCheck() {
        const now = new Date();
        const seconds = now.getSeconds();
        const milliseconds = now.getMilliseconds();
        
        // คำนวณเวลาที่เหลือจนถึงต้นนาทีถัดไป (XX:XX:00.000)
        const msUntilNextMinute = (60 - seconds) * 1000 - milliseconds;
        
        console.log(`⏱️ Next check in ${(msUntilNextMinute / 1000).toFixed(1)} seconds`);
        
        setTimeout(() => {
            checkAndPlaySchedules();
            // ตั้งเวลาเช็ครอบถัดไป (ทุก 1 นาทีพอดี)
            schedulerInterval = setInterval(checkAndPlaySchedules, 60 * 1000);
        }, msUntilNextMinute);
    }
    
    // เช็คทันทีเมื่อเริ่มต้น
    checkAndPlaySchedules();
    
    // จากนั้นตั้งเวลาให้เช็คที่ต้นนาทีถัดไป
    scheduleNextCheck();
}

function stopScheduler() {
    if (schedulerInterval) {
        clearInterval(schedulerInterval);
        schedulerInterval = null;
        console.log('🛑 Scheduler stopped');
    }
}

// ฟังก์ชันสำหรับเช็คว่าต้องหยุด schedule เพื่อให้ mic เล่นหรือไม่
function checkMicPriority() {
    if (isSchedulePlaying) {
        console.log('🎤 Mic priority detected, stopping schedule');
        stopSchedulePlayback();
    }
}

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

module.exports = {
    startScheduler,
    stopScheduler,
    checkAndPlaySchedules,
    stopSchedulePlayback,
    getScheduleStatus,
    checkMicPriority,
    get isSchedulePlaying() { return isSchedulePlaying; },
    get currentScheduleTrack() { return currentScheduleTrack; }
};
