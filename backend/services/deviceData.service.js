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
 * 🔹 decode flag 2 หลัก ตามสเปคใหม่
 *
 * รูปแบบ: "$XY"
 *   X = voltage  : 0 ปกติ, 1 สูง, 2 ต่ำ
 *   Y = current  : 0 ปกติ, 1 over current (2 ยังไม่ใช้)
 *
 * ตัวอย่าง:
 *   "$00" → voltage=0, current=0 (ปกติ)
 *   "$10" → voltage สูง, current ปกติ
 *   "$01" → voltage ปกติ, current over current
 */
function decodeFlag(flag) {
  if (!flag || typeof flag !== 'string') return null;

  let s = flag.trim();
  if (s.startsWith('$')) s = s.slice(1); // "$10" → "10"

  // ต้องยาว 2 ตัว และเป็นตัวเลข 0–2
  if (!/^[0-2]{2}$/.test(s)) {
    console.warn(
      '[deviceData.service] invalid 2-digit flag format:',
      flag
    );
    return null;
  }

  const v = parseInt(s[0], 10);
  const c = parseInt(s[1], 10);

  return {
    voltage: v, // 0 ปกติ, 1 สูง, 2 ต่ำ
    current: c, // 0 ปกติ, 1 over current
  };
}

/** ประกอบ payload ตามลำดับฟิลด์ที่ต้องการเก็บใน DB */
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

  const flagRaw = raw.flag;

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
    lng: raw.lng
  };
}

/**
 * แปลง doc/data -> รูปแบบส่งให้ frontend
 * - timestamp เป็น ISO string
 * - เติม alarms ที่ decode จาก flag + oat
 *
 * alarms รูปแบบ:
 * {
 *   voltage: 0|1|2,
 *   current: 0|1,
 *   oat: 0|1    // 0 ไม่ได้ประกาศ, 1 กำลังประกาศ
 * }
 */
function toFrontendRow(docOrData) {
  const r = docOrData.toObject ? docOrData.toObject() : { ...docOrData };

  // 1) ดึงจาก flag 2 หลัก
  const alarmsFromFlag = decodeFlag(r.flag) || {};

  // 2) อิง oat จากค่าที่เก็บใน DB (0/1)
  const alarms = { ...alarmsFromFlag };

  if (typeof r.oat === 'number') {
    const oatBit = r.oat > 0 ? 1 : 0;
    // ถ้าอยากให้แสดงเฉพาะตอน "กำลังประกาศ" ให้เก็บเฉพาะ oatBit === 1
    if (oatBit !== 0) {
      alarms.oat = oatBit;
    }
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
