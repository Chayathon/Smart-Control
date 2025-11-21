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

// กำหนด Schema สำหรับ Collection deviceData
const deviceDataSchema = new mongoose.Schema(
  {
    timestamp: { type: Date, required: true },

    meta: { type: Object },

    acW: { type: Number },
    acV: { type: Number },
    acA: { type: Number },

    dcV: { type: Number }, // แรงดัน DC Volt
    dcW: { type: Number }, // กำลังไฟ DC Watt
    dcA: { type: Number }, // กระแส DC Ampere

    status: { type: String },  // on/off หรือสถานะอื่น
    oat: { type: Number },     // อุณหภูมิภายนอก
    lighting: { type: Number },
    battery: { type: Number },

    snr: { type: Number },
    rssi: { type: Number },

    lat: { type: Number },
    lng: { type: Number },

    // no: { type: Number },
    type: {type: String},

    flag: { type: String },
  },
  { timestamps: true, collection: 'deviceData' }
);

module.exports = mongoose.model('DeviceData', deviceDataSchema);
