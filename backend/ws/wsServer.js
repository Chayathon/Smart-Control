// D:\mass_smart_city\Smart-Control\backend\ws\wsServer.js
const WebSocket = require('ws');
const { URL } = require('url');
const stream = require('../services/stream.service');
const micStream = require('../services/micStream.service');
const bus = require('../services/bus');
const Device = require('../models/Device');
const lineNotifyService = require('../services/line-notify.service');

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
    
    // TODO: Add authentication here (JWT token validation or IP whitelist)
    // Example: if (!validateAuth(req)) { ws.close(1008, 'Unauthorized'); return; }
    
    micStream.start(ws).catch(err => {
      console.error('❌ [mic] startMicStream error:', err);
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

    const onStatus = async (payload) => {
        const msg = JSON.stringify({ type: 'status', ...payload });
        for (const client of statusClients) {
            if (client.readyState === WebSocket.OPEN) {
                try { client.send(msg); } catch { }
            }
        }
        
        // Send LINE notifications for song events
        try {
            if (payload.event === 'started' && payload.extra?.title) {
                const songTitle = payload.extra.title;
                const mode = payload.activeMode || 'unknown';
                lineNotifyService.sendSongStarted(songTitle, mode).catch(err => 
                    console.error('LINE notification (started) error:', err)
                );
            } else if (payload.event === 'ended' || payload.event === 'playlist-ended') {
                const songTitle = payload.extra?.title || payload.currentUrl || '';
                const mode = payload.activeMode || 'unknown';
                lineNotifyService.sendSongEnded(songTitle, mode).catch(err => 
                    console.error('LINE notification (ended) error:', err)
                );
            }
        } catch (err) {
            console.error('LINE notification error:', err);
        }
    };
    
    const onScheduleStatus = async (payload) => {
        const msg = JSON.stringify({ type: 'schedule-status', ...payload });
        for (const client of statusClients) {
            if (client.readyState === WebSocket.OPEN) {
                try { client.send(msg); } catch { }
            }
        }
    };
    
    bus.on('status', onStatus);
    bus.on('schedule-status', onScheduleStatus);

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
