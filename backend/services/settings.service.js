const Settings = require('../models/Settings');

const DEFAULT_SETTINGS = {
    sampleRate: 44100,
    loopPlaylist: false,
};

async function getAllSettings() {
    const settings = await Settings.find().lean();
    
    const settingsObj = {};
    settings.forEach(item => {
        settingsObj[item.key] = item.value;
    });

    return { ...DEFAULT_SETTINGS, ...settingsObj };
}

async function getSetting(key) {
    const setting = await Settings.findOne({ key }).lean();
    
    if (!setting) {
        return DEFAULT_SETTINGS[key] ?? null;
    }

    return setting.value;
}

async function updateSetting(key, value) {
    const result = await Settings.findOneAndUpdate(
        { key },
        { key, value },
        { upsert: true, new: true }
    ).lean();

    return result;
}

async function updateMultipleSettings(settingsData) {
    const operations = Object.entries(settingsData).map(([key, value]) => ({
        updateOne: {
            filter: { key },
            update: { $set: { key, value } },
            upsert: true,
        }
    }));

    await Settings.bulkWrite(operations);

    return getAllSettings();
}

async function resetSettings() {
    await Settings.deleteMany({});
    
    const operations = Object.entries(DEFAULT_SETTINGS).map(([key, value]) => ({
        updateOne: {
            filter: { key },
            update: { $set: { key, value } },
            upsert: true,
        }
    }));

    await Settings.bulkWrite(operations);

    return DEFAULT_SETTINGS;
}

module.exports = {
    getAllSettings,
    getSetting,
    updateSetting,
    updateMultipleSettings,
    resetSettings,
};
