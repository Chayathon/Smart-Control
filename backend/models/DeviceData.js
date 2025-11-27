// \models\DeviceData.js
const mongoose = require('mongoose');

const deviceDataSchema = new mongoose.Schema(
  {
    timestamp: { type: Date, required: true },
    meta: { type: Object, default: {} },

    vac: { type: Number }, // แรงดัน AC Volt
    wac: { type: Number }, // กำลังไฟ AC Watt
    iac: { type: Number }, // กระแส AC Ampere
    acfreq: { type: Number }, // ความถี่ AC Hz
    acenergy: { type: Number }, // พลังงาน AC kWh
    vdc: { type: Number }, // แรงดัน DC Volt
    idc: { type: Number }, // กระแส DC Ampere
    wdc: { type: Number }, // กำลังไฟ DC Watt
    flag: { type: String },// เก็บค่า flag ดิบ เช่น "$11" หรือ "$00"
    // status: { type: String },  // on/off หรือสถานะอื่น
    oat: { type: Number }, // on air target stream_enable:is_playing
    // lighting: { type: Number },
    // battery: { type: Number },
    // snr: { type: Number },
    // rssi: { type: Number },
    lat: { type: Number }, // latitude
    lng: { type: Number }, // longitude





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
