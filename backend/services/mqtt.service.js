const mqtt = require('mqtt');
const { broadcast, broadcastDeviceData } = require('../ws/wsServer');
const Device = require('../models/Device');
const DeviceData = require('../models/DeviceData');
const uart = require('./uart.handle');
const deviceDataService = require('../services/deviceData.service');
const { stream } = require('../config/config');
const mongoose = require('mongoose');

let deviceStatus = [];
let seenZones = new Set();
let client = null;
let connected = false;
let lastUartCmd = null;
let lastUartTs = 0;
let blockSyncUntil = 0;
let lastBulkString = "";

let dbBuffer = [];
let wsBuffer = [];
const BATCH_INTERVAL = 500;
const TOTAL_ZONES = 200;

const deviceIdCache = new Map();
const lastHeartbeatUpdate = new Map();
const pendingRequestsByZone = {};
const lastManualByZone = new Map();

function connectAndSend({
    brokerUrl = 'mqtt://192.168.1.83:1883',
    username = 'admin',
    password = 'admin',
    statusTopic = process.env.MQTT_TOPIC_ZONE_STATUS,
    dataTopic = process.env.MQTT_TOPIC_ZONE_DATA,
    zoneCommandTopic = process.env.MQTT_TOPIC_ZONE_COMMAND,
    zoneLwtTopic = process.env.MQTT_TOPIC_ZONE_LWT
} = {}) {
    deviceStatus = [];
    seenZones.clear();

    client = mqtt.connect(brokerUrl, {
        username,
        password,
        protocolVersion: 5,
        reconnectPeriod: 5000,
        clean: true
    });

    client.on('connect', () => {
        connected = true;
        console.log('✅ MQTT connected');

        client.subscribe(dataTopic, { qos: 1 }, (err) => {
            if (err) console.error('📥 subscribe mass-radio/+/monitoring error:', err.message);
            else console.log('📥 subscribed mass-radio/+/monitoring');
        });

        client.subscribe(zoneCommandTopic, { qos: 1 }, (err) => {
            if (err) console.error('❌ Subscribe error for zone/command:', err.message);
            else console.log('📥 Subscribed to mass-radio/+/command');
        });

        client.subscribe(statusTopic, { qos: 1 }, (err) => {
            if (err) console.error('❌ Subscribe error:', err.message);
            else console.log(`📥 Subscribed to ${statusTopic}`);
        });

        client.subscribe(zoneLwtTopic, { qos: 1 }, (err) => {
            if (err) console.error('❌ Subscribe error for zone LWT:', err.message);
            else console.log('📥 Subscribed to mass-radio/+/lwt');
        });

        client.subscribe('mass-radio/test/bulk', { qos: 1 });

        // setInterval(() => {
        //     publish(allCommandTopic, { get_status: true });
        // }, 30000);

        setInterval(checkOfflineZones, 10000);
        setInterval(processBatch, BATCH_INTERVAL);
    });

    client.on('close', () => {
        connected = false;
        console.warn('⚠️ MQTT connection closed');
    });

    client.on('message', async (topic, message, packet) => {
        const payloadStr = message.toString();

        if (topic === 'mass-radio/test/bulk') {
            console.log(`🧪 [TEST] Received Bulk String via MQTT: ${payloadStr}`);
            // เรียกใช้ฟังก์ชัน Bulk Update ทันที
            await handleRawBulkStatus(payloadStr);
            return;
        }

        // 1. เช็คว่าเป็น Data Monitoring หรือไม่?
        if (await handleDeviceData(topic, payloadStr, packet)) return;

        // 2. เช็คว่าเป็น Status หรือไม่?
        if (await handleStatus(topic, payloadStr, packet)) return;

        // 3. เช็คว่าเป็น Command หรือไม่?
        if (await handleCommand(topic, payloadStr)) return;

        // 4. เช็คว่าเป็น LWT หรือไม่?
        if (await handleLWT(topic, payloadStr)) return;
    });

    client.on('error', (err) => console.error('❌ MQTT error:', err.message));
    client.on('reconnect', () => console.log('🔁 MQTT reconnecting...'));
    client.on('offline', () => console.warn('⚠️ MQTT offline'));
}

function getStatus() {
    return deviceStatus;
}

