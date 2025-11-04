// D:\mass_smart_city\Smart-Control\backend\routes\deviceData.routes.js

const express = require('express');
const router = express.Router();
const controller = require('../controllers/deviceData.controller');
const { optionalAuth } = require('../middleware/auth');

// GET /deviceData  -> ดึงรายการข้อมูล DeviceData ล่าสุด 50 รายการ
router.get('/', optionalAuth, controller.getDeviceDataList); 

module.exports = router;