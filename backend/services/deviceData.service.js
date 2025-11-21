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
 * 🔹 decode flag 4 หลัก เช่น "$1201" → object แยก field
 *
 * ลำดับตัวเลข:
 *   0: voltage
 *   1: current
 *   2: power
 *   3: oat (อุณหภูมิภายนอก)
 *
 * แต่ละหลัก:
 *   0 = ปกติ
 *   1 = สูง
 *   2 = ต่ำ
 *
 * ค่าปกติทุกตัว = "0000"
 */
function decodeFlag(flag) {
  if (!flag || typeof flag !== 'string') return null;

  let s = flag.trim();
  if (s.startsWith('$')) s = s.slice(1); // "$1201" → "1201"

  if (s.length < 4) {
    console.warn('[deviceData.service] flag too short (expect 4 digits):', flag);
    return null;
  }

  // ใช้แค่ 4 หลักแรก
  s = s.slice(0, 4);

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
    voltage: d[0],
    current: d[1],
    power: d[2],
    oat: d[3],
  };
}

/** ประกอบ payload ตามลำดับฟิลด์ที่ต้องการเก็บใน DB */
function buildOrderedPayload(raw = {}) {
  const ts = toDate(raw.timestamp);

  const meta = {};
  // ถ้ามี meta ด้านนอก เข้ามาแล้ว เอามา merge
  if (raw.meta && typeof raw.meta === 'object') {
    Object.assign(meta, raw.meta);
  }
  // รองรับกรณีส่ง no / deviceId มาเป็น root และยังไม่ได้ยัดเข้า meta
  if (raw.no != null && meta.no == null) {
    meta.no = raw.no;
  }
  if (raw.deviceId && meta.deviceId == null) {
    meta.deviceId = raw.deviceId;
  }

  const flagRaw = raw.flag;

  // ✅ จัดลำดับฟิลด์ให้ใกล้เคียงตัวอย่าง document ที่คุณให้มา
  return {
    timestamp: ts,
    meta,

    dcA: raw.dcA,
    type: raw.type,
    lat: raw.lat,
    flag: flagRaw,
    oat: raw.oat,
    dcV: raw.dcV,
    dcW: raw.dcW,
    lng: raw.lng,
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
    ...(alarms ? { alarms } : {}),
  };
}

/** บันทึก 1 แถว + broadcast realtime */
async function ingestOne(raw) {
  const data = buildOrderedPayload(raw);
  const saved = await DeviceData.create(data);

  try {
    // ส่งไปให้ frontend ผ่าน WS (ใช้ฟิลด์ alarms ที่ decode แล้ว)
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

/** โหลดเริ่มต้น (เช่น 50 แถวล่าสุด) */
async function getDeviceDataList(limit = 50) {
  const rows = await DeviceData.find({})
    .sort({ timestamp: -1 })
    .limit(limit)
    .lean();

  return rows.map(toFrontendRow);
}

/** ตอนนี้ realtime มาจาก ingest → broadcast แล้ว (ฟังก์ชันนี้คงไว้เป็น log) */
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