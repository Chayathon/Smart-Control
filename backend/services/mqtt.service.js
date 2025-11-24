const mqtt = require('mqtt');
const { broadcast } = require('../ws/wsServer');
const Device = require('../models/Device');
const DeviceData = require('../models/DeviceData');
const uart = require('./uart.handle');
// const deviceDataService = require('../services/deviceData.service');


let deviceStatus = [];
let seenZones = new Set();
let client = null;
let connected = false;
let lastUartCmd = null;
let lastUartTs = 0;

const pendingRequestsByZone = {};

const lastManualByZone = new Map();  


function connectAndSend({
    brokerUrl = 'mqtt://192.168.1.83:1883',
    username = 'admin',
    password = 'admin',
    commandTopic = 'mass-radio/all/command',
    statusTopic = 'mass-radio/+/status',
    dataTopic = 'mass-radio/+/data',
    payload = { set_stream: true }
    
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
            if (err) console.error('📥 subscribe mass-radio/+/data error:', err.message);
            else console.log('📥 subscribed mass-radio/+/data');
        });

        client.subscribe('mass-radio/+/command', { qos: 1 }, (err) => {
            if (err) console.error('❌ Subscribe error for zone/command:', err.message);
            else console.log('📥 Subscribed to mass-radio/+/command');
        });

        // client.subscribe(commandTopic, { qos: 1 }, (err) => {
        //     if (err) console.error('❌ Subscribe error for mass-radio/all/command:', err.message);
        //     else console.log('📥 Subscribed to mass-radio/all/command');
        // });

        client.subscribe(statusTopic, { qos: 1 }, (err) => {
            if (err) console.error('❌ Subscribe error:', err.message);
            else console.log(`📥 Subscribed to ${statusTopic}`);
        });

        client.subscribe('mass-radio/select/command', { qos: 1 }, (err) => {
            if (err) console.error('❌ Subscribe error for select/command:', err.message);
            else console.log(`📥 Subscribed to mass-radio/select/command`);
        });

        // setTimeout(() => {
        //     publish(commandTopic, payload);
        // }, 1000);

        setInterval(() => {
            publish(commandTopic, { get_status: true });
        }, 30000);

        setInterval(checkOfflineZones, 10000);
    });

    client.on('close', () => {
        connected = false;
        console.warn('⚠️ MQTT connection closed');
    });

    async function sendZoneUartCommand(zone, set_stream) {
        const zoneStr = String(zone).padStart(4, '0');
        const baseCmd = set_stream
            ? `$S${zoneStr}Y$`  // เปิดโซน
            : `$S${zoneStr}N$`; // ปิดโซน

        const now = Date.now();
        const key = `${baseCmd}`;

        // กันยิงซ้ำในเวลาใกล้ ๆ กัน (เช่น จาก 2 path พร้อมกัน)
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

        const baseCmd = `$V${zoneStr}${vol}$`;     // ex. $V011204$

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


    client.on('message', async (topic, message, packet) => {

        const payloadStr = message.toString();
        const m = topic.match(/^mass-radio\/(no\d+)\/data$/);

        if (m) {
            const nodeKey = m[1];
            const noFromTopic = parseInt(nodeKey.replace(/^no/, ''), 10);

            console.log('[MQTT] incoming deviceData from', nodeKey, 'payload =', payloadStr);

            let json;
            try {
                json = JSON.parse(payloadStr);
            } catch (e) {
                console.error('[MQTT] invalid JSON for deviceData:', e.message);
                return;
            }

            try {
                const no = typeof json.no === 'number' ? json.no : noFromTopic;

                const device = await Device.findOne({ no });
                if (!device) {
                    console.warn('[MQTT] device not found for no =', no, 'still saving deviceData without deviceId');
                }

                const timestamp = json.timestamp ? new Date(json.timestamp) : new Date();

                const doc = {
                    timestamp,
                    meta: {
                        no,
                        deviceId: device ? device._id : null,
                    },

                    dcV: json.dcV,
                    dcW: json.dcW,
                    dcA: json.dcA,

                    acV: json.acV,
                    acW: json.acW,
                    acA: json.acA,

                    oat: json.oat,
                    lat: json.lat,
                    lng: json.lng,

                    flag: json.flag,

                    type: json.type,

                    status: json.status || undefined,

                    no,
                };

                const saved = await DeviceData.create(doc);
                console.log('[MQTT] saved DeviceData for', nodeKey, '-> _id =', saved._id.toString());

                if (device) {
                    device.lastSeen = timestamp;
                    await device.save();
                }
            } catch (err) {
                console.error('[MQTT] error while saving DeviceData:', err.message);
            }

            return;
        }

        

        // ---------- 2) mass-radio/zoneX/command -> สั่ง UART ----------
        const allMatch = topic.match(/^mass-radio\/all\/command$/);
        if (allMatch) {
            let json;
            try {
                json = JSON.parse(payloadStr);
            } catch (e) {
                console.error('[MQTT] invalid JSON on all/command:', e.message, 'payload =', payloadStr);
                return;
            }

            if (json.get_status) return; // ข้ามคำสั่ง get_status

            // set_stream (เปิด/ปิดทุกโซน)
            const allZoneCode = 1111; 
            if (typeof json.set_stream === 'boolean') {
                // ใช้ 1111 ให้กลายเป็น $S1111Y$ / $S1111N$
                console.log(
                    '[RadioZone] ALL command -> UART (zone=1111):',
                    { set_stream: json.set_stream }
                );

                try {
                    await sendZoneUartCommand(allZoneCode, json.set_stream);
                } catch (err) {
                    console.error('[RadioZone] UART write error for ALL command:', err.message);
                }
                // set_voluem (ทุกโซน)
            } else if (typeof json.set_volume === 'number') { 
                console.log(
                    '[RadioZone] ALL command -> UART (zone=1111, volume):',
                    { set_volume: json.set_volume }
                );

                try {
                    await sendVolUartCommand(allZoneCode, json.set_volume);
                } catch (err) {
                    console.error('[RadioZone] UART write error for ALL volume command:', err.message);
                }

            } else {

                console.warn('[RadioZone] ignore ALL command: set_stream/set_Volume missing or invalid:', json);
            }
            return;            
        }
        

        // ---------- 3) mass-radio/zoneX/command -> สั่ง UART ----------
        const cmdMatch = topic.match(/^mass-radio\/zone(\d+)\/command$/);

        if (cmdMatch) {
            const zone = parseInt(cmdMatch[1], 10);

            let json;
            try {
                json = JSON.parse(payloadStr);
            } catch (e) {
                console.error('[MQTT] invalid JSON on zone command:', e.message, 'payload =', payloadStr);
                return;
            }

            if (json.get_status) {
                // publishAndWaitByZone(topic, { get_status: true });
                console.log("Return get_status for zone", zone);
                return;
            }

            // set_stream (เปิด/ปิดโซน)
            if (typeof json.set_stream === 'boolean') {
                // แปลง zone -> 4 หลัก เช่น 1 -> "0001", 12 -> "0012"
                // const zoneStr = String(zone).padStart(4, '0');
                // const cmd = json.set_stream
                //     ? `$S${zoneStr}Y$`  // เปิดโซน
                //     : `$S${zoneStr}N$`; // ปิดโซน

                // // console.log('[RadioZone] MQTT zone command -> UART:', {
                // //     zone,
                // //     set_stream: json.set_stream,
                // //     uartCmd: cmd,
                // // });

                // await sendZoneUartCommand(zone, cmd);
                // console.log('[RadioZone] sent UART command for zone', zone);
                // console.log('UART Command:', cmd);

                // // try {
                // //     await uart.writeString(cmd, 'ascii');
                // // } catch (err) {
                // //     console.error('[RadioZone] UART write error for zone command:', err.message);
                // // }
                await sendZoneUartCommand(zone, json.set_stream);
            } else if ( typeof json.set_volume === 'number') {
                await sendVolUartCommand(zone, json.set_volume);
            } else {
                console.warn('[RadioZone] ignore zone command: set_stream/set_volume missing or invalid:', json);
            }
            return;
        }


        if (topic === 'mass-radio/select/command') {
            if (!message || !message.toString().trim()) return;
            try {
                const data = JSON.parse(message.toString());
                console.log(`📨 Received select command:`, data);

                if (data.zone && Array.isArray(data.zone)) {
                    data.zone.forEach(zoneNo => {
                        const zoneTopic = `mass-radio/zone${zoneNo}/command`;
                        const zonePayload = { ...data };
                        delete zonePayload.zone;
                        publish(zoneTopic, zonePayload);
                        console.log(`📤 Forwarded to zone ${zoneNo}`);
                    });
                }
            } catch (err) {
                console.error(`❌ Failed to parse select command:`, err.message);
            }
            return;
        }
        

        if (topic === 'mass-radio/all/status') {
            if (!message || !message.toString().trim()) return;
            try {
                const data = JSON.parse(message.toString());
                const streamEnabled = !!data.stream_enabled;
                const now = Date.now();

                console.log('[RadioZone] ALL status from panel -> set all zones to', streamEnabled ? 'ON' : 'OFF');

                deviceStatus = deviceStatus.map(d => ({
                    ...d,
                    data: {
                        ...d.data,
                        stream_enabled: streamEnabled,
                        is_playing: streamEnabled,
                    },
                    lastSeen: now,
                }));

                await Device.updateMany(
                    {},
                    {
                        $set: {
                            'status.stream_enabled': streamEnabled,
                            'status.is_playing': streamEnabled,
                            lastSeen: new Date(),
                        },
                    }
                );

                deviceStatus.forEach(d => {
                    broadcast({
                        zone: d.zone,
                        stream_enabled: streamEnabled,
                        is_playing: streamEnabled,
                        source: 'manual-all',   // เผื่ออยากเอาไปใช้แยกใน UI
                    });
                });
            } catch (err) {
                console.error('❌ Failed to handle mass-radio/all/status:', err.message);
            }
            return; // อย่าให้หล่นไปเข้า logic status ปกติด้านล่าง
        }

        
        const match = topic.match(/mass-radio\/([^/]+)\/status/);
        const zoneStr = match ? match[1] : null;
        if (!zoneStr) return;

        const matchNum = zoneStr.match(/\d+/);
        const no = matchNum ? parseInt(matchNum[0], 10) : null;
        if (!no) {
            console.warn(`⚠️ Invalid zone number: ${zoneStr}`);
            return;
        }

        if (packet.retain) {
            if (!seenZones.has(zoneStr)) {
                seenZones.add(zoneStr);
                client.publish(topic, '', { qos: 1, retain: true }, () => {
                    console.log(`🧹 Cleared retained for ${zoneStr}`);
                });
            }
            return;
        }

        if (!message || !message.toString().trim()) return;

        // manual first logic
        try {
            const data = JSON.parse(message.toString());

            if (pendingRequestsByZone[no]) {
                pendingRequestsByZone[no].resolve({ zone: no, ...data });
                delete pendingRequestsByZone[no];
            }

            const now = Date.now();
            const isManual = data && data.source === 'manual';

            if (isManual) {
                lastManualByZone.set(no, now);
            }

            const prev = getCurrentStatusOfZone(no);

            let merged = { ...data };

            const lastManualTs = lastManualByZone.get(no);
            if (!isManual && lastManualTs && (now - lastManualTs) < 5000) {
                if (prev) {
                    merged.stream_enabled = prev.stream_enabled;
                    merged.is_playing = prev.is_playing;
                }
                console.log(
                    `[Status] protect manual state for zone ${no} (within 5s)`,
                );
            }

            upsertDeviceStatus(no, merged);
            console.log(`✅ Response from zone ${no}:`, merged);

            broadcast({ zone: no, ...merged });
            updateDeviceInDB(no, merged);
        } catch (err) {
            console.error(`❌ Failed to parse message from zone ${no}`, err.message);
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

async function checkOfflineZones() {
    const now = Date.now();
    const beforeCount = deviceStatus.length;

    const onlineZones = [];
    const offlineZones = [];

    if (deviceStatus.length === 0) {
        try {

            await Device.updateMany(
                {},
                {
                    $set: {
                        'status.stream_enabled': false,
                        'status.volume': 0,
                        'status.is_playing': false,
                        'status.playback_mode': 'none',
                        lastSeen: new Date()
                    }
                }
            );

            const allDevices = await Device.find({});
            allDevices.forEach(d => {
                broadcast({
                    zone: d.no,
                    stream_enabled: false,
                    volume: 0,
                    is_playing: false,
                    offline: true
                });
            });

            console.log("⚠️ deviceStatus ว่าง → ตั้งค่าทุกโซนเป็น offline");
        } catch (err) {
            console.error("❌ Failed to mark all devices offline:", err.message);
        }
        return;
    }

    deviceStatus = deviceStatus.filter(d => {
        const online = now - d.lastSeen <= 35000;
        if (online) {
            onlineZones.push(d.zone);
        } else {
            offlineZones.push(d.zone);
        }
        return online;
    });

    try {
        if (offlineZones.length > 0) {
            await Device.updateMany(
                { no: { $in: offlineZones } },
                {
                    $set: {
                        'status.stream_enabled': false,
                        'status.volume': 0,
                        'status.is_playing': false,
                        'status.playback_mode': 'none',
                        lastSeen: new Date()
                    }
                }
            );
            offlineZones.forEach(zoneNo => {
                broadcast({
                    zone: zoneNo,
                    stream_enabled: false,
                    volume: 0,
                    is_playing: false,
                    offline: true
                });
            });
        }
    } catch (err) {
        console.error('❌ Failed to update offline zones in DB:', err.message);
    }

    if (deviceStatus.length !== beforeCount) {
        console.log(`⚠️ Removed offline zones. Active zones: ${deviceStatus.length}`);
    }
}

module.exports = {
    connectAndSend,
    getStatus,
    publish,
    publishAndWaitByZone
};