function publishAndWaitByZone(topic, payload, timeoutMs = 5000) {
    return new Promise((resolve, reject) => {
        if (!client || !connected) {
            return reject(new Error('MQTT not connected'));
        }

        const match = topic.match(/zone(\d+)/);
        if (!match) {
            return reject(new Error(`Cannot extract zone from topic: ${topic}`));
        }
        const zone = parseInt(match[1], 10);

        pendingRequestsByZone[zone] = { resolve, reject };

        setTimeout(() => {
            if (pendingRequestsByZone[zone]) {
                delete pendingRequestsByZone[zone];
                reject(new Error(`Timeout waiting for response from zone ${zone}`));
            }
        }, timeoutMs);

        const message = JSON.stringify(payload);
        client.publish(topic, message, { qos: 1 }, (err) => {
            if (err) reject(err);
        });
    });
}

function publish(topic, payload, opts = { qos: 1, retain: false }) {
    if (!client || !connected) {
        console.error('❌ Cannot publish, MQTT not connected');
        return;
    }
    const message = typeof payload === 'object' ? JSON.stringify(payload) : String(payload);
    client.publish(topic, message, opts, (err) => {
        if (err) console.error(`❌ Failed to publish ${topic}:`, err.message);
        else console.log(`📤 Published to ${topic}:`, message);
    });
}

function upsertDeviceStatus(no, data) {
    const now = Date.now();
    const index = deviceStatus.findIndex(d => d.zone === no);

    if (index >= 0) {
        deviceStatus[index] = { zone: no, data, lastSeen: now };
    } else {
        deviceStatus.push({ zone: no, data, lastSeen: now });
    }
}

function getCurrentStatusOfZone(no) {
    const item = deviceStatus.find(d => d.zone === no);
    return item ? item.data : null;
}

async function updateDeviceInDB(no, data) {
    try {
        await Device.findOneAndUpdate(
            { no },
            {
                $set: {
                    'status.stream_enabled': !!data.stream_enabled,
                    'status.volume': data.volume ?? 0,
                    lastSeen: new Date()
                }
            },
            { upsert: true, new: true }
        );
    } catch (err) {
        console.error(`❌ Failed to update device ${no} in DB:`, err.message);
    }
}

/** System Control Functions */

async function processBatch() {
    if (dbBuffer.length > 0) {
        const batch = [...dbBuffer];
        dbBuffer = [];

        if (mongoose.connection.readyState === 1) {
            DeviceData.insertMany(batch)
                .catch(err => console.error('[Batch-DB] Error:', err.message));
        }
    }

    if (wsBuffer.length > 0) {
        const batch = [...wsBuffer];
        wsBuffer = [];

        broadcastDeviceData({
            data: batch
        });
    }
}

