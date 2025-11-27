const mqtt = require('mqtt');
const { broadcast } = require('../ws/wsServer');
const Device = require('../models/Device');
const DeviceData = require('../models/DeviceData');
const uart = require('./uart.handle');
const deviceDataService = require('../services/deviceData.service');
const { stream } = require('../config/config');

let deviceStatus = [];
let seenZones = new Set();
let client = null;
let connected = false;
let lastUartCmd = null;
let lastUartTs = 0;
let blockSyncUntil = 0;

const pendingRequestsByZone = {};

const lastManualByZone = new Map();  


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
    if (lastUartCmd === key && (now - lastUartTs) < 300) {
        console.log('[RadioZone] skip duplicate UART cmd (VOL):', key);
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

        // setInterval(() => {
        //     publish(allCommandTopic, { get_status: true });
        // }, 30000);

        // setInterval(checkOfflineZones, 10000);
    });

    client.on('close', () => {
        connected = false;
        console.warn('⚠️ MQTT connection closed');
    });



    client.on('message', async (topic, message, packet) => {

        const lwtMatch = topic.match(/^mass-radio\/([^/]+)\/lwt$/);
        if (lwtMatch) {
            const payloadStr = message.toString();
            
            const target = lwtMatch[1]; 
            const zoneNumMatch = target.match(/^zone(\d+)$/);
            
            if (zoneNumMatch) {
                const no = parseInt(zoneNumMatch[1], 10);

                // 👉 เพิ่มการเช็คตรงนี้ครับ 👈
                if (payloadStr === 'offline') {
                    
                    console.log(`[LWT] 💀 Zone ${no} confirmed DEAD (Payload: ${payloadStr})`);

                    // 1. อัปเดต Memory
                    upsertDeviceStatus(no, { 
                        stream_enabled: false, 
                        is_playing: false, 
                        online: false 
                    });

                    // 2. อัปเดต DB
                    try {
                        await Device.findOneAndUpdate({ no }, {
                            $set: {
                                'status.stream_enabled': false,
                                'status.volume': 0,
                                'status.is_playing': false,
                                'status.playback_mode': 'none',
                            }
                        });
                    } catch(e) { console.error(e); }

                    // 3. สั่ง UART ดับไฟ
                    sendZoneUartCommand(no, false).catch(() => {});

                    // 4. แจ้งหน้าเว็บ
                    broadcast({
                        zone: no,
                        offline: true,
                        source: 'lwt'
                    });

                } else if (payloadStr === 'online') {
                    
                    console.log(`[LWT] 🐣 Zone ${no} is back ONLINE!`);
                    
                    // อัปเดต lastSeen ใน Memory ให้สดใหม่
                    const item = deviceStatus.find(d => d.zone === no);
                    if (item) {
                        item.lastSeen = Date.now();
                    }
                    
                    broadcast({
                        zone: no,
                        offline: false,
                        source: 'lwt'
                    });
                }
            }
            return; 
        }


        const payloadStr = message.toString();
        const m = topic.match(/^mass-radio\/(zone\d+)\/monitoring$/);

        if (m) {
            const nodeKey = m[1];
            const noFromTopic = parseInt(nodeKey.replace(/^zone/, ''), 10);

            console.log('[MQTT] incoming deviceData from', nodeKey, 'payload =', payloadStr);

            let json;
            try {
                json = JSON.parse(payloadStr);
            } catch (e) {
                console.error('[MQTT] invalid JSON for deviceData:', e.message);
                return;
            }

            try {
                const no =
                typeof json.no === 'number' && Number.isFinite(json.no)
                    ? json.no
                    : noFromTopic;

                const device = await Device.findOne({ no });
                if (!device) {
                    console.warn('[MQTT] device not found for no =', no, '(ยังคงบันทึก DeviceData โดยไม่ใส่ deviceId)');
                }

                const timestamp = json.timestamp ? new Date(json.timestamp) : new Date();

                const payloadForIngest = {
                    timestamp,
                    meta: {
                        no,
                        ...(device ? { deviceId: device._id } : {}),
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
                    lng: json.lng
                };


                // payload ={
                //     "vac": 213,
                //     "iac": 23,
                //     "wac": 13,
                //     "acfreq" 13,
                //     "acenergy": 213,
                //     "vdc": 221,
                //     "idc": 1.02,
                //     "wdc": 213,
                //     "flag": "$11",
                //     "oat": 1,
                //     "lat": 13.657844025619063,
                //     "lng": 100.66084924318992,  
                // }

                await deviceDataService.ingestOne(payloadForIngest);
                console.log('[MQTT] saved DeviceData via ingestOne for', nodeKey);

                if (device) {
                    device.lastSeen = timestamp;
                    await device.save();
                }
            } catch (err) {
                console.error('[MQTT] error while saving DeviceData:', err.message);
            }

            return;
        }

                // 1. Regex เดียว ดักจับทุกรูปแบบ (all / zone... / select)
        const cmdMatch = topic.match(/^mass-radio\/([^/]+)\/command$/);
        if (cmdMatch) {
            let json;
            const target = cmdMatch[1]; // ค่าที่ได้จะเป็น "all", "zone1", "select", "zone99"
            const payloadStr = message.toString();
            try {
                json = JSON.parse(payloadStr);
            } catch (e) {
                console.error(`[MQTT] Invalid JSON for ${target}/command:`, e.message);
                return;
            }
            if (!json || json.source === 'manual-panel' || json.get_status) return;
            if (json.source === 'node')
            // if (json.get_status) {
            //     console.log('📥 App requested sync via MQTT.');
            //     await requestAllStatus(); 
            //     return;
            // }
            if (target === 'select') {
                if (json.zone && Array.isArray(json.zone)) {
                    console.log(`📨 Received SELECT command for zones:`, json.zone);
                    json.zone.forEach(zoneNo => {
                        const zonePayload = { ...json };
                        delete zonePayload.zone; // ลบ array zone ออกก่อนส่งต่อ
                        publish(`mass-radio/zone${zoneNo}/command`, zonePayload);
                    });
                }
                return; 
            }
            let zoneNum = null;
            if (target === 'all') {
                zoneNum = 1111; 
            } else if (target.startsWith('zone')) {
                const numMatch = target.match(/\d+/); 
                if (numMatch) zoneNum = parseInt(numMatch[0], 10);
            }
            if (zoneNum !== null) {
                if (typeof json.set_stream === 'boolean') {
                    if (zoneNum === 1111) {
                        console.log(`[RadioZone] CMD -> UART (Zone ${zoneNum}): stream=${json.set_stream}`);
                        blockSyncUntil = Date.now() + 5000;
                    }
                    await sendZoneUartCommand(zoneNum, json.set_stream);
                } 
                else if (typeof json.set_volume === 'number') {
                    console.log(`[RadioZone] CMD -> UART (Zone ${zoneNum}): volume=${json.set_volume}`);
                    await sendVolUartCommand(zoneNum, json.set_volume);
                } 
                else {
                    console.warn(`[RadioZone] Ignore CMD Zone ${zoneNum}: Missing valid key`, json);
                }
            } else {
                console.warn(`[RadioZone] Unknown command target: ${target}`);
            }
            return;
        }

        const statusMatch = topic.match(/^mass-radio\/([^/]+)\/status$/);
        if (statusMatch) {
            let json;
            const target = statusMatch[1]; // ได้ค่า "all" หรือ "zone1", "zone2"
            const payloadStr = message.toString();
            if (!payloadStr.trim()) return; 
            try {
                json = JSON.parse(payloadStr);
            } catch (e) {
                console.error(`[MQTT] Invalid JSON on ${target}/status:`, e.message);
                return;
            }
            if (target === 'all') {
                const streamEnabled = !!json.stream_enabled;
                const now = Date.now();
                console.log('[RadioZone] ALL status -> set all zones to', streamEnabled ? 'ON' : 'OFF');
                deviceStatus = deviceStatus.map(d => ({
                    ...d,
                    data: {
                        ...d.data,
                        stream_enabled: streamEnabled,
                        is_playing: streamEnabled,
                    },
                    lastSeen: now,
                }));

                try {
                    await Device.updateMany({}, {
                        $set: {
                            'status.stream_enabled': streamEnabled,
                            'status.is_playing': streamEnabled,
                            lastSeen: new Date(),
                        },
                    });
                } catch (err) {
                    console.error('❌ DB UpdateMany failed:', err.message);
                }

                deviceStatus.forEach(d => {
                    broadcast({
                        zone: d.zone,
                        stream_enabled: streamEnabled,
                        is_playing: streamEnabled,
                        source: 'manual-all',
                    });
                });
                return;
            }

            const zoneNumMatch = target.match(/^zone(\d+)$/);
            if (zoneNumMatch) {
                const no = parseInt(zoneNumMatch[1], 10);

                // 1. จัดการ Retain Message (เคลียร์ทิ้งถ้าเป็นของเก่าค้างท่อ)
                if (packet.retain) {
                    if (!seenZones.has(target)) {
                        seenZones.add(target);
                        client.publish(topic, '', { qos: 1, retain: true }, () => {
                            console.log(`🧹 Cleared retained for ${target}`);
                        });
                    }
                    return;
                }
                if (pendingRequestsByZone[no]) {
                    pendingRequestsByZone[no].resolve({ zone: no, ...json });
                    delete pendingRequestsByZone[no];
                }
                const now = Date.now();
                const isManual = json.source === 'manual' || json.source === 'manual-panel';
                if (isManual) {
                    lastManualByZone.set(no, now);
                }
                const prev = getCurrentStatusOfZone(no);
                const prevStreamStatus = prev ? prev.stream_enabled : null;
                let merged = { ...json };
                const isFromManualPanel = merged.source === 'manual-panel'; 
                upsertDeviceStatus(no, merged);
                if (!isFromManualPanel && merged.stream_enabled !== undefined && merged.stream_enabled !== prevStreamStatus) {
                    
                    if (Date.now() < blockSyncUntil) {
                        return;
                    } else {
                        console.log(`[Sync] Node/Web changed status (Zone ${no}). Syncing to UART Machine...`);
                        sendZoneUartCommand(no, merged.stream_enabled).catch(err => {
                            console.error(`[RadioZone] UART sync error zone ${no}:`, err.message);
                        });
                    }

                } else if (isFromManualPanel) {
                    console.log(`[Sync] Action from Manual Panel (Zone ${no})`);
                }
                console.log(`✅ Response from zone ${no}:`, merged);
                broadcast({ zone: no, ...merged });
                updateDeviceInDB(no, merged);              
                return;
            }
        }
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
                    'status.is_playing': !!data.is_playing,
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

// async function checkOfflineZones() {
//     const now = Date.now();
//     const beforeCount = deviceStatus.length;

//     const onlineZones = [];
//     const offlineZones = [];

//     // กรณีที่ 1: ไม่มีข้อมูลใน Memory เลย (เช่น เพิ่งรีสตาร์ท Server)
//     if (deviceStatus.length === 0) {
//         // ส่วนนี้อาจจะเก็บไว้ หรือจะลบออกก็ได้ถ้าไม่อยากให้มัน Reset ทุกครั้งที่ Restart Service
//         // แต่ถ้าเก็บไว้ ต้องเพิ่มการสั่งปิด UART ด้วย
//         try {
//             await Device.updateMany(
//                 {},
//                 {
//                     $set: {
//                         'status.stream_enabled': false,
//                         'status.volume': 0,
//                         'status.is_playing': false,
//                         'status.playback_mode': 'none',
//                         // lastSeen: new Date() // ไม่ควรอัปเดต lastSeen ถ้ามัน offline
//                     }
//                 }
//             );

//             const allDevices = await Device.find({});
//             allDevices.forEach(d => {
//                 // 1. แจ้ง UI
//                 broadcast({
//                     zone: d.no,
//                     stream_enabled: false,
//                     volume: 0,
//                     is_playing: false,
//                     offline: true
//                 });
//             });
//             sendZoneUartCommand(1111, false).catch(err => {
//                 console.error('❌ UART error when marking all offline:', err.message);
//             });
//             console.log("⚠️ deviceStatus ว่าง → ตั้งค่าทุกโซนเป็น offline");
//         } catch (err) {
//             console.error("❌ Failed to mark all devices offline:", err.message);
//         }
//         return;
//     }

//     // กรองแยก Online / Offline
//     deviceStatus = deviceStatus.filter(d => {
//         const online = now - d.lastSeen <= 35000; // Timeout 35 วินาที
//         if (online) {
//             onlineZones.push(d.zone);
//         } else {
//             offlineZones.push(d.zone);
//         }
//         return online;
//     });

//     // กรณีที่ 2: มีบางโซนหลุด (Timeout)
//     try {
//         if (offlineZones.length > 0) {
//             console.log(`[Offline] Detected zones: ${offlineZones.join(', ')}`);

//             // อัปเดต Database
//             await Device.updateMany(
//                 { no: { $in: offlineZones } },
//                 {
//                     $set: {
//                         'status.stream_enabled': false,
//                         'status.volume': 0,
//                         'status.is_playing': false,
//                         'status.playback_mode': 'none',
//                     }
//                 }
//             );

//             // วนลูปแจ้งเตือนและสั่งปิดไฟ
//             offlineZones.forEach(zoneNo => {
//                 // ✅ 1. เพิ่มตรงนี้: สั่ง UART ให้ไฟดับทันทีเมื่อ Node หลุด
//                 console.log(`[Offline] Zone ${zoneNo} timed out. Sending OFF to UART.`);
//                 sendZoneUartCommand(zoneNo, false).catch(err => {
//                     console.error(`[Offline] UART error zone ${zoneNo}:`, err.message);
//                 });

//                 // 2. แจ้ง UI
//                 broadcast({
//                     zone: zoneNo,
//                     stream_enabled: false,
//                     volume: 0,
//                     is_playing: false,
//                     offline: true
//                 });
//             });
//         }
//     } catch (err) {
//         console.error('❌ Failed to update offline zones in DB:', err.message);
//     }

//     if (deviceStatus.length !== beforeCount) {
//         console.log(`⚠️ Removed offline zones. Active zones: ${deviceStatus.length}`);
//     }
// }

// async function checkOfflineZones() {
//     const now = Date.now();
    
//     // ❌ ลบส่วนที่เช็ค deviceStatus.length === 0 ออก หรือ comment ไว้ก่อนก็ได้ 
//     // เพื่อโฟกัสที่ Logic การจัดการ Offline รายตัว
    
//     const offlineZones = [];

//     // 1. วนลูปเช็ค Memory (ห้ามใช้ .filter เพื่อลบของออก!)
//     deviceStatus.forEach(d => {
//         const isOnline = (now - d.lastSeen) <= 35000; // 35 วินาที
        
//         if (!isOnline) {
//             // ถ้าหลุด.. ให้เก็บเข้า list ว่าจะไปจัดการ DB
//             offlineZones.push(d.zone);

//             // ✅ KEY FIX: อัปเดต Memory ให้เป็น "ปิด" (อย่าลบทิ้ง!)
//             // เพื่อให้ตอน UART ตอบกลับมา มันจะได้รู้ว่า "อ๋อ ค่าเดิมก็ปิดอยู่แล้ว" ไม่ต้องส่งซ้ำ
//             if (d.data) {
//                 d.data.stream_enabled = false;
//                 d.data.is_playing = false;
//                 // d.data.volume = 0; // จะรีเซ็ต volume ด้วยไหมแล้วแต่ดีไซน์
//             }
//         }
//     });

//     // 2. จัดการพวกที่ Offline (DB & UART)
//     if (offlineZones.length > 0) {
//         console.log(`[Offline] Detected zones: ${offlineZones.join(', ')}`);

//         try {
//             // Update Database
//             await Device.updateMany(
//                 { no: { $in: offlineZones } },
//                 {
//                     $set: {
//                         'status.stream_enabled': false,
//                         'status.volume': 0,
//                         'status.is_playing': false,
//                         'status.playback_mode': 'none',
//                     }
//                 }
//             );

//             // Send UART & Broadcast
//             offlineZones.forEach(zoneNo => {
//                 console.log(`[Offline] Zone ${zoneNo} timed out. Sending OFF to UART.`);
                
//                 // สั่ง UART (แบบไม่รอ)
//                 sendZoneUartCommand(zoneNo, false).catch(err => {
//                     console.error(`[Offline] UART error zone ${zoneNo}:`, err.message);
//                 });

//                 // แจ้ง UI
//                 broadcast({
//                     zone: zoneNo,
//                     stream_enabled: false,
//                     volume: 0,
//                     is_playing: false,
//                     offline: true
//                 });
//             });

//         } catch (err) {
//             console.error('❌ Offline update error:', err.message);
//         }
//     }
    
//     // ลบบรรทัดที่ log ว่า "Removed offline zones" ออก เพราะเราไม่ได้ remove แล้ว
// }

// async function requestAllStatus() {
//     console.log('[RadioZone] 🔄 Requesting FULL status from Manual Panel...');
//     try {
//         await uart.writeString('$G1111S$', 'ascii');
//     } catch (err) {
//         console.error('[RadioZone] Failed to request status:', err.message);
//     }
// }

module.exports = {
    connectAndSend,
    getStatus,
    publish,
    publishAndWaitByZone,
    upsertDeviceStatus
};
