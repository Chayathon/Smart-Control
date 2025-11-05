const {
    seedDevices,
    listDevices,
    clearDevices,
    appendDevices,
    setStreamEnabled,
    getStreamEnabled,
} = require('../services/device.service');
const stream = require('../services/stream.service');

async function postSeed(req, res) {
    try {
        const { count, startAt, reset } = req.body || {};
        const result = await seedDevices({
            count: Number(count),
            startAt: startAt ? Number(startAt) : undefined,
            reset: !!reset,
        });
        res.json({ ok: true, ...result });
    } catch (e) {
        res.status(400).json({ ok: false, error: e.message });
    }
}

async function getList(req, res) {
    const items = await listDevices();
    res.json(items);
}

async function deleteAll(req, res) {
    const result = await clearDevices();
    res.json({ ok: true, ...result });
}

async function postAppend(req, res) {
    try {
        const { count } = req.body || {};
        const result = await appendDevices({ count: Number(count) });
        res.json({ ok: true, ...result });
    } catch (e) {
        res.status(400).json({ ok: false, error: e.message });
    }
}
 
async function putStreamEnabled(req, res) {
    try {
        const { enabled } = req.body || {};
        const flag = !!enabled;
        const result = await setStreamEnabled(flag);
        
        if (!flag) {
            try { await stream.stopAll(); } catch (_) {}
        }
        const payload = { status: 'success', enabled: result.enabled };
        if (flag && result.enabledZones) payload.enabledZones = result.enabledZones;
        res.json(payload);
    } catch (e) {
        res.status(400).json({ status: 'error', message: e.message });
    }
}

async function getStreamEnabledCtrl(_req, res) {
    try {
        const enabled = await getStreamEnabled();
        res.json({ status: 'success', enabled });
    } catch (e) {
        res.status(500).json({ status: 'error', message: e.message });
    }
}

module.exports = { postSeed, getList, deleteAll, postAppend, getStreamEnabledCtrl, putStreamEnabled };