// 1. จัดการข้อมูล DeviceData ที่เข้ามา
async function handleDeviceData(topic, payloadStr, packet) {
    if (packet && packet.retain) return true;

    const m = topic.match(/^mass-radio\/(zone\d+)\/monitoring$/);
    if (!m) return false;
    const nodeKey = m[1];
    const noFromTopic = parseInt(nodeKey.replace(/^zone/, ''), 10);
    // console.log(`[MQTT] 📥 incoming deviceData from ${nodeKey} : `, payloadStr);

    let json;
    try {
        json = JSON.parse(payloadStr);
    } catch (e) {
        console.error('[MQTT] Invalid JSON for deviceData:', e.message);
        return true;
    }

    const no = typeof json.no === 'number' && Number.isFinite(json.no) ? json.no : noFromTopic;

    // --- Cache Handling ---
    let deviceId = deviceIdCache.get(no);
    if (!deviceId && mongoose.connection.readyState === 1) {
        try {
            const device = await Device.findOne({ no });
            if (device) {
                deviceId = device._id;
                deviceIdCache.set(no, device._id);
            }
        } catch (e) { }
    }

    const timestamp = json.timestamp ? new Date(json.timestamp) : new Date();

    // ข้อมูลสำหรับลง DB / ส่งต่อ
    const payloadForIngest = {
        timestamp,
        meta: {
            no,
            ...(deviceId ? { deviceId } : {}),
        },
        vac: json.vac,
        iac: json.iac,
        wac: json.wac,
        acfreq: json.acfreq,
        acenergy: json.acenergy,
        vdc: json.vdc,
        idc: json.idc,
        wdc: json.wdc,
        flag: json.flag,
        oat: json.oat,
        lat: json.lat,
        lng: json.lng,
    };

    let payloadForUI = payloadForIngest;
    try {
        payloadForUI = deviceDataService.toFrontendRow(payloadForIngest);
    } catch (e) {
        console.warn('[Data] Formatting error, sending raw:', e.message);
    }

    // // ✅ ส่ง realtime ไปยัง /ws/device-data แบบเวอร์ชันเก่า (row ต่อ row)
    // try {
    //     broadcastDeviceData(payloadForUI);
    // } catch (e) {
    //     console.warn('[WS] broadcastDeviceData error:', e.message);
    // }

    // ✅ ยังเก็บ buffer สำหรับ bulk WS + Mongo ตามเดิม
    wsBuffer.push(payloadForUI);
    dbBuffer.push(payloadForIngest); // รอรถเมล์รอบ DB

    const now = Date.now();
    const lastUpdate = lastHeartbeatUpdate.get(no) || 0;

    // อัปเดต DB แค่นาทีละครั้ง (ตาราง Device)
    if (now - lastUpdate > 60000 && deviceId && mongoose.connection.readyState === 1) {
        Device.updateOne({ _id: deviceId }, { lastSeen: timestamp }).catch(() => { });
        lastHeartbeatUpdate.set(no, now);
    }

    // อัปเดต RAM ทันที (เพื่อ Watchdog)
    const item = deviceStatus.find(d => d.zone === no);
    if (item) {
        item.lastSeen = now;
    } else {
        upsertDeviceStatus(no, { online: true, lastSeen: now });
    }

    return true;
}

// 2. จัดการ LWT (Last Will and Testament)
async function handleLWT(topic, payloadStr) {
    const lwtMatch = topic.match(/^mass-radio\/([^/]+)\/lwt$/);
    if (!lwtMatch) return false;
    const target = lwtMatch[1];
    const zoneNumMatch = target.match(/^zone(\d+)$/);
    if (zoneNumMatch) {
        const no = parseInt(zoneNumMatch[1], 10);

        if (payloadStr === 'offline') {
            console.log(`[LWT] 💀 Zone ${no} confirmed DEAD.`);
            broadcast({ zone: no, offline: true, source: 'lwt' });
        } else if (payloadStr === 'online') {
            console.log(`[LWT] 🐣 Zone ${no} is back ONLINE.`);
            broadcast({ zone: no, offline: false, source: 'lwt' });
        }
    }
    return true;
}

// 3. จัดการคำสั่ง (Command) จาก App/Web
async function handleCommand(topic, payloadStr) {
    const cmdMatch = topic.match(/^mass-radio\/([^/]+)\/command$/);
    if (!cmdMatch) return false;

    let json;
    const target = cmdMatch[1];
    try { json = JSON.parse(payloadStr); } catch (e) { return true; }

    if (!json || json.source === 'manual-panel') return true;

    // Case: Select (หลายโซน)
    if (target === 'select' && json.zone && Array.isArray(json.zone)) {
        console.log(`📨 Received SELECT command for ${json.zone.length} zones:`, json.zone);
        if (typeof json.set_stream === 'boolean') {
            await sendMultiZoneUartCommand(json.zone, json.set_stream);
        }
        return true;
    }

    // Case: All / Zone
    let zoneNum = null;
    if (target === 'all') zoneNum = 1111;
    else if (target.startsWith('zone')) {
        const numMatch = target.match(/\d+/);
        if (numMatch) zoneNum = parseInt(numMatch[0], 10);
    }

    if (zoneNum !== null) {
        if (typeof json.set_stream === 'boolean') {
            if (zoneNum === 1111) {
                console.log(`[RadioZone] CMD ALL -> UART`);
                blockSyncUntil = Date.now() + 5000; // กัน Flood
            }
            await sendZoneUartCommand(zoneNum, json.set_stream);
        }
        else if (typeof json.set_volume === 'number') {
            await sendVolUartCommand(zoneNum, json.set_volume);
        }
    }
    return true;
}

