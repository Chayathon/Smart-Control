const stream = require('../services/stream.service');
const Song = require('../models/Song');
const path = require('path');
const axios = require('axios');
const cfg = require('../config/config');
const { PassThrough } = require('stream');

// Store active broadcast streams
const broadcastStreams = new Set();

function status(_req, res) {
    res.json({ status: 'success', data: stream.getStatus() });
}

async function streamAudio(req, res) {
    try {
        console.log('📻 Client requesting audio stream');
        
        // Check if there's an active stream
        const streamStatus = stream.getStatus();
        const isPlaying = streamStatus.isPlaying || streamStatus.playlistMode;
        
        if (!isPlaying) {
            return res.status(503).json({ 
                status: 'error', 
                message: 'ไม่มีเพลงกำลังเล่นในระบบ กรุณาเริ่มเล่นเพลงก่อน',
                code: 'NO_ACTIVE_STREAM'
            });
        }

        // Set headers for audio streaming
        res.setHeader('Content-Type', 'audio/mpeg');
        res.setHeader('Cache-Control', 'no-cache, no-store');
        res.setHeader('Connection', 'keep-alive');
        res.setHeader('Transfer-Encoding', 'chunked');
        res.setHeader('Accept-Ranges', 'none');
        res.setHeader('icy-name', 'Smart Control Stream');
        res.setHeader('icy-br', '128');

        console.log('✅ Client connected to audio stream');

        // Try to connect to Icecast stream
        try {
            const { icecast } = cfg;
            const streamUrl = `http://${icecast.host}:${icecast.port}${icecast.mount}`;
            
            console.log('📻 Connecting to Icecast:', streamUrl);

            const response = await axios({
                method: 'get',
                url: streamUrl,
                responseType: 'stream',
                timeout: 5000,
                headers: {
                    'User-Agent': 'Smart-Control-Backend',
                    'Icy-MetaData': '1',
                }
            });

            console.log('✅ Successfully connected to Icecast');

            // Create a passthrough to track this client
            const passThrough = new PassThrough();
            broadcastStreams.add(passThrough);

            // Pipe Icecast to this client
            response.data.pipe(passThrough).pipe(res);

            // Cleanup on disconnect
            const cleanup = () => {
                console.log('🔌 Client disconnected from audio stream');
                broadcastStreams.delete(passThrough);
                passThrough.destroy();
                response.data.destroy();
            };

            passThrough.on('error', cleanup);
            response.data.on('error', cleanup);
            req.on('close', cleanup);
            req.on('aborted', cleanup);

        } catch (icecastError) {
            console.error('❌ Icecast connection failed:', icecastError.message);
            
            if (!res.headersSent) {
                return res.status(503).json({ 
                    status: 'error', 
                    message: 'Stream กำลังเริ่มต้น กรุณารอสักครู่ (5-10 วินาที) แล้วลองใหม่',
                    code: 'STREAM_NOT_READY'
                });
            }
        }

    } catch (error) {
        console.error('❌ Error in streamAudio:', error.message);
        
        if (!res.headersSent) {
            res.status(500).json({ 
                status: 'error', 
                message: 'เกิดข้อผิดพลาดในการเชื่อมต่อ stream',
                code: 'INTERNAL_ERROR'
            });
        }
    }
}

async function enableStream(_req, res) {
    try {
        const result = await stream.enableStream();
        return res.json({ status: 'success', message: result.message });
    } catch (e) {
        console.error('Error enableStreamAll:', e);
        return res.status(500).json({ status: 'error', message: e.message || 'enable stream failed' });
    }
}

async function disableStream(_req, res) {
    try {
        const result = await stream.disableStream();
        return res.json({ status: 'success', message: result.message });
    } catch (e) {
        console.error('Error disableStreamAll:', e);
        return res.status(500).json({ status: 'error', message: e.message || 'disable stream failed' });
    }
}

