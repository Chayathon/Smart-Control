const Device = require('../models/Device');

async function seedDevices({ count, startAt = 1, reset = false }) {
    if (!count || count < 1) {
        throw new Error('count ต้องมากกว่า 0');
    }

    if (reset) {
        await Device.deleteMany({});
    }

    const ops = Array.from({ length: count }, (_, i) => {
        const no = startAt + i;
        return {
            updateOne: {
                filter: { no },
                update: { $setOnInsert: { no } },
                upsert: true,
            },
        };
    });

    const result = await Device.bulkWrite(ops, { ordered: false });


    const inserted =
        (result.upsertedCount ?? 0) ||
        (result.result && result.result.upserted ? result.result.upserted.length : 0);

    const total = await Device.countDocuments();

    return { inserted, total };
}

async function listDevices() {
    return Device.find().sort({ no: 1 }).lean();
}

async function clearDevices() {
    const res = await Device.deleteMany({});
    return { deleted: res.deletedCount || 0 };
}


async function appendDevices({ count }) {
    if (!count || count < 1) throw new Error('count ต้องมากกว่า 0');

    const last = await Device.findOne().sort({ no: -1 }).lean();
    const startAt = last ? last.no + 1 : 1;
    return seedDevices({ count, startAt, reset: false });
}

async function setStreamEnabled(enabled) {
    const mqtt = require('./mqtt.service');
    if (enabled) {
        try { mqtt.publish('mass-radio/all/command', { set_stream: true }); } catch (_) {}

        await new Promise(r => setTimeout(r, 1200));
        const enabledDevices = await Device.find({ 'status.stream_enabled': true }, { no: 1 }).lean();
        const enabledZones = enabledDevices.map(d => d.no).sort((a,b)=>a-b);
        return { enabled: true, enabledZones };
    }
    
    const res = await Device.updateMany({}, {
        $set: {
            'status.stream_enabled': false,
            'status.is_playing': false,
            'status.playback_mode': 'none',
        },
    });
    try { mqtt.publish('mass-radio/all/command', { set_stream: false }); } catch (_) {}
    return { matched: res.matchedCount ?? res.n, modified: res.modifiedCount ?? res.nModified, enabled: false };
}

async function getStreamEnabled() {
    const any = await Device.findOne({}, { 'status.stream_enabled': 1 }).lean();
    return !!(any && any.status && any.status.stream_enabled);
}

module.exports = {
    seedDevices,
    listDevices,
    clearDevices,
    appendDevices,
    setStreamEnabled,
    getStreamEnabled,
};