// 4. จัดการสถานะ (Status) จาก Hardware/Manual Panel
async function handleStatus(topic, payloadStr, packet) {
    const statusMatch = topic.match(/^mass-radio\/([^/]+)\/status$/);
    if (!statusMatch) return false;

    const target = statusMatch[1];
    if (!payloadStr.trim()) return true;

    let json;
    try { json = JSON.parse(payloadStr); } catch (e) { return true; }

    // Case: ALL Status Response
    if (target === 'all') {
        const streamEnabled = !!json.stream_enabled;
        const now = Date.now();
        console.log('[RadioZone] ALL status ->', streamEnabled ? 'ON' : 'OFF');

        deviceStatus = deviceStatus.map(d => ({
            ...d,
            data: { ...d.data, stream_enabled: streamEnabled, is_playing: streamEnabled },
            lastSeen: now
        }));

        if (mongoose.connection.readyState === 1) {
            Device.updateMany({}, {
                $set: { 'status.stream_enabled': streamEnabled, 'status.is_playing': streamEnabled, lastSeen: now }
            }).catch(() => { });
        }

        deviceStatus.forEach(d => broadcast({
            zone: d.zone, stream_enabled: streamEnabled, is_playing: streamEnabled, source: 'manual-all'
        }));
        return true;
    }

    // Case: ZONE Status Response
    const zoneNumMatch = target.match(/^zone(\d+)$/);
    if (zoneNumMatch) {
        const no = parseInt(zoneNumMatch[1], 10);

        // 1. Clear Retain
        if (packet && packet.retain) {
            if (!seenZones.has(target)) {
                seenZones.add(target);
                client.publish(topic, '', { qos: 1, retain: true });
            }
            return true;
        }

        // 2. Handle Promise Request
        if (pendingRequestsByZone[no]) {
            pendingRequestsByZone[no].resolve({ zone: no, ...json });
            delete pendingRequestsByZone[no];
        }

        const now = Date.now();
        const isManual = json.source === 'manual' || json.source === 'manual-panel';
        if (isManual) lastManualByZone.set(no, now);

        const prev = getCurrentStatusOfZone(no);
        const prevStreamStatus = prev ? prev.stream_enabled : null;
        let merged = { ...json };

        // 3. Manual Debounce (5s)
        const lastManualTs = lastManualByZone.get(no);
        if (!isManual && lastManualTs && (now - lastManualTs) < 5000 && prev) {
            merged.stream_enabled = prev.stream_enabled;
            merged.is_playing = prev.is_playing;
        }

        upsertDeviceStatus(no, merged);
        const isFromManualPanel = merged.source === 'manual-panel';

        if (!isFromManualPanel && merged.stream_enabled !== undefined && merged.stream_enabled !== prevStreamStatus) {
            if (Date.now() < blockSyncUntil) {
                // ภายในช่วง block จากคำสั่ง ALL → ไม่ sync UART ซ้ำ
            } else {
                console.log(`[Sync] Node/Web changed status (Zone ${no}). Syncing to UART Machine...`);
                sendZoneUartCommand(no, merged.stream_enabled).catch(err => {
                    console.error(`[RadioZone] UART sync error zone ${no}:`, err.message);
                });
            }
        } else if (isFromManualPanel) {
            console.log(`[Sync] Action from Manual Panel (Zone ${no}) - No Echo`);
        }

        // 5. Broadcast & DB
        console.log(`✅ Response from zone ${no}:`, merged);
        broadcast({ zone: no, ...merged });

        if (mongoose.connection.readyState === 1) {
            updateDeviceInDB(no, merged);
        }
        return true;
    }
    return false;
}

// 5. ส่งคำสั่งเปิด/ปิดโซนไปยัง UART
async function sendZoneUartCommand(zone, set_stream) {
    const zoneStr = String(zone).padStart(4, '0');
    const baseCmd = set_stream
        ? `$S${zoneStr}Y$`  // เปิดโซน
        : `$S${zoneStr}N$`; // ปิดโซน

    const now = Date.now();
    const key = `${baseCmd}`;

    if (lastUartCmd === key && (now - lastUartTs) < 300) {
        console.log('[RadioZone] skip duplicate UART cmd:', key);
        return;
    }
    lastUartCmd = key;
    lastUartTs = now;

    console.log('[RadioZone] MQTT zone command -> UART:', {
        zone,
        set_stream,
        uartCmd: baseCmd,
    });

    try {
        await uart.writeString(baseCmd, 'ascii');
    } catch (err) {
        console.error('[RadioZone] UART write error for zone command:', err.message);
    }
}

