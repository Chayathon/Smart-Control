// D:\mass_smart_city\Smart-Control\backend\controllers\deviceData.controller.js
const deviceDataService = require('../services/deviceData.service');

// GET /deviceData → ดึงล่าสุด
async function getDeviceDataList(req, res) {
  try {
    const list = await deviceDataService.getDeviceDataList();
    res.json({ status: 'success', data: list });
  } catch (error) {
    console.error('Error getting device data list:', error);
    res.status(500).json({
      status: 'error',
      message: error.message || 'get device data list failed',
    });
  }
}

// POST /deviceData → ingest + broadcast (วิธีที่ 1)
async function postIngest(req, res) {
  try {
    const body = req.body;
    if (!body) {
      return res.status(400).json({ status: 'error', message: 'body is required' });
    }
    if (Array.isArray(body)) {
      const created = await deviceDataService.ingestMany(body);
      return res.json({ status: 'success', count: created.length });
    } else {
      const created = await deviceDataService.ingestOne(body);
      return res.json({ status: 'success', id: created._id });
    }
  } catch (e) {
    console.error('Error postIngest:', e);
    res.status(500).json({ status: 'error', message: e.message });
  }
}

module.exports = { getDeviceDataList, postIngest };
