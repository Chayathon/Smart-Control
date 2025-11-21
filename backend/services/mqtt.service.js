// D:\mass_smart_city\Smart-Control\backend\services\mqtt.service.js
const mqtt = require('mqtt');
const { broadcast } = require('../ws/wsServer');
const Device = require('../models/Device');
const DeviceData = require('../models/DeviceData'); // ยัง require ไว้เผื่อใช้ต่อยอด
const deviceDataService = require('../services/deviceData.service');

let deviceStatus = [];
let seenZones = new Set();
let client = null;
let connected = false;

const pendingRequestsByZone = {};

function connectAndSend({
  brokerUrl = 'mqtt://192.168.1.83:1883',
  username = 'admin',
  password = 'admin',
  commandTopic = 'mass-radio/all/command',
  statusTopic = 'mass-radio/+/status',
  dataTopic = 'mass-radio/+/data',
  payload = { set_stream: true },
} = {}) {
  deviceStatus = [];
  seenZones.clear();

  client = mqtt.connect(brokerUrl, {
    username,
    password,
    protocolVersion: 5,
    reconnectPeriod: 5000,
    clean: true,
  });

  client.on('connect', () => {
    connected = true;
    console.log('✅ MQTT connected');

    // subscribe data ของ node เพื่อบันทึก DeviceData
    client.subscribe(dataTopic, { qos: 1 }, (err) => {
      if (err) console.error('📥 subscribe mass-radio/+/data error:', err.message);
      else console.log('📥 subscribed mass-radio/+/data');
    });

    client.subscribe(statusTopic, { qos: 1 }, (err) => {
      if (err) console.error('❌ Subscribe error:', err.message);
      else console.log(`📥 Subscribed to ${statusTopic}`);
    });

    client.subscribe('mass-radio/select/command', { qos: 1 }, (err) => {
      if (err) console.error('❌ Subscribe error for select/command:', err.message);
      else console.log(`📥 Subscribed to mass-radio/select/command`);
    });

    setTimeout(() => {
      publish(commandTopic, payload);
    }, 1000);

    setInterval(() => {
      publish(commandTopic, { get_status: true });
    }, 30000);

    setInterval(checkOfflineZones, 10000);
  });

  client.on('close', () => {
    connected = false;
    console.warn('⚠️ MQTT connection closed');
  });

  client.on('message', async (topic, message, packet) => {
    const payloadStr = message.toString();

    // === 1) กรณี device data: mass-radio/noX/data ===
    const m = topic.match(/^mass-radio\/(no\d+)\/data$/);
    if (m) {
      const nodeKey = m[1]; // เช่น "no2"
      const noFromTopic = parseInt(nodeKey.replace(/^no/, ''), 10);

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

        // ✅ payload ที่ส่งเข้า ingestOne (ไม่มี topic และไม่มี field แปลก ๆ)
        const payloadForIngest = {
          timestamp,
          meta: {
            no,
            ...(device ? { deviceId: device._id } : {}),
          },

          dcV: json.dcV,
          dcW: json.dcW,
          dcA: json.dcA,

          oat: json.oat,
          lat: json.lat,
          lng: json.lng,

          type: json.type,
          flag: json.flag,
        };

        await deviceDataService.ingestOne(payloadForIngest);
        // console.log('[MQTT] saved DeviceData via ingestOne for', nodeKey);

        if (device) {
          device.lastSeen = timestamp;
          await device.save();
        }
      } catch (err) {
        console.error('[MQTT] error while saving DeviceData:', err.message);
      }

      return;
    }

    // === 2) กรณี select command ===
    if (topic === 'mass-radio/select/command') {
      if (!message || !payloadStr.trim()) return;
      try {
        const data = JSON.parse(payloadStr);
        console.log(`📨 Received select command:`, data);

        if (data.zone && Array.isArray(data.zone)) {
          data.zone.forEach((zoneNo) => {
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

    // === 3) กรณี status: mass-radio/zoneX/status ===
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

    if (!message || !payloadStr.trim()) return;

    try {
      const data = JSON.parse(payloadStr);

      if (pendingRequestsByZone[no]) {
        pendingRequestsByZone[no].resolve({ zone: no, ...data });
        delete pendingRequestsByZone[no];
      }

      upsertDeviceStatus(no, data);
      console.log(`✅ Response from zone ${no}:`, data);

      broadcast({ zone: no, ...data });
      updateDeviceInDB(no, data);
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
  const message =
    typeof payload === 'object' ? JSON.stringify(payload) : String(payload);
  client.publish(topic, message, opts, (err) => {
    if (err) console.error(`❌ Failed to publish ${topic}:`, err.message);
    else console.log(`📤 Published to ${topic}:`, message);
  });
}

function upsertDeviceStatus(no, data) {
  const now = Date.now();
  const index = deviceStatus.findIndex((d) => d.zone === no);

  if (index >= 0) {
    deviceStatus[index] = { zone: no, data, lastSeen: now };
  } else {
    deviceStatus.push({ zone: no, data, lastSeen: now });
  }
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
          lastSeen: new Date(),
        },
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
            lastSeen: new Date(),
          },
        }
      );

      const allDevices = await Device.find({});
      allDevices.forEach((d) => {
        broadcast({
          zone: d.no,
          stream_enabled: false,
          volume: 0,
          is_playing: false,
          offline: true,
        });
      });

      console.log('⚠️ deviceStatus ว่าง → ตั้งค่าทุกโซนเป็น offline');
    } catch (err) {
      console.error('❌ Failed to mark all devices offline:', err.message);
    }
    return;
  }

  deviceStatus = deviceStatus.filter((d) => {
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
            lastSeen: new Date(),
          },
        }
      );
      offlineZones.forEach((zoneNo) => {
        broadcast({
          zone: zoneNo,
          stream_enabled: false,
          volume: 0,
          is_playing: false,
          offline: true,
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
  publishAndWaitByZone,
};