async function startFile(req, res) {
    let filePath = req.query.path || req.body?.path;
    const songId = req.query.songId || req.body?.songId;
    try {
        let displayName = null;
        if (songId) {
            const song = await Song.findById(songId).lean();
            if (!song) return res.status(404).json({ status: 'error', message: 'Song not found' });
            
            filePath = path.join(__dirname, '../uploads', song.url || song.file || '');
            displayName = song.name || song.title || (song.url || song.file || '');
        }

        if (!filePath) return res.status(400).json({ status: 'error', message: 'path or songId is required' });

        if (!displayName) {
            displayName = path.basename(filePath);
        }

        await stream.startLocalFile(filePath, 0, { displayName });
        res.json({ status: 'success', filePath, name: displayName });
    } catch (e) {
        console.error('Error starting stream:', e);
        const status = (e.code === 'MODE_BUSY' || e.code === 'STREAM_DISABLED') ? 409 : 500;
        res.status(status).json({ status: 'error', message: e.message || 'start failed', code: e.code });
    }
}

async function startYoutube(req, res) {
    const youtubeUrl = req.query.url || req.body?.url;
    try {
        await stream.startYoutubeUrl(youtubeUrl);
        res.json({ status: 'success', youtubeUrl });
    } catch (e) {
        console.error('Error starting YouTube stream:', e);
        const status = (e.code === 'MODE_BUSY' || e.code === 'STREAM_DISABLED') ? 409 : 500;
        res.status(status).json({ status: 'error', message: e.message || 'start failed', code: e.code });
    }
}

async function startPlaylist(req, res) {
    try {
        const loop = req.query.loop === 'true' || req.body?.loop === true;
        const result = await stream.playPlaylist({ loop });
        return res.json({ status: 'success', message: result.message });
    } catch (e) {
        console.error('Error playPlaylist:', e);
        const status = (e.code === 'MODE_BUSY' || e.code === 'STREAM_DISABLED') ? 409 : 500;
        return res.status(status).json({ status: 'error', message: e.message || 'play playlist failed', code: e.code });
    }
}

async function pause(_req, res) {
    try {
        stream.pause();
        return res.json({ status: 'success', message: 'หยุดชั่วคราว' });
    } catch (e) {
        console.error('Error pausePlaylist:', e);
        return res.status(500).json({ status: 'error', message: e.message || 'pause failed' });
    }
}

async function resume(_req, res) {
    try {
        stream.resume();
        return res.json({ status: 'success', message: 'เล่นต่อ' });
    } catch (e) {
        console.error('Error resumePlaylist:', e);
        return res.status(500).json({ status: 'error', message: e.message || 'resume failed' });
    }
}

async function nextTrack(_req, res) {
    try {
        const result = await stream.nextTrack();
        if (!result.success) {
            return res.status(400).json({ status: 'error', message: result.message });
        }
        return res.json({ status: 'success', message: result.message });
    } catch (e) {
        console.error('Error nextTrack:', e);
        return res.status(500).json({ status: 'error', message: e.message || 'next failed' });
    }
}

async function prevTrack(_req, res) {
    try {
        const result = await stream.prevTrack();
        if (!result.success) {
            return res.status(400).json({ status: 'error', message: result.message });
        }
        return res.json({ status: 'success', message: result.message });
    } catch (e) {
        console.error('Error prevTrack:', e);
        return res.status(500).json({ status: 'error', message: e.message || 'prev failed' });
    }
}

async function stopAll(_req, res) {
    try {
        const result = await stream.stop();
        return res.json({ status: 'success', message: result.message });
    } catch (e) {
        console.error('Error stopPlaylist:', e);
        return res.status(500).json({ status: 'error', message: e.message || 'stop playlist failed' });
    }
}

module.exports = { 
    status,
    streamAudio,
    enableStream,
    disableStream,
    startFile,
    startYoutube,
    startPlaylist,
    pause,
    resume,
    nextTrack,
    prevTrack,
    stopAll,
};
