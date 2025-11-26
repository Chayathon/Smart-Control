// services/radioZone.service.js
const uart = require('./uart.handle');
const mqttSvc = require('./mqtt.service');
// const Device = require('../models/device.service');

function parseStatusFrame(rawStr) {
  const s = rawStr.trim(); // ตัด \r\n, space

  // Stream on/off
  let m = s.match(/^\$S(\d{4})([YN])\$/);
  if (m) {
    const zone4 = m[1];
    const flag = m[2];
    const zoneNum = parseInt(zone4, 10);

    return {
      type: 'stream',
      zone: zoneNum,
      set_stream: flag === 'Y',
      raw: s,
    };
  }

  // Volume
  m = s.match(/^\$V(\d{4})(\d{1,2})\$/);
  if (m) {
    const zone4 = m[1];
    const vol = m[2];
    const zoneNum = parseInt(zone4, 10);
    const volume = parseInt(vol, 10);

    return {
      type: 'volume',
      zone: zoneNum,
      volume,
      raw: s,
    };
  }

  return null;
}

function onRxFrame(frameBuf) {
  const raw = frameBuf.toString('ascii');  // "$S0001Y$\r\n"
  console.log('[RadioZone] UART RX frame (raw):', JSON.stringify(raw));

  // log เดิม
  try {
    mqttSvc.publish('radio/cmd', raw, { qos: 1, retain: false });
    console.log('[RadioZone] MQTT TX -> [radio/cmd]', JSON.stringify(raw));
  } catch (e) {
    console.error('[RadioZone] MQTT publish error (radio/cmd):', e.message);
  }

  const parsed = parseStatusFrame(raw);
  if (!parsed) return;

  const { type, zone } = parsed;
  const isAll = zone === 1111;

  if (type === 'stream') {
    // 👉 1) แปลงการกด panel → command ให้ node
    if (isAll) {
      const cmdPayload = {
        set_stream: parsed.set_stream,
        source: 'manual-panel',   // สำคัญมาก
      };
      mqttSvc.publish('mass-radio/all/command', cmdPayload, { qos: 1, retain: false });
      console.log(
        '[RadioZone] MQTT TX (CMD ALL) -> mass-radio/all/command',
        JSON.stringify(cmdPayload)
      );
    } else {
      const topicCmd = `mass-radio/zone${zone}/command`;
      const cmdPayload = {
        set_stream: parsed.set_stream,
        source: 'manual-panel',   // สำคัญมาก
      };
      mqttSvc.publish(topicCmd, cmdPayload, { qos: 1, retain: false });
      console.log(
        '[RadioZone] MQTT TX (CMD) ->',
        topicCmd,
        JSON.stringify(cmdPayload)
      );
    }

    // 👉 2) ถ้าอยากยิง status ให้ UI/DB ด้วยก็ทำเพิ่ม (ไม่จำเป็นต่อ node)
    const topicStatus = isAll
      ? 'mass-radio/all/status'
      : `mass-radio/zone${zone}/status`;

    const payloadStatus = {
      zone,
      stream_enabled: parsed.set_stream,
      is_playing: parsed.set_stream,
      source: 'manual-panel',
      raw: parsed.raw,
    };

    try {
      mqttSvc.publish(topicStatus, payloadStatus, { qos: 1, retain: false });
      console.log(
        '[RadioZone] MQTT TX (STATUS) ->',
        topicStatus,
        JSON.stringify(payloadStatus)
      );
    } catch (e) {
      console.error('[RadioZone] MQTT publish error (status):', e.message);
    }
  } else if (type === 'volume') {
    // 3.1 ส่งเป็น "คำสั่ง volume" ให้โหนด – ผ่าน /command
    if (isAll) {
      const cmdPayload = {
        set_volume: parsed.volume,
        source: 'manual-panel',
      };
      mqttSvc.publish('mass-radio/all/command', cmdPayload, { qos: 1, retain: false });
      console.log(
        '[RadioZone] MQTT TX (CMD ALL volume) -> mass-radio/all/command',
        JSON.stringify(cmdPayload)
      );
    } else {
      const topicCmd = `mass-radio/zone${zone}/command`;
      const cmdPayload = {
        set_volume: parsed.volume,
        source: 'manual-panel',
      };
      mqttSvc.publish(topicCmd, cmdPayload, { qos: 1, retain: false });
      console.log(
        '[RadioZone] MQTT TX (CMD volume) ->',
        topicCmd,
        JSON.stringify(cmdPayload)
      );
    }

    // 3.2 ส่งเป็น "status" ให้ UI/DB เห็น volume ใหม่ผ่าน /status
    const topicStatus = isAll
      ? 'mass-radio/all/status'
      : `mass-radio/zone${zone}/status`;

    const payloadStatus = {
      zone,
      volume: parsed.volume,
      source: 'manual-panel',
      raw: parsed.raw,
    };

    try {
      mqttSvc.publish(topicStatus, payloadStatus, { qos: 1, retain: false });
      console.log(
        '[RadioZone] MQTT TX (STATUS volume) ->',
        topicStatus,
        JSON.stringify(payloadStatus)
      );
    } catch (e) {
      console.error('[RadioZone] MQTT publish error (status volume):', e.message);
    }
  }
}


