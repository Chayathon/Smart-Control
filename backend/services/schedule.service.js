const Schedule = require('../models/Schedule');

// convert "HH:mm" or "HH:mm:ss" to minutes since midnight
function timeStrToMinutes(timeStr) {
    if (!timeStr || typeof timeStr !== 'string') return null;
    const parts = timeStr.split(':').map(p => parseInt(p, 10));
    if (parts.length < 2 || parts.some(isNaN)) return null;
    const hours = parts[0];
    const minutes = parts[1];
    return hours * 60 + minutes;
}

// circular minute difference (handles midnight wrap)
function minuteDiff(a, b) {
    const diff = Math.abs(a - b);
    return Math.min(diff, 1440 - diff);
}

async function getSchedules() {
    try {
        const schedules = await Schedule.find().populate('id_song');
        return schedules;
    } catch (err) {
        console.error('Error in getSchedules:', err);
        throw err;
    }
}

async function getScheduleById(id) {
    try {
        const schedule = await Schedule.findById(id).populate('id_song');
        return schedule;
    } catch (err) {
        console.error('Error in getSchedule:', err);
        throw err;
    }
}

async function saveSchedule(schedule) {
    try {
        const newSchedule = new Schedule(schedule);

        if (Array.isArray(schedule.days_of_week) && schedule.days_of_week.length && schedule.time) {
            const newMinutes = timeStrToMinutes(schedule.time);
            if (newMinutes === null) {
                throw new Error('Invalid time format for schedule.time');
            }

            const candidates = await Schedule.find({
                days_of_week: { $in: schedule.days_of_week },
                is_active: true,
            });

            for (const cand of candidates) {
                const candMinutes = timeStrToMinutes(cand.time);
                if (candMinutes === null) continue; // skip malformed
                if (minuteDiff(newMinutes, candMinutes) <= 5) {
                    const err = new Error('ไม่สามารถเพิ่มเพลงตั้งเวลาได้เนื่องจากมีรายการอื่นอยู่ใกล้เวลา (+-5 นาที)');
                    err.status = 400;
                    throw err;
                }
            }
        }

        const savedSchedule = await newSchedule.save();

        return {
            success: true,
            message: 'บันทึกเพลงตั้งเวลาเรียบร้อย',
            data: savedSchedule,
        };
    } catch (err) {
        console.error('Error in saveSchedule:', err);
        throw err;
    }
}

async function updateSchedule(id, schedule) {
    try {
        if ((Array.isArray(schedule.days_of_week) && schedule.days_of_week.length) || schedule.time) {
            const existing = await Schedule.findById(id);
            if (!existing) {
                throw new Error('Schedule not found');
            }

            const days = Array.isArray(schedule.days_of_week) && schedule.days_of_week.length ? schedule.days_of_week : existing.days_of_week;
            const timeStr = schedule.time ? schedule.time : existing.time;
            const newMinutes = timeStrToMinutes(timeStr);
            if (newMinutes === null) {
                throw new Error('Invalid time format for schedule.time');
            }

            const candidates = await Schedule.find({
                _id: { $ne: id },
                days_of_week: { $in: days },
                is_active: true,
            });

            for (const cand of candidates) {
                const candMinutes = timeStrToMinutes(cand.time);
                if (candMinutes === null) continue;
                if (minuteDiff(newMinutes, candMinutes) <= 5) {
                    const err = new Error('ไม่สามารถอัปเดตเพลงตั้งเวลาได้เนื่องจากมีรายการอื่นอยู่ใกล้เวลา (+-5 นาที)');
                    err.status = 400;
                    throw err;
                }
            }
        }

        const updatedSchedule = await Schedule.findByIdAndUpdate(
            id,
            schedule,
            { new: true }
        );

        if (!updatedSchedule) {
            throw new Error('Schedule not found');
        }

        return {
            success: true,
            message: 'อัปเดตเพลงตั้งเวลาเรียบร้อย',
            data: updatedSchedule,
        };
    } catch (err) {
        console.error('Error in updateSchedule:', err);
        throw err;
    }
}

async function changeScheduleStatus(id, isActive) {
    try {
        const updatedSchedule = await Schedule.findByIdAndUpdate(
            id,
            { is_active: isActive },
            { new: true }
        );

        if (!updatedSchedule) {
            throw new Error('Schedule not found');
        }

        return {
            success: true,
            message: 'เปลี่ยนสถานะเพลงตั้งเวลาเรียบร้อย',
            data: updatedSchedule,
        };
    } catch (err) {
        console.error('Error in changeScheduleStatus:', err);
        throw err;
    }
}

async function deleteSchedule(id) {
    try {
        const deletedSchedule = await Schedule.findByIdAndDelete(id);

        if (!deletedSchedule) {
            throw new Error('Schedule not found');
        }

        return {
            success: true,
            message: 'ลบเพลงตั้งเวลาเรียบร้อย',
        }
    } catch (err) {
        console.error('Error in deleteSchedule:', err);
        throw err;
    }
}

module.exports = { getSchedules, getScheduleById, saveSchedule, updateSchedule, changeScheduleStatus, deleteSchedule };