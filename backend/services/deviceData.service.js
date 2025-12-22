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
 * ✅ decodeFlag (สเปคของคุณจริง ๆ)
 * - flag จะมาแบบ "$" + 2 หลัก เช่น "$00", "$12"
 * - หลังตัด '$' จะเหลือ 2 ตัวอักษร (0–2)
 *
 * ⚠️ หมายเหตุ:
 * - เดิมโค้ดเคยเขียนรองรับ 6 หลัก (สเปคใหม่) แต่คุณยืนยันว่า "ของจริงมีแค่ 2 หลัก"
 * - ดังนั้น "ห้าม pad เป็น 6 หลัก" เพราะจะเพี้ยนความหมาย
 *
 * ✅ เราจะคืนค่า object alarms ให้ UI ใช้ต่อได้ทันที โดยยังใช้ key เดิมที่ UI คาดหวัง:
 * { acSensor, acVoltage, acCurrent, dcSensor, dcVoltage, dcCurrent }
 *
 * ✅ Mapping ที่ใช้ (ปลอดภัยและเข้ากับค่า 0–2):
 * - หลักที่ 1 (a) -> acVoltage  (0/1/2)
 * - หลักที่ 2 (b) -> dcVoltage  (0/1/2)
 * - ค่าอื่นที่ไม่รู้ (sensor/current) ตั้งเป็น 0
 *
 * ถ้าคุณต้องการ mapping แบบอื่นในอนาคต (เช่น a=acSensor b=dcSensor) ก็ปรับ return ได้ง่ายมาก
 */
function decodeFlag(flag) {
  if (!flag || typeof flag !== 'string') return null;

  let s = flag.trim();
  if (s.startsWith('$')) s = s.slice(1); // "$00" → "00"

  // ต้องเป็น 2 หลัก และเป็นตัวเลข 0–2 เท่านั้น
  if (!/^[0-2]{2}$/.test(s)) {
    console.warn('[deviceData.service] invalid 2-digit flag format:', flag);
    return null;
  }

  const a = parseInt(s[0], 10); // 0/1/2
  const b = parseInt(s[1], 10); // 0/1/2

  return {
    // ค่า 0/1: sensor check (เราไม่มีข้อมูลจาก 2 หลักนี้ จึงตั้งเป็น 0)
    acSensor: 0,
    dcSensor: 0,

    // ค่า 0/1/2: voltage normal/over/under (เหมาะกับช่วง 0–2)
    acVoltage: a,
    dcVoltage: b,

    // current ไม่มีข้อมูลจาก flag 2 หลักนี้
    acCurrent: 0,
    dcCurrent: 0,
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
 * alarms รูปแบบ:
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

  // 1) decode flag -> alarms
  const alarmsFromFlag = decodeFlag(r.flag) || {};
  const alarms = { ...alarmsFromFlag };

  // 2) oat (ประกาศ/ไม่ประกาศ) เติมเพิ่ม
  if (typeof r.oat === 'number') {
    const oatBit = r.oat !== 0 ? 1 : 0;
    alarms.oat = oatBit;
  }

  // 3) เติม nodeId ให้แน่ใจว่ามี (สำคัญต่อการ update UI ทีละโซน)
  let nodeId = r.nodeId;
  if (!nodeId) {
    if (r.meta && r.meta.no != null) {
      nodeId = String(r.meta.no); // ใช้เลขโซนเป็น nodeId
    } else if (r.meta && r.meta.devEui) {
      nodeId = String(r.meta.devEui); // สำรอง
    }
  }

  return {
    ...r,
    ...(nodeId ? { nodeId } : {}), // ใส่เฉพาะถ้าเราหาได้จริง
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
    // ส่งไปให้ frontend ผ่าน WS
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
