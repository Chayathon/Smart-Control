const WebSocket = require('ws');
const { URL } = require('url');
const stream = require('../services/stream.service');
const bus = require('../services/bus');
const Device = require('../models/Device');

let wssMic;
let wssStatus;
const statusClients = new Set();

function createWSServer(server) {

    wssMic = new WebSocket.Server({ noServer: true /*, perMessageDeflate: false*/ });
    wssStatus = new WebSocket.Server({ noServer: true /*, perMessageDeflate: false*/ });


    wssMic.on('connection', (ws) => {
        console.log('🔌 [mic] client connected');
        stream.startMicStream(ws).catch(err => {
            console.error('[mic] startMicStream error:', err);
            try { ws.close(1011, 'internal error'); } catch { }
        });
        ws.on('close', () => console.log('❌ [mic] client disconnected'));
        ws.on('error', (err) => console.error('⚠️ [mic] error:', err.message));
    });

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

        // Update devices' playing_mode in DB using the authoritative stream status
        try {
            const s = stream.getStatus();
            const mode = s.activeMode || 'none';
            // Only update playing_mode to reflect current central play mode; do not touch lastSeen
            await Device.updateMany({}, { $set: { 'status.playback_mode': mode } });
        } catch (e) {
            console.error('⚠️ Failed to update devices playing_mode:', e.message || e);
        }
    };
    bus.on('status', onStatus);

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
        } else {
            socket.write('HTTP/1.1 404 Not Found\r\n\r\n');
            socket.destroy();
        }
    });


    setInterval(() => {
        for (const s of [wssMic, wssStatus]) {
            s.clients.forEach((ws) => {
                if (ws.isAlive === false) return ws.terminate();
                ws.isAlive = false;
                try { ws.ping(); } catch { }
            });
        }
    }, 30000);

    [wssMic, wssStatus].forEach((s) => {
        s.on('connection', (ws) => {
            ws.isAlive = true;
            ws.on('pong', () => (ws.isAlive = true));
        });
    });

    console.log('✅ WebSocket endpoints ready: /ws/mic  &  /ws/status');
}

function broadcast(data) {
    if (!wssStatus) return;
    const msg = typeof data === 'string' ? data : JSON.stringify(data);
    for (const client of statusClients) {
        if (client.readyState === WebSocket.OPEN) {
            try { client.send(msg); } catch { }
        }
    }
}

module.exports = { createWSServer, broadcast };
