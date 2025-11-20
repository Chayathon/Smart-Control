// D:\mass_smart_city\Smart-Control\backend\routes\deviceData.routes.js
const express = require('express');
const router = express.Router();
const controller = require('../controllers/deviceData.controller');
const { optionalAuth } = require('../middleware/auth');

// ดึงรายการล่าสุด
router.get('/', optionalAuth, controller.getDeviceDataList);

// วิธีที่ 1: ingest แล้ว broadcast อัตโนมัติ
router.post('/', optionalAuth, controller.postIngest);

module.exports = router;
