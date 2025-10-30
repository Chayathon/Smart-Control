// D:\mass_smart_city\Smart-Control\backend\services\deviceData.service.js

const DeviceData = require('../models/DeviceData'); // นำเข้า Model ใหม่

/**
 * ฟังก์ชันสำหรับดึงรายการข้อมูล DeviceData ทั้งหมด
 */
async function listDeviceData() {
    // ใช้ .find() เพื่อดึงเอกสารทั้งหมด
    // เรียงตาม timestamp ล่าสุดขึ้นก่อน
    return DeviceData.find()
        .sort({ timestamp: -1 }) 
        .lean();
}

module.exports = {
    listDeviceData,
};