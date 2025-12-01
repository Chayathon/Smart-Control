const axios = require('axios');
const settingsService = require('./settings.service');

const LINE_MESSAGING_API_URL = 'https://api.line.me/v2/bot/message/push';

async function sendLineNotification(message) {
    try {
        const settings = await settingsService.getAllSettings();
        
        const lineEnabled = settings.lineNotifyEnabled ?? false;
        const channelAccessToken = settings.lineChannelAccessToken;
        const userId = settings.lineUserId;

        if (!lineEnabled) {
            console.log('📴 LINE notification disabled');
            return false;
        }

        if (!channelAccessToken || !userId) {
            console.warn('⚠️ LINE notification enabled but missing credentials (channelAccessToken or userId)');
            return false;
        }

        const payload = {
            to: userId,
            messages: [
                {
                    type: 'text',
                    text: message
                }
            ]
        };

        const response = await axios.post(LINE_MESSAGING_API_URL, payload, {
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

async function sendSongStarted(songTitle, mode = 'unknown') {
    try {
        const settings = await settingsService.getAllSettings();
        const template = settings.lineMessageStart || '🎵 กำลังเล่น: {songTitle}';
        
        const message = template
            .replace(/{songTitle}/g, songTitle)
            .replace(/{mode}/g, mode)
            .replace(/{timestamp}/g, new Date().toLocaleString('th-TH'));

        return await sendLineNotification(message);
    } catch (error) {
        console.error('❌ Error sending song started notification:', error.message);
        return false;
    }
}

async function sendSongEnded(songTitle = '', mode = 'unknown') {
    try {
        const settings = await settingsService.getAllSettings();
        const template = settings.lineMessageEnd || '⏹️ เพลงจบแล้ว{songTitle}';
        
        const songPart = songTitle ? `: ${songTitle}` : '';
        const message = template
            .replace(/{songTitle}/g, songPart)
            .replace(/{mode}/g, mode)
            .replace(/{timestamp}/g, new Date().toLocaleString('th-TH'));

        return await sendLineNotification(message);
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

        if (!settings.lineChannelAccessToken || !settings.lineUserId) {
            return { success: false, message: 'Missing LINE credentials' };
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
};
