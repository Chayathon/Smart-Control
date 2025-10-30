// D:\mass_smart_city\Smart-Control\backend\models\DeviceData.js

const mongoose = require('mongoose');

// Schema สำหรับ Device Data ที่ส่งมาจากอุปกรณ์ IoT
const deviceDataSchema = new mongoose.Schema(
    {
        // 1. ข้อมูลหลักที่ต้องมี
        timestamp: { type: Date, required: true, index: true }, // เวลาที่บันทึกข้อมูล (สำคัญมาก)
        name: { type: String, required: true, index: true }, // ชื่ออุปกรณ์ (เช่น 'StreetLight-001')

        // 2. ข้อมูลสถานะและพิกัด (บาง Field อาจไม่มีค่าส่งมา จึงไม่ใส่ required)
        status: { type: String }, // สถานะปัจจุบัน (เช่น 'on', 'off')
        lng: { type: Number }, // ลองจิจูด
        lat: { type: Number }, // ละติจูด
        rssi: { type: Number }, // ความแรงสัญญาณ
        snr: { type: Number }, // Signal-to-Noise Ratio

        // 3. ข้อมูลพลังงานและค่าเซ็นเซอร์
        acW: { type: Number }, // กำลังไฟ AC (Watt)
        acA: { type: Number }, // กระแสไฟ AC (Ampere)
        acV: { type: Number }, // แรงดันไฟ AC (Volt)
        battery: { type: Number }, // เปอร์เซ็นต์แบตเตอรี่
        lighting: { type: Number }, // สถานะไฟส่องสว่าง (0/1)
        oat: { type: Number }, // อุณหภูมิภายนอก (Outdoor Air Temperature)

        // 4. ข้อมูล Metadata อื่นๆ ที่อาจจะมาเป็น Object
        meta: { type: mongoose.Schema.Types.Mixed }, 
    },
    // ให้ Mongoose สร้าง createdAt และ updatedAt ให้อัตโนมัติ
    { timestamps: true }
);

// สร้าง Index เพิ่มเติมเพื่อให้ค้นหาเร็วขึ้น
deviceDataSchema.index({ name: 1, timestamp: -1 });

module.exports = mongoose.model('DeviceData', deviceDataSchema);