// 5.1 ส่งคำสั่ง Bulk เปิด/ปิดโซนไปยัง UART
async function sendZoneUartBulkCommand(zone, set_stream) {
    let bulkString = '';
    if (zone === 1111) {
        bulkString = (set_stream ? 'Y' : 'N').repeat(TOTAL_ZONES);
    } else {
        for (let i = 1; i <= TOTAL_ZONES; i++) {
            let isZoneOn = false;
            if (i === zone) {
                isZoneOn = set_stream;
            }
            else {
                const item = deviceStatus.find(d => d.zone === i);
                isZoneOn = item && item.data ? item.data.stream_enabled : false;
            }
            bulkString += (isZoneOn ? 'Y' : 'N');
        }
    }
    const finalCmd = `${bulkString}`;
    console.log(`[RadioZone] Bulk String Length: ${finalCmd.length}`);
    const now = Date.now();
    if (lastUartCmd === finalCmd && (now - lastUartTs) < 300) {
        console.log('[RadioZone] Skip duplicate UART bulk cmd');
        return;
    }
    lastUartCmd = finalCmd;
    lastUartTs = now;
    console.log(`[RadioZone] 📤 UART Syncing ${TOTAL_ZONES} zones (Target: ${zone}, Val: ${set_stream})`);
    try {
        await uart.writeString(finalCmd, 'ascii');
    } catch (err) {
        console.error('[RadioZone] ❌ UART Write Error:', err.message);
    }
}

// 5.2 ส่งคำสั่งเปิด/ปิดหลายโซน bulk ไปยัง UART
async function sendMultiZoneUartCommand(targetZonesArray, set_stream) {
    const TOTAL_ZONES = 200;
    let bulkString = '';

    // 1. แปลง Array เป็น Set เพื่อให้เช็คเร็วขึ้น (O(1)) และกันค่าซ้ำ
    const targets = new Set(targetZonesArray.map(z => parseInt(z, 10)));

    // 2. วนลูปสร้าง String 200 ตัว
    for (let i = 1; i <= TOTAL_ZONES; i++) {
        let isZoneOn = false;

        // A. ถ้าโซนนี้ (i) อยู่ในรายชื่อที่เลือก -> ใช้ค่าใหม่ที่สั่งมา
        if (targets.has(i)) {
            isZoneOn = set_stream;
        }
        // B. ถ้าไม่อยู่ -> ให้รักษาค่าเดิมจาก Memory ไว้
        else {
            const item = deviceStatus.find(d => d.zone === i);
            isZoneOn = item && item.data ? item.data.stream_enabled : false;
        }

        bulkString += (isZoneOn ? 'Y' : 'N');
    }

    const finalCmd = `${bulkString}`;

    // 3. ระบบ Debounce (กันส่งซ้ำ)
    const now = Date.now();
    if (lastUartCmd === finalCmd) {
        console.log('[RadioZone] ⏹️ Skip sending UART: State unchanged (Already sent)');
        return;
    }

    if ((now - lastUartTs) < 300) {
        console.log('[RadioZone] ⚠️ Skip sending UART: Too fast (Rate limit)');
        return;
    }

    lastUartCmd = finalCmd;
    lastUartTs = now;

    try {
        console.log('[RadioZone] UART Command:', finalCmd);
        // await uart.writeString(finalCmd, 'ascii');
    } catch (err) {
        console.error('[RadioZone] ❌ UART Write Error:', err.message);
    }
}

