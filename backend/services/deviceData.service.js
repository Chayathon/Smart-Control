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
 * 🔹 decode flag 6 หลัก เช่น "$012210" → object แยก field
 *
 * ลำดับตัวเลขตามที่กำหนด:
 *   0: af_power
 *   1: voltage
 *   2: current
 *   3: battery_filtered
 *   4: solar_v
 *   5: solar_i
 *
 * แต่ละหลัก: 0 = ปกติ, 1 = สูง, 2 = ต่ำ
 *
 * ค่ามาตรฐาน (ไม่มี alarm ทุกตัว) = "000000"
 */
function decodeFlag(flag) {
  if (!flag || typeof flag !== 'string') return null;

  let s = flag.trim();
  if (s.startsWith('$')) s = s.slice(1); // "$012210" → "012210"

  if (s.length < 6) {
    console.warn('[deviceData.service] flag too short (expect 6 digits):', flag);
    return null;
  }

  // ใช้แค่ 6 หลักแรก
  s = s.slice(0, 6);

  // ต้องเป็นตัวเลข 0 / 1 / 2 เท่านั้น
  if (/[^0-2]/.test(s)) {
    console.warn(
      '[deviceData.service] invalid flag format (must contain only 0,1,2):',
      flag
    );
    return null;
  }

  const d = s.split('').map((c) => parseInt(c, 10));

  return {
    af_power: d[0],
    voltage: d[1],
    current: d[2],
    battery_filtered: d[3],
    solar_v: d[4],
    solar_i: d[5],
  };
}

/** ประกอบ payload ตาม schema ปัจจุบันของ DeviceData */
function buildOrderedPayload(raw = {}) {
  const ts = toDate(raw.timestamp);

  const meta =
    raw.meta && typeof raw.meta === 'object' ? { ...raw.meta } : {};

  // เก็บ flag ดิบไว้ใน DB
  const flagRaw = raw.flag;

  return {
    timestamp: ts,
    meta,

    dcV: raw.dcV,
    dcW: raw.dcW,
    dcA: raw.dcA,

    oat: raw.oat,
    lat: raw.lat,
    lng: raw.lng,

    type: raw.type,
    flag: flagRaw,
  };
}

/**
 * แปลง doc/data -> รูปแบบส่งให้ frontend
 * - timestamp เป็น ISO string
 * - เติม alarms ที่ decode จาก flag (ใช้แค่ส่งออก ไม่บันทึก DB)
 */
function toFrontendRow(docOrData) {
  const r = docOrData.toObject ? docOrData.toObject() : { ...docOrData };

  const alarms = decodeFlag(r.flag);

  return {
    ...r,
    timestamp:
      r.timestamp instanceof Date ? r.timestamp.toISOString() : r.timestamp,
    ...(alarms ? { alarms } : {}), // ใช้ตอน frontend แสดงสีแจ้งเตือน
  };
}

/** บันทึก 1 แถว + broadcast realtime ไป /ws/device-data */
async function ingestOne(raw) {
  const data = buildOrderedPayload(raw);
  const saved = await DeviceData.create(data);

  try {
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
    console.warn('[deviceData.service] broadcast error (many):', e.message || e);
  }

  return docs;
}

/** โหลดเริ่มต้น (เช่น 50 แถวล่าสุด) ให้ frontend */
async function getDeviceDataList(limit = 50) {
  const rows = await DeviceData.find({})
    .sort({ timestamp: -1 })
    .limit(limit)
    .lean();

  return rows.map(toFrontendRow);
}

/** ปัจจุบันไม่ได้ใช้ Change Stream แล้ว (คงไว้เป็น no-op เพื่อความเข้ากันได้) */
function initRealtimeBridge() {
  console.log('✅ deviceData realtime bridge initialized (ingest → WS broadcast)');
}

module.exports = {
  ingestOne,
  ingestMany,
  getDeviceDataList,
  initRealtimeBridge,
  decodeFlag,
};
