const stream = require('../services/stream.service');
const Song = require('../models/Song');
const path = require('path');
const axios = require('axios');
const cfg = require('../config/config');

function status(_req, res) {
    res.json({ status: 'success', data: stream.getStatus() });
}

async function streamAudio(req, res) {
    try {
        // Get Icecast stream URL from config
        const { icecast } = cfg;
        const streamUrl = `http://${icecast.host}:${icecast.port}${icecast.mount}`;
        
        console.log('📻 Client requesting audio stream, proxying from:', streamUrl);

        // Set headers for audio streaming
        res.setHeader('Content-Type', 'audio/mpeg');
        res.setHeader('Cache-Control', 'no-cache');
        res.setHeader('Connection', 'keep-alive');
        res.setHeader('Accept-Ranges', 'none');
        res.setHeader('icy-name', 'Smart Control Stream');

        // Retry logic: try to connect to Icecast with retries
        let lastError = null;
        const maxRetries = 3;
        const retryDelay = 1000; // 1 second

        for (let attempt = 0; attempt < maxRetries; attempt++) {
            try {
                console.log(`📻 Attempt ${attempt + 1}/${maxRetries} to connect to Icecast`);
                
                // Proxy the stream from Icecast
                const response = await axios({
                    method: 'get',
                    url: streamUrl,
                    responseType: 'stream',
                    timeout: 10000,
                    headers: {
                        'User-Agent': 'Smart-Control-Backend',
                        'Icy-MetaData': '1',
                    },
                    validateStatus: (status) => status === 200
                });

                console.log('✅ Successfully connected to Icecast stream');

                // Pipe the Icecast stream to the client
                response.data.pipe(res);

                // Handle errors
                response.data.on('error', (error) => {
                    console.error('❌ Stream pipe error:', error.message);
                    if (!res.headersSent) {
                        res.status(500).end();
                    }
                });

                req.on('close', () => {
                    console.log('🔌 Client disconnected from audio stream');
                    response.data.destroy();
                });

                return; // Success - exit function

            } catch (err) {
                lastError = err;
                console.warn(`⚠️ Attempt ${attempt + 1} failed:`, err.message);
                
                if (attempt < maxRetries - 1) {
                    await new Promise(resolve => setTimeout(resolve, retryDelay));
                }
            }
        }

        // All retries failed
        throw lastError;

    } catch (error) {
        console.error('❌ Error streaming audio after all retries:', error.message);
        
        if (!res.headersSent) {
            // Send a more helpful error message
            const streamStatus = stream.getStatus();
            const isPlaying = streamStatus.isPlaying || streamStatus.playlistMode;
            
            if (!isPlaying) {
                res.status(503).json({ 
                    status: 'error', 
                    message: 'ไม่มีเพลงกำลังเล่นในระบบ กรุณาเริ่มเล่นเพลงก่อน',
                    code: 'NO_ACTIVE_STREAM'
                });
            } else {
                res.status(503).json({ 
                    status: 'error', 
                    message: 'กำลังโหลด stream กรุณารอสักครู่แล้วลองใหม่',
                    code: 'STREAM_NOT_READY'
                });
            }
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
