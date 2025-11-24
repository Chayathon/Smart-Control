// services/radioZone.service.js
const uart = require('./uart.handle');
const mqttSvc = require('./mqtt.service');

/**
 * แปลง topic + payload จากฝั่งแอพ ให้เป็นคำสั่ง UART string
 *
 * รองรับ:
 * - set_stream   -> $SxxxxY$ / $SxxxxN$
 * - set_volume   -> $VxxxxVV$  (VV = 00–21)
 * - get_status   -> $GxxxxS$
 * - get_volume   -> $GxxxxV$
 *
 * topic:
 * - "mass-radio/zone1/command"
 * - "mass-radio/all/command"
 */
function buildUartCommandFromApp(topic, payload) {
  if (typeof topic !== 'string') return null;
  if (!payload || typeof payload !== 'object') return null;

  let zoneNum = null;

  if (topic === 'mass-radio/all/command') {
    zoneNum = 1111;
  } else {
    const m = topic.match(/^mass-radio\/zone(\d+)\/command$/);
    if (!m) return null;
    zoneNum = parseInt(m[1], 10);
    if (Number.isNaN(zoneNum)) return null;
  }

  const zone4 = String(zoneNum).padStart(4, '0');

  // 1) เปิด/ปิด stream (on/off)
  if (Object.prototype.hasOwnProperty.call(payload, 'set_stream')) {
    const flag = payload.set_stream ? 'Y' : 'N'; // Y=เปิด, N=ปิด
    return `$S${zone4}${flag}$`;
  }

  // 2) เซ็ต volume
  if (Object.prototype.hasOwnProperty.call(payload, 'set_volume')) {
    let vol = Number(payload.set_volume);
    if (!Number.isFinite(vol)) return null;
    // proto บอก max = 21, ปลอดภัยเราก็ clamp 0–21
    if (vol < 0) vol = 0;
    if (vol > 21) vol = 21;
    // const vol = String(vol).padStart(2, '0'); // 15 -> "15"
    return `$V${zone4}${vol}$`;
  }

  // 3) ขอ status ทุกโซนหรือโซนเดียว
  if (payload.get_status) {
    return `$G${zone4}S$`;
  }

  // 4) ขอ volume
  if (payload.get_volume) {
    return `$G${zone4}V$`;
  }

  return null;
}

/**
 * ใช้เรียกจาก controller เมื่อมีคำสั่งจากแอปเข้ามา
 * ถ้า map ได้ -> ส่ง UART
 */
// async function handleAppCommand(topic, payload) {
//   const cmd = buildUartCommandFromApp(topic, payload);
//   if (!cmd) {
//     // ไม่ใช่ topic/payload ที่เรารู้จัก -> ให้ controller ตัดสินใจว่าจะทำอะไรต่อ
//     return { handled: false };
//   }

//   await uart.writeString(cmd, 'ascii');
//   return { handled: true, cmd };
// }

/**
 * เช็คทุกโซนด้วย $G1111S$
 */
// async function checkAllZones() {
//   await uart.writeString('$G1111S$', 'ascii');
// }

/**
 * parse ข้อความที่กลับมาจากเครื่อง (RX)
 *
 * รูปแบบที่รองรับตอนนี้:
 * - $S0001Y$ / $S0001N$  -> stream on/off
 * - $V000115$            -> volume = 15 (สองหลักท้าย)
 *
 * GxxxxS / GxxxxV เป็นคำสั่งฝั่งไป (request) มากกว่า response
 * ปกติ response น่าจะมาในรูป S/V เหมือนกัน เลย parse S/V เป็นหลัก
 */
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
  m = s.match(/^\$V(\d{4})(\d{2})\$/);
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

/**
 * callback ตอนมี RX จาก UART
 * - log ออกมา
 * - publish raw ขึ้น MQTT topic 'radio/rsp' (เลียนแบบระบบเก่า)
 * - ถ้า parse ได้ -> publish zone status/volume เพิ่ม
 */
// function onRxFrame(frameBuf) {
//   const raw = frameBuf.toString('ascii');  // เช่น "$S0001Y$\r\n"
//   console.log('[RadioZone] UART RX frame (raw):', JSON.stringify(raw));

//   // 1) ทำเหมือนระบบเก่า: ส่ง raw ขึ้น MQTT ที่ topic radio/rsp
//   try {
//     mqttSvc.publish('radio/cmd', raw, { qos: 1, retain: false });
//     console.log('[RadioZone] MQTT TX -> [radio/cmd]', JSON.stringify(raw));
//   } catch (e) {
//     console.error('[RadioZone] MQTT publish error (radio/rsp):', e.message);
//   }