// function onRxFrame(frameBuf) {
//     const raw = frameBuf.toString('ascii').trim();

//     if (raw.length > 10 && /^[YN]+$/.test(raw)) {
//         console.log('[RadioZone] Detected Bulk Status String!');
//         handleRawBulkStatus(raw);
//         return; 
//     }

//     console.log('[RadioZone] UART RX frame (raw):', JSON.stringify(raw));
    
//    try {
//     mqttSvc.publish('radio/cmd', raw, { qos: 1, retain: false });
//     console.log('[RadioZone] MQTT TX -> [radio/cmd]', JSON.stringify(raw));
//   } catch (e) {
//     console.error('[RadioZone] MQTT publish error (radio/cmd):', e.message);
//   }

//   const parsed = parseStatusFrame(raw);
//   if (!parsed) return;

//   const { type, zone } = parsed;
//   const isAll = zone === 1111;

//   if (type === 'stream') {
//     // 👉 1) แปลงการกด panel → command ให้ node
//     if (isAll) {
//       const cmdPayload = {
//         set_stream: parsed.set_stream,
//         source: 'manual-panel',   // สำคัญมาก
//       };
//       mqttSvc.publish('mass-radio/all/command', cmdPayload, { qos: 1, retain: false });
//       console.log(
//         '[RadioZone] MQTT TX (CMD ALL) -> mass-radio/all/command',
//         JSON.stringify(cmdPayload)
//       );
//     } else {
//       const topicCmd = `mass-radio/zone${zone}/command`;
//       const cmdPayload = {
//         set_stream: parsed.set_stream,
//         source: 'manual-panel',   // สำคัญมาก
//       };
//       mqttSvc.publish(topicCmd, cmdPayload, { qos: 1, retain: false });
//       console.log(
//         '[RadioZone] MQTT TX (CMD) ->',
//         topicCmd,
//         JSON.stringify(cmdPayload)
//       );
//     }

//     // 👉 2) ถ้าอยากยิง status ให้ UI/DB ด้วยก็ทำเพิ่ม (ไม่จำเป็นต่อ node)
//     const topicStatus = isAll
//       ? 'mass-radio/all/status'
//       : `mass-radio/zone${zone}/status`;

//     const payloadStatus = {
//       zone,
//       stream_enabled: parsed.set_stream,
//       is_playing: parsed.set_stream,
//       source: 'manual-panel',
//       raw: parsed.raw,
//     };

