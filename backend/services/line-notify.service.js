const axios = require('axios');
const settingsService = require('./settings.service');

const LINE_BROADCAST_API_URL = 'https://api.line.me/v2/bot/message/broadcast';

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

async function sendSongStarted(songTitle, mode = 'unknown') {
    try {
        const settings = await settingsService.getAllSettings();
        const template = settings.lineMessageStart || '🎵 กำลังเล่น: {songTitle}';
        
        const message = template
            .replace(/{songTitle}/g, songTitle)
            .replace(/{mode}/g, mode)
            .replace(/{timestamp}/g, new Date().toLocaleString('th-TH'));

        console.log('📤 Sending LINE notification (Song Started):', message);
        const result = await sendLineNotification(message);
        if (result) {
            console.log('✅ LINE notify sent: Song Started -', songTitle);
        }
        return result;
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

        console.log('📤 Sending LINE notification (Song Ended):', message);
        const result = await sendLineNotification(message);
        if (result) {
            console.log('✅ LINE notify sent: Song Ended -', songTitle || 'Unknown');
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
};
