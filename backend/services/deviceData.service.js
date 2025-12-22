// D:\mass_smart_city\Smart-Control\backend\services\deviceData.service.js

const DeviceData = require('../models/DeviceData');
const { broadcastDeviceData } = require('../ws/wsServer');

/** =========================
 *  WS Batch Broadcaster
 *  - เก็บ row ไว้ใน buffer
 *  - flush ออกเป็นก้อนทุก ๆ BATCH_INTERVAL ms
 *  ========================= */
let wsBuffer = [];
let wsBatchTimerStarted = false;

// ปรับได้ด้วย env ถ้าต้องการ (เช่น 1000)
// ค่า default = 500ms
const BATCH_INTERVAL = Number(process.env.DEVICEDATA_WS_BATCH_MS || 500);

// กัน buffer โตผิดปกติ
const WS_BUFFER_MAX = Number(process.env.DEVICEDATA_WS_BUFFER_MAX || 5000);

function startWsBatchBroadcaster() {
  if (wsBatchTimerStarted) return;
  wsBatchTimerStarted = true;

  setInterval(() => {
    flushWsBuffer();
  }, BATCH_INTERVAL);
}

function flushWsBuffer() {
  if (!wsBuffer.length) return;

  const batch = wsBuffer;
  wsBuffer = [];

  try {
    // ✅ ส่งออกเป็นก้อนเดียว
    // format เดียวกับ mqtt.service.js ที่คุณทำไว้: { data: [...] }
    broadcastDeviceData({ data: batch });
  } catch (e) {
    console.warn('[deviceData.service] WS batch broadcast error:', e.message || e);
  }
}

function pushWsRow(row) {
  wsBuffer.push(row);

  // ถ้า buffer ใหญ่มาก ให้ flush ทันที กัน RAM บวม
  if (wsBuffer.length >= WS_BUFFER_MAX) {
    flushWsBuffer();
  }
}

/**
 * ✅ ฟังก์ชันใหม่: ให้โมดูลอื่น (เช่น mqtt.service) โยน row เข้ามา
 * โดยไม่ต้องมี wsBuffer ซ้ำอีกกอง
 */
function enqueueWsRow(row) {
  startWsBatchBroadcaster();
  try {
    pushWsRow(row);
  } catch (e) {
    console.warn('[deviceData.service] enqueueWsRow error:', e.message || e);
  }
}

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
 * ตัวอย่าง: "$010120"
 */
function decodeFlag(flag) {
  if (!flag || typeof flag !== 'string') return null;

  let s = flag.trim();
  if (s.startsWith('$')) s = s.slice(1);

  if (!/^[0-2]{6}$/.test(s)) {
    console.warn('[deviceData.service] invalid 6-digit flag format:', flag);
    return null;
  }

  const acSensor = parseInt(s[0], 10);
  const acVoltage = parseInt(s[1], 10);
  const acCurrent = parseInt(s[2], 10);
  const dcSensor = parseInt(s[3], 10);
  const dcVoltage = parseInt(s[4], 10);
  const dcCurrent = parseInt(s[5], 10);

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
 */
function toFrontendRow(docOrData) {
  const r = docOrData.toObject ? docOrData.toObject() : { ...docOrData };

  // 1) decode flag
  const alarmsFromFlag = decodeFlag(r.flag) || {};
  const alarms = { ...alarmsFromFlag };

  if (typeof r.oat === 'number') {
    const oatBit = r.oat !== 0 ? 1 : 0;
    alarms.oat = oatBit;
  }

  // 2) เติม nodeId ให้แน่ใจว่ามี
  let nodeId = r.nodeId;
  if (!nodeId) {
    if (r.meta && r.meta.no != null) {
      nodeId = String(r.meta.no);
    } else if (r.meta && r.meta.devEui) {
      nodeId = String(r.meta.devEui);
    }
  }

  return {
    ...r,
    ...(nodeId ? { nodeId } : {}),
    timestamp:
      r.timestamp instanceof Date ? r.timestamp.toISOString() : r.timestamp,
    ...(Object.keys(alarms).length ? { alarms } : {}),
  };
}

/** บันทึก 1 แถว + buffer WS (batch) */
async function ingestOne(raw) {
  startWsBatchBroadcaster();

  const data = buildOrderedPayload(raw);
  const saved = await DeviceData.create(data);

  try {
    // ✅ เปลี่ยนจากยิงทันที -> push เข้า buffer
    pushWsRow(toFrontendRow(saved));
  } catch (e) {
    console.warn('[deviceData.service] buffer push error (one):', e.message || e);
  }

  return saved;
}

/** บันทึกหลายแถว + buffer WS (batch) */
async function ingestMany(rows = []) {
  startWsBatchBroadcaster();

  const items = Array.isArray(rows) ? rows : [rows];
  if (items.length === 0) return [];

  const normalized = items.map(buildOrderedPayload);
  const docs = await DeviceData.insertMany(normalized, { ordered: false });

  try {
    // ✅ เปลี่ยนจาก loop broadcast ทีละตัว -> loop push เข้า buffer
    for (const d of docs) {
      pushWsRow(toFrontendRow(d));
    }
  } catch (e) {
    console.warn('[deviceData.service] buffer push error (many):', e.message || e);
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

/** คงไว้เพื่อ log/compat */
function initRealtimeBridge() {
  startWsBatchBroadcaster();
  console.log(
    `✅ deviceData realtime bridge initialized (WS batch every ${BATCH_INTERVAL}ms)`
  );
}

module.exports = {
  ingestOne,
  ingestMany,
  getDeviceDataList,
  initRealtimeBridge,
  decodeFlag,
  toFrontendRow,

  // ✅ export ตัวนี้ให้ mqtt.service เรียกใช้
  enqueueWsRow,
};
