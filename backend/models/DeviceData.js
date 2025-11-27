// // D:\mass_smart_city\Smart-Control\backend\models\DeviceData.js

// const mongoose = require('mongoose');

// // กำหนด Schema สำหรับ Collection deviceData
// // เราจะระบุฟิลด์ที่สำคัญเพื่อให้ Mongoose รู้จัก
// const deviceDataSchema = new mongoose.Schema(
//     {
//         // timestamp: { type: Date, required: true },
//         // meta: { type: Object }, // เก็บข้อมูล Object ภายใน เช่น name
//         acW: { type: Number }, // กำลังไฟ AC Watt
//         no: {type: Number},
//         // status: { type: String }, // สถานะ on/off
//         oat: { type: Number }, // อุณหภูมิภายนอก (Outdoor Ambient Temperature)
//         // lighting: { type: Number },
//         // battery: { type: Number },
//         // snr: { type: Number }, // Signal-to-Noise Ratio
//         acV: { type: Number }, // แรงดันไฟ AC Volt
//         lat: { type: Number }, // Latitude
//         lng: { type: Number }, // Longitude
//         acA: { type: Number }, // กระแสไฟ AC Ampere
//         // rssi: { type: Number }, // Received Signal Strength Indicator
//         // Mongoose จะจัดการ _id ให้เอง
//     },
//     { timestamps: true, collection: 'deviceData' } // ระบุชื่อ Collection ให้ตรงกับ MongoDB
// );

// module.exports = mongoose.model('DeviceData', deviceDataSchema);
const mongoose = require('mongoose');

// กำหนด Schema สำหรับ Collection deviceData (แบบ simplified ตาม requirement ล่าสุด)
const deviceDataSchema = new mongoose.Schema(
  {
    timestamp: { type: Date, required: true },

    // meta ใช้เก็บข้อมูลประกอบ เช่น no, deviceId ฯลฯ
    meta: { type: Object, default: {} },

    vac: { type: Number }, // แรงดัน DC Volt
    wac: { type: Number }, // กำลังไฟ DC Watt
    iac: { type: Number }, // กระแส DC Ampere
    acfreq: { type: Number }, // ความถี่ AC Hz
    acenergy: { type: Number }, // พลังงาน AC kWh
    vdc: { type: Number },
    idc: { type: Number },
    wdc: { type: Number },
    flag: { type: String }, // เก็บค่า flag ดิบ เช่น "$00" หรือ "$00"
    oat: { type: Number },
    lat: { type: Number },
    lng: { type: Number },
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