//   // 2) พยายาม parse ให้รู้ zone / status / volume
//   const parsed = parseStatusFrame(raw);
//   if (!parsed) {
//     return;
//   }

//   const { type, zone } = parsed;
//   const isAll = zone === 1111;

//   if (type === 'stream') {
//     const topicStatus = isAll
//       ? 'mass-radio/all/command'
//       : `mass-radio/zone${zone}/command`;

//     const payloadStatus = {
//       zone,
//       set_stream: parsed.set_stream,
//       source: 'manual', // กดจากเครื่อง
//       raw: parsed.raw,
//     };

//     try {
//       mqttSvc.publish(topicStatus, payloadStatus, { qos: 1, retain: false });
//       console.log(
//         '[RadioZone] MQTT TX ->',
//         topicStatus,
//         JSON.stringify(payloadStatus)
//       );
//     } catch (e) {
//       console.error('[RadioZone] MQTT publish error (status):', e.message);
//     }
//   } else if (type === 'volume') {
//     const topicVol = isAll
//       ? 'mass-radio/all/volume'
//       : `mass-radio/zone${zone}/volume`;

//     const payloadVol = {
//       zone,
//       volume: parsed.volume,
//       source: 'manual', // กดจากเครื่อง
//       raw: parsed.raw,
//     };

//     try {
//       mqttSvc.publish(topicVol, payloadVol, { qos: 1, retain: false });
//       console.log(
//         '[RadioZone] MQTT TX ->',
//         topicVol,
//         JSON.stringify(payloadVol)
//       );
//     } catch (e) {
//       console.error('[RadioZone] MQTT publish error (volume):', e.message);
//     }
//   }
// }

// function onRxFrame(frameBuf) {
//   const raw = frameBuf.toString('ascii');  // เช่น "$S0001Y$\r\n"
//   console.log('[RadioZone] UART RX frame (raw):', JSON.stringify(raw));

//   try {
//     mqttSvc.publish('radio/cmd', raw, { qos: 1, retain: false });
//     console.log('[RadioZone] MQTT TX -> [radio/cmd]', JSON.stringify(raw));
//   } catch (e) {
//     console.error('[RadioZone] MQTT publish error (radio/cmd):', e.message);
//   }

//   const parsed = parseStatusFrame(raw);
//   if (!parsed) {
//     return;
//   }

//   const { type, zone } = parsed;
//   const isAll = zone === 1111;

//   if (type === 'stream') {
//     const topicStatus = isAll
//       ? 'mass-radio/all/status'
//       : `mass-radio/zone${zone}/status`;

//     const payloadStatus = {
//       zone,
//       stream_enabled: parsed.set_stream,
//       // is_playing: parsed.set_stream,
//       source: 'manual', // กดจากเครื่อง
//       raw: parsed.raw,
//     };

//     try {
//       mqttSvc.publish(topicStatus, payloadStatus, { qos: 1, retain: false });
//       console.log(
//         '[RadioZone] MQTT TX ->',
//         topicStatus,
//         JSON.stringify(payloadStatus)
//       );
//     } catch (e) {
//       console.error('[RadioZone] MQTT publish error (status):', e.message);
//     }
//   } else if (type === 'volume') {
//     const topicCmd = isAll
//       ? 'mass-radio/all/status'
//       : `mass-radio/zone${zone}/status`;

//     const payloadCmd = {
//       zone,
//       set_volume: parsed.volume,
//       source: 'manual',
//       raw: parsed.raw,
//     };

//     try {
//       mqttSvc.publish(topicCmd, payloadCmd, { qos: 1, retain: false });
//       console.log(
//         '[RadioZone] MQTT TX -> (from panel VOL)',
//         topicCmd,
//         JSON.stringify(payloadCmd)
//       );
//     } catch (e) {
//       console.error('[RadioZone] MQTT publish error (panel->command VOL):', e.message);
//     }
//   }
// }
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
  }
}



/**
 * เรียกตอน start server เพื่อ:
 * - เปิด UART
 * - ลงทะเบียน callback รับ RX จากเครื่อง
 */
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

// helper สำหรับใช้สั่งโซนจาก code อื่นได้สะดวก
// async function setZone(zone, isOn) {
//   const topic = zone === 'all'
//     ? 'mass-radio/all/command'
//     : `mass-radio/zone${zone}/command`;

//   const payload = { set_stream: !!isOn };
//   const cmd = buildUartCommandFromApp(topic, payload);
//   if (!cmd) throw new Error('Cannot build UART command for zone');
//   await uart.writeString(cmd, 'ascii');
//   return { zone, isOn: !!isOn, cmd };
// }

module.exports = {
  initRadioZone,
  // handleAppCommand,
  // checkAllZones,
  // setZone,
  buildUartCommandFromApp,
};
