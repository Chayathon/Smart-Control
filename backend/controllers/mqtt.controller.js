// controllers/mqtt.controller.js
const mqttSvc = require('../services/mqtt.service');
const radioZone = require('../services/radioZone.service');

/**
 * รับจากแอปเป็น JSON:
 * {
 *   "topic": "mass-radio/zone1/command",
 *   "payload": { "set_stream": false },
 *   "qos": 1,
 *   "retain": false
 * }
 *
 * จากนั้น:
 * 1) พยายาม map command -> UART (เช่น $S0001N$) ผ่าน radioZone.handleAppCommand()
 * 2) ยัง publish ไป MQTT ตามเดิม (ถ้าต้องการ)
 */
async function publish(req, res) {
  const { topic, payload, qos = 1, retain = false } = req.body || {};

  if (!topic) {
    return res.status(400).json({ error: 'Topic is required' });
  }
  

  const isZoneCmd = /^mass-radio\/zone\d+\/command$/.test(topic);

  const isDeviceData = /^mass-radio\/no\d+\/data$/.test(topic);

  const isSpecialCmd = ['mass-radio/select/command', 'mass-radio/all/command'].includes(topic);

  if (!isZoneCmd && !isDeviceData && !isSpecialCmd) {
    console.warn(`[publish] Blocked invalid topic: ${topic}`);
    return res.status(400).json({ 
      error: 'Invalid topic format', 
    });
  }
  // ----------------------------------------

  if (typeof payload === 'undefined') {
    return res.status(400).json({ error: 'Payload is required' });
  }

  try {
    // 1) ส่งเข้า radioZone เพื่อดูว่าจะต้องแปลงเป็น UART ไหม
    let uartResult = null;
    try {
      uartResult = await radioZone.handleAppCommand(topic, payload);
    } catch (e) {
      console.error('[publish] UART handle error:', e.message);
    }

    // 2) ยัง publish ไป MQTT ตามเดิม (ถ้าไม่ต้องการก็ comment ทิ้งได้)
    // ตรงนี้สำคัญ: สำหรับ /data โค้ดจะวิ่งมาทำงานบรรทัดนี้ และส่งเข้า MQTT -> Service รับไปลง Mongo
    try {
      mqttSvc.publish(topic, payload, { qos, retain });
    } catch (e) {
      console.error('[publish] MQTT publish error:', e.message);
      // ไม่ throw ต่อ เพื่อให้ UART ยังทำงานแม้ MQTT ล้มเหลว
    }

    res.json({
      ok: true,
      topic,
      payload,
      qos,
      retain,
      uart: uartResult,
    });
  } catch (e) {
    console.error('[publish] fatal error:', e);
    res
      .status(500)
      .json({ error: 'Publish failed', details: e.message });
  }
}

async function publishGetStatusAndWait(req, res) {
  const { zone } = req.body;
  if (!zone) return res.status(400).json({ error: 'Missing zone' });

  try {
    const result = await mqttSvc.publishAndWaitByZone(
      `mass-radio/zone${zone}/command`,
      {
        get_status: true,
      }
    );
    res.json(result);
  } catch (err) {
    res
      .status(500)
      .json({ error: 'Publish failed', details: err.message });
  }
}

async function getStatus(req, res) {
  try {
    res.json(mqttSvc.getStatus());
  } catch (err) {
    res
      .status(500)
      .json({ error: 'Get status failed', details: err.message });
  }
}

module.exports = { publish, publishGetStatusAndWait, getStatus };