// 7. ส่งคำสั่งปรับระดับเสียงโซนไปยัง UART
async function sendVolUartCommand(zone, set_volume) {
    const zoneStr = String(zone).padStart(4, '0');

    // clamp 0–21
    let vol = Number(set_volume);
    if (!Number.isFinite(vol)) {
        console.warn('[RadioZone] invalid volume value:', set_volume);
        return;
    }
    if (vol < 0) vol = 0;
    if (vol > 21) vol = 21;

    const baseCmd = `$V${zoneStr}${vol}$`;
    const now = Date.now();
    const key = baseCmd;

    // กันยิงซ้ำในเวลาใกล้ ๆ กัน (เหมือน set_stream)
    if (lastUartCmd === key) {
        console.log('[RadioZone] skip duplicate UART cmd (VOL):', key);
        return;
    }

    if ((now - lastUartTs) < 300) {
        console.log('[RadioZone] skip UART vol cmd: too fast');
        return;
    }

    lastUartCmd = key;
    lastUartTs = now;

    console.log('[RadioZone] MQTT volume command -> UART:', {
        zone,
        volume: vol,
        uartCmd: baseCmd,
    });

    try {
        await uart.writeString(baseCmd, 'ascii');
    } catch (err) {
        console.error('[RadioZone] UART write error for volume command:', err.message);
    }
}

// 8. จัดการสถานะ Bulk (เช่น "YNNYYN...")
async function handleRawBulkStatus(rawString) {
    const totalZones = rawString.length;
    if (rawString === lastBulkString) {
        console.log('[Bulk] skip duplicate bulk string');
        return;
    }
    lastBulkString = rawString;
    console.log(`[Bulk] Processing status for ${totalZones} zones...`);
    const bulkOps = [];
    const updatesForBroadcast = [];
    const now = Date.now();
    for (let i = 0; i < totalZones; i++) {
        const char = rawString[i];
        const zoneNum = i + 1;
        let streamEnabled = (char === 'Y');
        if (char !== 'Y' && char !== 'N') continue;

        // ดึงค่าเก่าจาก Memory
        const prev = getCurrentStatusOfZone(zoneNum);
        const oldState = prev ? prev.stream_enabled : false;
        if (prev) {
            prev.lastSeen = now;
        } else {
            upsertDeviceStatus(zoneNum, { stream_enabled: oldState, lastSeen: now });
        }
        if (streamEnabled === oldState) {
            continue;
        }
        bulkOps.push({
            updateOne: {
                filter: { no: zoneNum },
                update: {
                    $set: {
                        'status.stream_enabled': streamEnabled,
                        'status.is_playing': streamEnabled,
                        lastSeen: now
                    }
                }
            }
        });
        upsertDeviceStatus(zoneNum, {
            stream_enabled: streamEnabled,
            is_playing: streamEnabled,
            volume: prev ? prev.volume : 0,
            source: 'bulk-scan'
        });
        updatesForBroadcast.push({ zone: zoneNum, stream_enabled: streamEnabled });
    }
    if (bulkOps.length > 0 && mongoose.connection.readyState === 1) {
        try {
            await Device.bulkWrite(bulkOps);
            console.log(`[Bulk] ✅ DB Updated for ${bulkOps.length} changed zones.`);

            if (updatesForBroadcast.length > 0) {
                broadcast({
                    type: 'STATE_CHANGE_BULK',
                    data: updatesForBroadcast,
                    source: 'bulk'
                });
            }

        } catch (err) { console.error('[Bulk] DB Error:', err.message); }
    }
}

// 9. ตรวจสอบโซนที่ Offline (เงียบเกิน 35 วินาที)
async function checkOfflineZones() {
    if (mongoose.connection.readyState !== 1) return;

    const now = Date.now();
    const offlineZones = [];

    deviceStatus.forEach(d => {
        const isTimedOut = (now - d.lastSeen) > 35000;
        const isCurrentlyMarkedOnline = d.data && d.data.online !== false;
        if (isTimedOut && isCurrentlyMarkedOnline) {
            console.log(`[Watchdog] Zone ${d.zone} silent > 35s (Zombie Detected)`);
            offlineZones.push(d.zone);
            if (d.data) d.data.online = false;
        }
    });

    if (offlineZones.length > 0) {
        offlineZones.forEach(zoneNo => {
            const currentMem = getCurrentStatusOfZone(zoneNo);

            broadcast({
                zone: zoneNo,
                stream_enabled: currentMem ? currentMem.stream_enabled : false,
                is_playing: currentMem ? currentMem.is_playing : false,
                volume: currentMem ? currentMem.volume : 0,

                offline: true,
                source: 'watchdog'
            });
        });
    }
}

module.exports = {
    connectAndSend,
    getStatus,
    publish,
    publishAndWaitByZone,
    upsertDeviceStatus,
    handleRawBulkStatus
};
