// D:\mass_smart_city\Smart-Control\backend\services\deviceData.service.js

const DeviceData = require('../models/DeviceData'); // ดึง Model มาใช้งาน

// ฟังก์ชันสำหรับดึงรายการข้อมูล DeviceData ทั้งหมด (หรือจะจำกัดจำนวนก็ได้)
async function getDeviceDataList() {
    // ใช้ .find({}) เพื่อดึงเอกสารทั้งหมด
    // .sort({ timestamp: -1 }) เพื่อเรียงลำดับจากล่าสุดไปเก่าสุด
    // .limit(50) เพื่อจำกัดให้ดึงมาแค่ 50 รายการล่าสุด
    const list = await DeviceData.find({})
        .sort({ timestamp: -1 }) 
        .limit(50)
        .lean(); // .lean() ช่วยให้ข้อมูลที่ได้เป็น JavaScript Object ธรรมดา ทำให้เร็วกว่า

    return list;
}

// ฟังก์ชันสำหรับดึงข้อมูล DeviceData ล่าสุด 1 รายการ
async function getLatestDeviceData() {
    const latestData = await DeviceData.findOne({})
        .sort({ timestamp: -1 })
        .lean();
    
    // ถ้าไม่พบข้อมูลจะคืนค่าเป็น null
    return latestData;
}


module.exports = { getDeviceDataList, getLatestDeviceData };