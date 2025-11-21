// D:\mass_smart_city\Smart-Control\backend\routes\uplink.routes.js
const router = require('express').Router();
const { postUplink } = require('../controllers/uplink.controller');

// ไม่ต้องล็อกอิน เพื่อให้ทดสอบง่าย (ถ้าต้องการป้องกัน ค่อยใส่ middleware ทีหลัง)
router.post('/', postUplink);

module.exports = router;
