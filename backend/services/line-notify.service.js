const axios = require('axios');
const settingsService = require('./settings.service');

const LINE_BROADCAST_API_URL = 'https://api.line.me/v2/bot/message/broadcast';

let hasNotifiedStart = false;
let lastActiveMode = 'unknown';

function canNotifyStart() {
    return !hasNotifiedStart;
}

function canNotifyEnd() {
    return hasNotifiedStart;
}

function markStartNotified(mode = 'unknown') {
    hasNotifiedStart = true;
    lastActiveMode = mode;
}

function markEndNotified() {
    hasNotifiedStart = false;
}

function getLastActiveMode() {
    return lastActiveMode;
}

function getMode(mode) {
    const modeMap = {
        'playlist': 'รายการเพลง',
        'file': 'ไฟล์เพลง',
        'youtube': 'YouTube',
        'schedule': 'เพลงตั้งเวลา',
        'mic': 'ไมโครโฟน'
    };
    return modeMap[mode] || mode;
}

function getNotificationState() {
    return { hasNotifiedStart, lastActiveMode };
}

async function sendLineNotification(message) {
    try {
        const settings = await settingsService.getAllSettings();
        
        const lineEnabled = settings.lineNotifyEnabled ?? false;
        const channelAccessToken = settings.lineChannelAccessToken;

        if (!lineEnabled) {
            console.log('📴 LINE notification disabled');
            return false;
        }

        if (!channelAccessToken) {
            console.warn('⚠️ LINE notification enabled but missing Channel Access Token');
            return false;
        }

        const payload = {
            messages: [
                {
                    type: 'text',
                    text: message
                }
            ]
        };

        const response = await axios.post(LINE_BROADCAST_API_URL, payload, {
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${channelAccessToken}`
            },
            timeout: 10000
        });

        if (response.status === 200) {
            console.log('✅ LINE notification sent successfully');
            return true;
        } else {
            console.warn(`⚠️ LINE notification failed with status: ${response.status}`);
            return false;
        }
    } catch (error) {
        if (error.response) {
            console.error('❌ LINE API error:', error.response.status, error.response.data);
        } else if (error.request) {
            console.error('❌ LINE API no response:', error.message);
        } else {
            console.error('❌ LINE notification error:', error.message);
        }
        return false;
    }
}

async function sendSongStarted(song, mode = 'unknown') {
    try {
        const settings = await settingsService.getAllSettings();
        const template = settings.lineMessageStart || '🟢 เริ่มถ่ายทอดสด {mode}! {date} 🎵';
        
        const now = new Date();
        const dateStr = now.toLocaleDateString('th-TH', { year: 'numeric', month: 'long', day: 'numeric' });
        const timeStr = now.toLocaleTimeString('th-TH', { hour: '2-digit', minute: '2-digit', second: '2-digit' });
        
        const modeThai = getMode(mode);
        const message = template
            .replace(/{song}/g, song)
            .replace(/{mode}/g, modeThai)
            .replace(/{date}/g, dateStr)
            .replace(/{time}/g, timeStr)
            .replace(/{timestamp}/g, now.toLocaleString('th-TH'));

        console.log('📤 Sending LINE notification (Song Started):', message);
        const result = await sendLineNotification(message);
        if (result) {
            console.log('✅ LINE notify sent: Song Started');
        }
        return result;
    } catch (error) {
        console.error('❌ Error sending song started notification:', error.message);
        return false;
    }
}

async function sendSongEnded(song = '', mode = 'unknown') {
    try {
        const settings = await settingsService.getAllSettings();
        const template = settings.lineMessageEnd || '🔴 หยุดการถ่ายทอดสด {date}';
        
        const now = new Date();
        const dateStr = now.toLocaleDateString('th-TH', { year: 'numeric', month: 'long', day: 'numeric' });
        const timeStr = now.toLocaleTimeString('th-TH', { hour: '2-digit', minute: '2-digit', second: '2-digit' });
        
        // ใช้โหมดที่เก็บไว้ตอน start ถ้าโหมดที่ส่งมาเป็น none หรือ unknown
        const actualMode = (mode === 'none' || mode === 'unknown') ? lastActiveMode : mode;
        const modeThai = getMode(actualMode);
        
        const songPart = song ? `: ${song}` : '';
        const message = template
            .replace(/{song}/g, songPart)
            .replace(/{mode}/g, modeThai)
            .replace(/{date}/g, dateStr)
            .replace(/{time}/g, timeStr)
            .replace(/{timestamp}/g, now.toLocaleString('th-TH'));

        console.log('📤 Sending LINE notification (Song Ended):', message);
        const result = await sendLineNotification(message);
        if (result) {
            console.log('✅ LINE notify sent: Song Ended');
        }
        return result;
    } catch (error) {
        console.error('❌ Error sending song ended notification:', error.message);
        return false;
    }
}

async function testNotification() {
    try {
        const settings = await settingsService.getAllSettings();
        
        if (!settings.lineNotifyEnabled) {
            return { success: false, message: 'LINE notification is disabled' };
        }

        if (!settings.lineChannelAccessToken) {
            return { success: false, message: 'Missing Channel Access Token' };
        }

        const testMessage = `🔔 ทดสอบการแจ้งเตือน LINE\n⏰ เวลา: ${new Date().toLocaleString('th-TH')}`;
        const result = await sendLineNotification(testMessage);

        if (result) {
            return { success: true, message: 'Test notification sent successfully' };
        } else {
            return { success: false, message: 'Failed to send test notification' };
        }
    } catch (error) {
        return { success: false, message: error.message };
    }
}

module.exports = {
    sendSongStarted,
    sendSongEnded,
    testNotification,
    canNotifyStart,
    canNotifyEnd,
    markStartNotified,
    markEndNotified,
    getLastActiveMode,
    getNotificationState,
};
