// controllers/mqtt.controller.js
const mqttSvc = require('../services/mqtt.service');

async function publish(req, res) {
  const { topic, payload, qos = 1, retain = false } = req.body || {};

  if (!topic) {
    return res.status(400).json({ error: 'Topic is required' });
  }
  

  const isZoneCmd = /^mass-radio\/zone\d+\/command$/.test(topic);

  const isDeviceData = /^mass-radio\/zone\d+\/monitoring$/.test(topic);

  const isDeviceLtw = /^mass-radio\/zone\d+\/ltw$/.test(topic);

  const isSpecialCmd = ['mass-radio/select/command', 'mass-radio/all/command'].includes(topic);

  const isZoneBulkTest = /^mass-radio\/test\/bulk$/.test(topic);

  if (!isZoneCmd && !isDeviceData && !isSpecialCmd && !isZoneBulkTest && !isDeviceLtw) {
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
    let uartResult = null;
    try {
      mqttSvc.publish(topic, payload, { qos, retain });
    } catch (e) {
      console.error('[publish] MQTT publish error:', e.message);
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
