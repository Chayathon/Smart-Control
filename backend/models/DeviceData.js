// D:\mass_smart_city\Smart-Control\backend\models\DeviceData.js
const mongoose = require('mongoose');

// กำหนด Schema สำหรับ Collection deviceData (แบบ simplified ตาม requirement ล่าสุด)
const deviceDataSchema = new mongoose.Schema(
  {
    timestamp: { type: Date, required: true },

    // meta ใช้เก็บข้อมูลประกอบ เช่น no, deviceId ฯลฯ
    meta: { type: Object, default: {} },

    dcV: { type: Number }, // แรงดัน DC Volt
    dcW: { type: Number }, // กำลังไฟ DC Watt
    dcA: { type: Number }, // กระแส DC Ampere

    oat: { type: Number }, // อุณหภูมิภายนอก

    lat: { type: Number },
    lng: { type: Number },

    type: { type: String }, // เช่น "sim", "wireless" ฯลฯ

    // เก็บค่า flag ดิบ เช่น "$111110" หรือ "$0000"
    flag: { type: String },
  },
  {
    collection: 'deviceData',
    timestamps: false,
    versionKey: false,
  }
);

// index สำหรับ query ล่าสุด / กราฟ
deviceDataSchema.index({ timestamp: -1 });

module.exports = mongoose.model('DeviceData', deviceDataSchema);

