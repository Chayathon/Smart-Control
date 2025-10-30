// D:\mass_smart_city\Smart-Control\backend\routes\deviceData.routes.js

const express = require('express');
const router = express.Router();
const { getDeviceDataList } = require('../controllers/deviceData.controller');
const { authenticateToken } = require('../middleware/auth');

// ใน deviceData.routes.js
// router.get('/', authenticateToken, getDeviceDataList); // เดิม
router.get('/', getDeviceDataList); // <<< แก้ไขเป็นแบบนี้ชั่วคราว

module.exports = router;