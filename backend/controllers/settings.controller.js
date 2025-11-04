const settingsService = require('../services/settings.service');

async function getAllSettings(req, res) {
    try {
        const settings = await settingsService.getAllSettings();
        res.json({ status: 'success', data: settings });
    } catch (error) {
        console.error('Error getting all settings:', error);
        res.status(500).json({
            status: 'error',
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
                status: 'error',
                message: 'Setting not found'
            });
        }

        res.json({ status: 'success', key, value });
    } catch (error) {
        console.error('Error getting setting:', error);
        res.status(500).json({
            status: 'error',
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
                status: 'error',
                message: 'Value is required'
            });
        }

        const result = await settingsService.updateSetting(key, value);
        res.json({ status: 'success', data: result });
    } catch (error) {
        console.error('Error updating setting:', error);
        res.status(500).json({
            status: 'error',
            message: error.message || 'Failed to update setting'
        });
    }
}

async function updateMultipleSettings(req, res) {
    try {
        const settingsData = req.body;

        if (!settingsData || Object.keys(settingsData).length === 0) {
            return res.status(400).json({
                status: 'error',
                message: 'Settings data is required'
            });
        }

        const result = await settingsService.updateMultipleSettings(settingsData);
        res.json({ status: 'success', data: result });
    } catch (error) {
        console.error('Error updating multiple settings:', error);
        res.status(500).json({
            status: 'error',
            message: error.message || 'Failed to update settings'
        });
    }
}

async function resetSettings(req, res) {
    try {
        const result = await settingsService.resetSettings();
        res.json({ status: 'success', data: result });
    } catch (error) {
        console.error('Error resetting settings:', error);
        res.status(500).json({
            status: 'error',
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
