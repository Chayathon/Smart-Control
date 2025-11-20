// D:\mass_smart_city\Smart-Control\backend\models\DeviceData.js
const mongoose = require('mongoose');

// กำหนด Schema สำหรับ Collection deviceData
const deviceDataSchema = new mongoose.Schema(
  {
    timestamp: { type: Date, required: true },

    // meta ไว้เก็บข้อมูลประกอบ เช่น no, deviceId, topic ฯลฯ
    meta: { type: Object, default: {} },

    dcV: { type: Number }, // แรงดัน DC Volt
    dcW: { type: Number }, // กำลังไฟ DC Watt
    dcA: { type: Number }, // กระแส DC Ampere

    oat: { type: Number }, // อุณหภูมิภายนอก

    lat: { type: Number },
    lng: { type: Number },

    type: { type: String }, // เช่น "sim", "wireless" etc.
    flag: { type: String }, // เก็บค่าดิบ เช่น "$111110"
  },
  {
    collection: 'deviceData',

    // ❌ ไม่ให้ Mongoose สร้าง createdAt / updatedAt ให้เอง
    timestamps: false,

    // ❌ ไม่เอา __v
    versionKey: false,
  }
);

// index ที่น่าจะใช้บ่อย
deviceDataSchema.index({ timestamp: -1 });
deviceDataSchema.index({ 'meta.no': 1, timestamp: -1 });

module.exports = mongoose.model('DeviceData', deviceDataSchema);
