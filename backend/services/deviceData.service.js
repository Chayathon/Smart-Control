// D:\mass_smart_city\Smart-Control\backend\services\deviceData.service.js

const DeviceData = require('../models/DeviceData');
const { broadcastDeviceData } = require('../ws/wsServer');

/** แปลง timestamp ทุกแบบให้กลายเป็น Date() */
function toDate(v) {
  try {
    if (!v) return new Date();
    if (v instanceof Date) return v;
    if (typeof v === 'object' && v.$date) return new Date(v.$date);
    if (typeof v === 'number') return new Date(v); // epoch ms
    return new Date(v); // string ISO
  } catch {
    return new Date();
  }
}

/**
 * 🔹 decode flag 7 หลัก (มี '$' นำหน้า + 6 ตัวเลข) ตามสเปคใหม่
 *
 * รูปแบบตัวอย่าง: "$010120"
 *
 * นับจากซ้ายไปขวา (ไม่นับ '$' นะ → จะเหลือ 6 ตัว):
 *
 *   s[0] → AC sensor check
 *          0 = normal
 *          1 = false
 *
 *   s[1] → vac (AC Voltage)
 *          0 = normal
 *          1 = over
 *          2 = under
 *
 *   s[2] → iac (AC Current)
 *          0 = normal
 *          1 = over
 *
 *   s[3] → DC sensor check
 *          0 = normal
 *          1 = false
 *
 *   s[4] → vdc (DC Voltage)
 *          0 = normal
 *          1 = over
 *          2 = under
 *
 *   s[5] → idc (DC Current)
 *          0 = normal
 *          1 = over
 *
 * คืนค่าเป็น object:
 * {
 *   acSensor: 0|1,
 *   acVoltage: 0|1|2,
 *   acCurrent: 0|1,
 *   dcSensor: 0|1,
 *   dcVoltage: 0|1|2,
 *   dcCurrent: 0|1
 * }
 */
function decodeFlag(flag) {
  if (!flag || typeof flag !== 'string') return null;

  let s = flag.trim();
  if (s.startsWith('$')) s = s.slice(1); // "$010120" → "010120"

  // ต้องยาว 6 ตัว และเป็นตัวเลข 0–2
  if (!/^[0-2]{6}$/.test(s)) {
    console.warn(
      '[deviceData.service] invalid 6-digit flag format:',
      flag
    );
    return null;
  }

  const acSensor = parseInt(s[0], 10);   // 0/1
  const acVoltage = parseInt(s[1], 10);  // 0/1/2
  const acCurrent = parseInt(s[2], 10);  // 0/1
  const dcSensor = parseInt(s[3], 10);   // 0/1
  const dcVoltage = parseInt(s[4], 10);  // 0/1/2
  const dcCurrent = parseInt(s[5], 10);  // 0/1

  return {
    acSensor,
    acVoltage,
    acCurrent,
    dcSensor,
    dcVoltage,
    dcCurrent,
  };
}

function buildOrderedPayload(raw = {}) {
  const ts = toDate(raw.timestamp);

  const meta = {};
  if (raw.meta && typeof raw.meta === 'object') {
    Object.assign(meta, raw.meta);
  }
  if (raw.no != null && meta.no == null) {
    meta.no = raw.no;
  }
  if (raw.deviceId && meta.deviceId == null) {
    meta.deviceId = raw.deviceId;
  }

  return {
    timestamp: ts,
    meta,

    vac: raw.vac,
    iac: raw.iac,
    wac: raw.wac,
    acfreq: raw.acfreq,
    acenergy: raw.acenergy,
    vdc: raw.vdc,
    idc: raw.idc,
    wdc: raw.wdc,
    flag: raw.flag,
    oat: raw.oat,
    lat: raw.lat,
    lng: raw.lng,
  };
}

/**
 * แปลง doc/data -> รูปแบบส่งให้ frontend
 * - timestamp เป็น ISO string
 * - เติม alarms ที่ decode จาก flag + oat
 *
 * alarms รูปแบบ (ตามสเปคใหม่):
 * {
 *   acSensor: 0|1,
 *   acVoltage: 0|1|2,
 *   acCurrent: 0|1,
 *   dcSensor: 0|1,
 *   dcVoltage: 0|1|2,
 *   dcCurrent: 0|1,
 *   oat: 0|1          // 0 ไม่ประกาศ, 1 กำลังประกาศ (ส่งตรงจากค่า oat)
 * }
 */
function toFrontendRow(docOrData) {
  const r = docOrData.toObject ? docOrData.toObject() : { ...docOrData };

  // 1) ดึงจาก flag 6 หลัก
  const alarmsFromFlag = decodeFlag(r.flag) || {};

  // 2) อิง oat จากค่าที่เก็บใน DB (0/1)
  const alarms = { ...alarmsFromFlag };

  // ใช้ค่า oat จาก DB ตรง ๆ (0 หรือ 1 ก็ส่ง)
  if (typeof r.oat === 'number') {
    const oatBit = r.oat !== 0 ? 1 : 0;
    alarms.oat = oatBit;
  }

  return {
    ...r,
    timestamp:
      r.timestamp instanceof Date ? r.timestamp.toISOString() : r.timestamp,
    ...(Object.keys(alarms).length ? { alarms } : {}),
  };
}

/** บันทึก 1 แถว + broadcast realtime */
async function ingestOne(raw) {
  const data = buildOrderedPayload(raw);
  const saved = await DeviceData.create(data);

  try {
    // ส่งไปให้ frontend ผ่าน WS (ใช้ field alarms ที่ decode แล้ว)
    broadcastDeviceData(toFrontendRow(saved));
  } catch (e) {
    console.warn('[deviceData.service] broadcast error:', e.message || e);
  }

  return saved;
}

/** บันทึกหลายแถว + broadcast ทีละแถว */
async function ingestMany(rows = []) {
  const items = Array.isArray(rows) ? rows : [rows];
  if (items.length === 0) return [];

  const normalized = items.map(buildOrderedPayload);
  const docs = await DeviceData.insertMany(normalized, { ordered: false });

  try {
    for (const d of docs) {
      broadcastDeviceData(toFrontendRow(d));
    }
  } catch (e) {
    console.warn(
      '[deviceData.service] broadcast error (many):',
      e.message || e
    );
  }

  return docs;
}

/** โหลดเริ่มต้น (ถ้าไม่ส่ง limit = ดึงทั้งหมด) */
async function getDeviceDataList(limit) {
  let query = DeviceData.find({}).sort({ timestamp: -1 });

  if (typeof limit === 'number' && Number.isFinite(limit)) {
    query = query.limit(limit);
  }

  const rows = await query.lean();
  return rows.map(toFrontendRow);
}

/** ตอนนี้ realtime มาจาก ingest → broadcast แล้ว (ฟังก์ชันนี้คงไว้เป็น log) */
function initRealtimeBridge() {
  console.log(
    '✅ deviceData realtime bridge initialized (ingest → WS broadcast)'
  );
}

module.exports = {
  ingestOne,
  ingestMany,
  getDeviceDataList,
  initRealtimeBridge,
  decodeFlag,
  toFrontendRow,
};