//     try {
//       mqttSvc.publish(topicStatus, payloadStatus, { qos: 1, retain: false });
//       console.log(
//         '[RadioZone] MQTT TX (STATUS) ->',
//         topicStatus,
//         JSON.stringify(payloadStatus)
//       );
//     } catch (e) {
//       console.error('[RadioZone] MQTT publish error (status):', e.message);
//     }
//   } else if (type === 'volume') {
//     // 3.1 ส่งเป็น "คำสั่ง volume" ให้โหนด – ผ่าน /command
//     if (isAll) {
//       const cmdPayload = {
//         set_volume: parsed.volume,
//         source: 'manual-panel',
//       };
//       mqttSvc.publish('mass-radio/all/command', cmdPayload, { qos: 1, retain: false });
//       console.log(
//         '[RadioZone] MQTT TX (CMD ALL volume) -> mass-radio/all/command',
//         JSON.stringify(cmdPayload)
//       );
//     } else {
//       const topicCmd = `mass-radio/zone${zone}/command`;
//       const cmdPayload = {
//         set_volume: parsed.volume,
//         source: 'manual-panel',
//       };
//       mqttSvc.publish(topicCmd, cmdPayload, { qos: 1, retain: false });
//       console.log(
//         '[RadioZone] MQTT TX (CMD volume) ->',
//         topicCmd,
//         JSON.stringify(cmdPayload)
//       );
//     }

//     // 3.2 ส่งเป็น "status" ให้ UI/DB เห็น volume ใหม่ผ่าน /status
//     const topicStatus = isAll
//       ? 'mass-radio/all/status'
//       : `mass-radio/zone${zone}/status`;

//     const payloadStatus = {
//       zone,
//       volume: parsed.volume,
//       source: 'manual-panel',
//       raw: parsed.raw,
//     };

//     try {
//       mqttSvc.publish(topicStatus, payloadStatus, { qos: 1, retain: false });
//       console.log(
//         '[RadioZone] MQTT TX (STATUS volume) ->',
//         topicStatus,
//         JSON.stringify(payloadStatus)
//       );
//     } catch (e) {
//       console.error('[RadioZone] MQTT publish error (status volume):', e.message);
//     }
//   }
// }



// async function handleRawBulkStatus(rawString) {
//     const totalZones = rawString.length;
//     console.log(`[Bulk] Processing status for ${totalZones} zones...`);

//     const bulkOps = [];
//     const now = Date.now();
//     const updatesForBroadcast = [];

//     for (let i = 0; i < totalZones; i++) {
//         const char = rawString[i];
//         const zoneNum = i + 1; // Map Index 0 -> Zone 1
        
//         let streamEnabled = false;
//         if (char === 'Y') streamEnabled = true;
//         else if (char === 'N') streamEnabled = false;
//         else continue; // ข้ามตัวอักษรขยะ

//         // 1. เตรียมข้อมูลลง DB (ยังไม่ยิง)
//         bulkOps.push({
//             updateOne: {
//                 filter: { no: zoneNum },
//                 update: {
//                     $set: {
//                         'status.stream_enabled': streamEnabled,
//                         'status.is_playing': streamEnabled, 
//                         lastSeen: new Date()
//                     }
//                 }
//             }
//         });

//         mqttSvc.upsertDeviceStatus(zoneNum, {
//             stream_enabled: streamEnabled,
//             is_playing: streamEnabled,
//             source: 'hardware-scan'
//         });

//         updatesForBroadcast.push({ zone: zoneNum, val: streamEnabled });
//     }


//     if (bulkOps.length > 0) {
//         try {
//             await Device.bulkWrite(bulkOps);
//             console.log(`[Bulk] ✅ Database updated successfully (${bulkOps.length} zones).`);


//             broadcast({
//                 type: 'FULL_STATE_UPDATE', 
//                 data: updatesForBroadcast  
//             });

//         } catch (err) {
//             console.error('[Bulk] ❌ Database Error:', err.message);
//         }
//     }
// }


async function initRadioZone() {
  console.log('[RadioZone] initRadioZone() ...');
  const ok = await uart.initialize();
  console.log('[RadioZone] UART init ok =', ok);

  if (!ok) {
    console.error('[RadioZone] ⚠️ UART init failed – โปรดเช็คสาย/PORT');
    return;
  }

  uart.registerRxCallback(onRxFrame);
}



module.exports = {
  initRadioZone
};
