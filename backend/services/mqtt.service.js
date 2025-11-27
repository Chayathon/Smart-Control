const mqtt = require('mqtt');
const http = require('http');
const { broadcast } = require('../ws/wsServer');
const Device = require('../models/Device');
const DeviceData = require('../models/DeviceData');
const uart = require('./uart.handle');
const deviceDataService = require('../services/deviceData.service');
const cfg = require('../config/config');

let deviceStatus = [];
let seenZones = new Set();
let client = null;
let connected = false;
let lastUartCmd = null;
let lastUartTs = 0;
let blockSyncUntil = 0;

const pendingRequestsByZone = {};

const lastManualByZone = new Map();  

let lastIcecastPlaying = null;
let currentPlaybackMode = 'none';

// ฟังก์ชันเช็คสถานะ Icecast ว่ามี listener หรือไม่
function checkIcecastStatus() {
    return new Promise((resolve) => {
        const options = {
            hostname: cfg.icecast.host || 'localhost',
            port: cfg.icecast.port || 8000,
            path: '/status-json.xsl',
            method: 'GET',
            timeout: 3000
        };

        const req = http.request(options, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                try {
                    const json = JSON.parse(data);
                    const source = json.icestats?.source;
                    
                    // ถ้า source เป็น array หรือ object ให้เช็คว่ามี listener
                    let isPlaying = false;
                    if (Array.isArray(source)) {
                        isPlaying = source.some(s => s.listeners > 0);
                    } else if (source && typeof source === 'object') {
                        isPlaying = source.listeners > 0;
                    }
                    
                    resolve({ success: true, isPlaying, source });
                } catch (e) {
                    resolve({ success: false, isPlaying: false, error: e.message });
                }
            });
        });

        req.on('error', (err) => {
            resolve({ success: false, isPlaying: false, error: err.message });
        });

        req.on('timeout', () => {
            req.destroy();
            resolve({ success: false, isPlaying: false, error: 'timeout' });
        });

        req.end();
    });
}

// ฟังก์ชัน publish is_playing และ playback_mode ผ่าน MQTT และอัพเดต DB
async function publishPlaybackStatus(isPlaying, playbackMode) {
    const mode = playbackMode || 'none';
    
    // อัพเดต state ก่อน
    lastIcecastPlaying = isPlaying;
    currentPlaybackMode = mode;
    
    // อัพเดต DB ทุก device ที่ stream_enabled = true
    try {
        await Device.updateMany(
            { 'status.stream_enabled': true },
            {
                $set: {
                    'status.is_playing': isPlaying,
                    'status.playback_mode': mode
                }
            }
        );
        console.log(`📊 Updated DB: is_playing=${isPlaying}, playback_mode=${mode}`);
    } catch (err) {
        console.error('❌ Failed to update devices in DB:', err.message);
    }
    
    // Publish ผ่าน MQTT ไปยัง mass-radio/all/command
    if (client && connected) {
        const payload = {
            set_playback: true,
            is_playing: isPlaying,
            playback_mode: mode,
            source: 'server'
        };
        
        publish('mass-radio/all/command', payload);
        console.log(`📡 Published playback status: is_playing=${isPlaying}, mode=${mode}`);
    }
    
    // Broadcast ไปยัง WebSocket clients
    broadcast({
        type: 'playback_status',
        is_playing: isPlaying,
        playback_mode: mode,
        source: 'server'
    });
}

// ฟังก์ชันตั้งค่า playback_mode จากภายนอก
function setPlaybackMode(mode) {
    currentPlaybackMode = mode || 'none';
}

// ฟังก์ชันดึงสถานะ playback ปัจจุบัน
function getPlaybackStatus() {
    return {
        is_playing: lastIcecastPlaying || false,
        playback_mode: currentPlaybackMode || 'none'
    };
}

// ฟังก์ชันส่ง get_status ไปยังโซน พร้อม playback status ปัจจุบัน
async function requestGetStatus(zones = null) {
    if (!client || !connected) {
        console.error('❌ Cannot request get_status, MQTT not connected');
        return;
    }
    
    // รวม playback status ปัจจุบันใน payload
    const payload = { 
        get_status: true, 
        source: 'server',
        is_playing: lastIcecastPlaying || false,
        playback_mode: currentPlaybackMode || 'none'
    };
    
    if (zones && Array.isArray(zones) && zones.length > 0) {
        // ส่งไปยังโซนที่ระบุ
        for (const zone of zones) {
            const topic = `mass-radio/zone${zone}/command`;
            publish(topic, payload);
        }
        console.log(`📤 Requested get_status for zones: [${zones.join(', ')}] with playback_mode=${currentPlaybackMode}`);
    } else {
        // ส่งไปยังทุกโซน
        publish('mass-radio/all/command', payload);
        console.log(`📤 Requested get_status for all zones with playback_mode=${currentPlaybackMode}`);
    }
}

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
            // ข้าม message ที่มาจาก server เอง หรือ manual-panel หรือ get_status
            if (!json || json.source === 'manual-panel' || json.source === 'server' || json.get_status) return;
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
                else if (typeof json.set_playback === 'boolean') {
                    console.log(`[RadioZone] CMD -> MQTT (Zone ${zoneNum}): playback=${json.set_playback}`);
                    publish(topic, {
                        is_playing: json.set_playback,
                        playback_mode: json.playback_mode || 'none',
                    });
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
                
                // ถ้าโซนมี stream_enabled = true ให้ใส่ is_playing และ playback_mode จาก server
                let merged = { ...json };
                if (merged.stream_enabled === true) {
                    merged.is_playing = lastIcecastPlaying || false;
                    merged.playback_mode = currentPlaybackMode || 'none';
                } else {
                    // ถ้า stream_enabled = false ให้ is_playing = false
                    merged.is_playing = false;
                    merged.playback_mode = 'none';
                }
                
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
        const updateData = {
            'status.is_playing': !!data.is_playing,
            'status.stream_enabled': !!data.stream_enabled,
            'status.volume': data.volume ?? 0,
            lastSeen: new Date()
        };
        
        // เพิ่ม playback_mode ถ้ามีค่า
        if (data.playback_mode !== undefined) {
            updateData['status.playback_mode'] = data.playback_mode;
        }
        
        await Device.findOneAndUpdate(
            { no },
            { $set: updateData },
            { upsert: true, new: true }
        );
    } catch (err) {
        console.error(`❌ Failed to update device ${no} in DB:`, err.message);
    }
}

module.exports = {
    connectAndSend,
    getStatus,
    publish,
    publishAndWaitByZone,
    upsertDeviceStatus,
    checkIcecastStatus,
    publishPlaybackStatus,
    setPlaybackMode,
    requestGetStatus,
    getPlaybackStatus
};
