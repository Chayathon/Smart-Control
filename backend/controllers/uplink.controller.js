// D:\mass_smart_city\Smart-Control\backend\controllers\uplink.controller.js
const deviceDataService = require('../services/deviceData.service');

async function postUplink(req, res) {
  try {
    const payload = req.body || {};
    await deviceDataService.ingestOne(payload);
    res.json({ status: 'success' });
  } catch (e) {
    console.error('[uplink.controller] error:', e);
    res.status(500).json({ status: 'error', message: e.message || 'ingest failed' });
  }
}

module.exports = { postUplink };
