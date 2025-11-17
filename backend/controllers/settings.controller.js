const settingsService = require('../services/settings.service');

async function getAllSettings(req, res) {
    try {
        const settings = await settingsService.getAllSettings();
        res.json({ ok: true, data: settings });
    } catch (error) {
        console.error('Error getting all settings:', error);
        res.status(500).json({
            ok: false,
            message: error.message || 'Failed to get settings'
        });
    }
}

async function getSetting(req, res) {
    try {
        const { key } = req.params;
        const value = await settingsService.getSetting(key);
        
        if (value === null) {
            return res.status(404).json({
                ok: false,
                message: 'Setting not found'
            });
        }

        res.json({ ok: true, key, value });
    } catch (error) {
        console.error('Error getting setting:', error);
        res.status(500).json({
            ok: false,
            message: error.message || 'Failed to get setting'
        });
    }
}

async function updateSetting(req, res) {
    try {
        const { key } = req.params;
        const { value } = req.body;

        if (value === undefined) {
            return res.status(400).json({
                ok: false,
                message: 'Value is required'
            });
        }

        let storeValue = value;
        if (key === 'micVolume') {
            const num = Number(value);
            if (!Number.isNaN(num)) {
                storeValue = Math.round(num * 10) / 10;
            }
        }

        const result = await settingsService.updateSetting(key, storeValue);
        res.json({ ok: true, data: result });
    } catch (error) {
        console.error('Error updating setting:', error);
        res.status(500).json({
            ok: false,
            message: error.message || 'Failed to update setting'
        });
    }
}

async function updateMultipleSettings(req, res) {
    try {
        const settingsData = req.body;

        if (!settingsData || Object.keys(settingsData).length === 0) {
            return res.status(400).json({
                ok: false,
                message: 'Settings data is required'
            });
        }

        if (Object.prototype.hasOwnProperty.call(settingsData, 'micVolume')) {
            const num = Number(settingsData.micVolume);
            if (!Number.isNaN(num)) {
                settingsData.micVolume = Math.round(num * 10) / 10;
            }
        }

        const result = await settingsService.updateMultipleSettings(settingsData);
        res.json({ ok: true, data: result });
    } catch (error) {
        console.error('Error updating multiple settings:', error);
        res.status(500).json({
            ok: false,
            message: error.message || 'Failed to update settings'
        });
    }
}

async function resetSettings(req, res) {
    try {
        const result = await settingsService.resetSettings();
        res.json({ ok: true, data: result });
    } catch (error) {
        console.error('Error resetting settings:', error);
        res.status(500).json({
            ok: false,
            message: error.message || 'Failed to reset settings'
        });
    }
}

module.exports = {
    getAllSettings,
    getSetting,
    updateSetting,
    updateMultipleSettings,
    resetSettings,
};
