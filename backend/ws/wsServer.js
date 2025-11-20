// D:\mass_smart_city\Smart-Control\backend\ws\wsServer.js
const WebSocket = require('ws');
const { URL } = require('url');
const stream = require('../services/stream.service');
const bus = require('../services/bus');
const Device = require('../models/Device');

let wssMic;
let wssStatus;
let wssDeviceData;                 // 🔹 NEW
const statusClients = new Set();
const deviceDataClients = new Set(); // 🔹 NEW

function createWSServer(server) {
  wssMic = new WebSocket.Server({ noServer: true /*, perMessageDeflate: false*/ });
  wssStatus = new WebSocket.Server({ noServer: true /*, perMessageDeflate: false*/ });
  wssDeviceData = new WebSocket.Server({ noServer: true /*, perMessageDeflate: false*/ }); // 🔹 NEW

  // --- mic ---
  wssMic.on('connection', (ws) => {
    console.log('🔌 [mic] client connected');
    stream.startMicStream(ws).catch(err => {
      console.error('[mic] startMicStream error:', err);
      try { ws.close(1011, 'internal error'); } catch {}
    });
    ws.on('close', () => console.log('❌ [mic] client disconnected'));
    ws.on('error', (err) => console.error('⚠️ [mic] error:', err.message));
  });

  // --- status ---
  wssStatus.on('connection', (ws) => {
    console.log('🔎 [status] client connected');
    statusClients.add(ws);
    ws.on('close', () => {
      statusClients.delete(ws);
      console.log('👋 [status] client disconnected');
    });
    ws.on('error', (err) => console.error('⚠️ [status] error:', err.message));
  });

  // --- device-data (NEW) ---
  wssDeviceData.on('connection', (ws) => {
    console.log('📡 [deviceData] client connected');
    deviceDataClients.add(ws);
    ws.on('close', () => {
      deviceDataClients.delete(ws);
      console.log('👋 [deviceData] client disconnected');
    });
    ws.on('error', (err) => console.error('⚠️ [deviceData] error:', err.message));
  });

  // broadcast for status (เดิม)
  const onStatus = async (payload) => {
    const msg = JSON.stringify({ type: 'status', ...payload });
    for (const client of statusClients) {
      if (client.readyState === WebSocket.OPEN) {
        try { client.send(msg); } catch {}
      }
    }

    // อัปเดต playback_mode ให้ทุก device ตาม engine
    try {
      const s = stream.getStatus();
      const mode = s.activeMode || 'none';
      await Device.updateMany({}, { $set: { 'status.playback_mode': mode } });
    } catch (e) {
      console.error('⚠️ Failed to update devices playback_mode:', e.message || e);
    }
  };
  bus.on('status', onStatus);

  // --- HTTP upgrade router ---
  server.on('upgrade', (req, socket, head) => {
    let pathname = '/';
    try {
      pathname = new URL(req.url, `http://${req.headers.host}`).pathname;
    } catch (_) {
      socket.destroy();
      return;
    }
    if (pathname === '/ws/mic') {
      wssMic.handleUpgrade(req, socket, head, (ws) => wssMic.emit('connection', ws, req));
    } else if (pathname === '/ws/status') {
      wssStatus.handleUpgrade(req, socket, head, (ws) => wssStatus.emit('connection', ws, req));
    } else if (pathname === '/ws/device-data') { // 🔹 NEW
      wssDeviceData.handleUpgrade(req, socket, head, (ws) => wssDeviceData.emit('connection', ws, req));
    } else {
      socket.write('HTTP/1.1 404 Not Found\r\n\r\n');
      socket.destroy();
    }
  });

  // keepalive สำหรับทุกกลุ่ม
  setInterval(() => {
    for (const s of [wssMic, wssStatus, wssDeviceData]) { // 🔹 NEW
      s.clients.forEach((ws) => {
        if (ws.isAlive === false) return ws.terminate();
        ws.isAlive = false;
        try { ws.ping(); } catch {}
      });
    }
  }, 30000);

  [wssMic, wssStatus, wssDeviceData].forEach((s) => { // 🔹 NEW
    s.on('connection', (ws) => {
      ws.isAlive = true;
      ws.on('pong', () => (ws.isAlive = true));
    });
  });

  console.log('✅ WebSocket endpoints ready: /ws/mic  &  /ws/status  &  /ws/device-data'); // 🔹 NEW
}

// broadcast สำหรับ status (เดิม)
function broadcast(data) {
  if (!wssStatus) return;
  const msg = typeof data === 'string' ? data : JSON.stringify(data);
  for (const client of statusClients) {
    if (client.readyState === WebSocket.OPEN) {
      try { client.send(msg); } catch {}
    }
  }
}

// 🔹 NEW: broadcast เฉพาะ deviceData (ถ้าบางจุดอยากยิงตรง)
function broadcastDeviceData(data) {
  if (!wssDeviceData) return;
  const msg = typeof data === 'string' ? data : JSON.stringify(data);
  for (const client of deviceDataClients) {
    if (client.readyState === WebSocket.OPEN) {
      try { client.send(msg); } catch {}
    }
  }
}

module.exports = { createWSServer, broadcast, broadcastDeviceData };
