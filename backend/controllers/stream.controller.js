const stream = require('../services/stream.service');
const Song = require('../models/Song');
const path = require('path');
const { getStreamEnabled } = require('../services/device.service');

async function assertStreamingEnabled(res) {
    const enabled = await getStreamEnabled();
    if (!enabled) {
        res.status(403).json({ status: 'error', code: 'STREAM_DISABLED', message: 'Streaming is disabled' });
        return false;
    }
    return true;
}

async function startFile(req, res) {
    if (!(await assertStreamingEnabled(res))) return;
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
        const status = e.code === 'MODE_BUSY' ? 409 : 500;
        res.status(status).json({ status: 'error', message: e.message || 'start failed', code: e.code });
    }
}

async function startYoutube(req, res) {
    if (!(await assertStreamingEnabled(res))) return;
    const youtubeUrl = req.query.url || req.body?.url;
    try {
        await stream.startYoutubeUrl(youtubeUrl);
        res.json({ status: 'success', youtubeUrl });
    } catch (e) {
        console.error('Error starting YouTube stream:', e);
        const status = e.code === 'MODE_BUSY' ? 409 : 500;
        res.status(status).json({ status: 'error', message: e.message || 'start failed', code: e.code });
    }
}

function status(_req, res) {
    Promise.resolve(getStreamEnabled())
        .then((enabled) => {
            const s = stream.getStatus();
            res.json({ status: 'success', data: { ...s, streamEnabled: enabled } });
        })
        .catch(() => {
            const s = stream.getStatus();
            res.json({ status: 'success', data: { ...s, streamEnabled: false } });
        });
}

async function stopMic(_req, res) {
    try {
        await stream.stopMicStream();
        res.json({ status: 'success', message: 'Mic stream stopped' });
    } catch (e) {
        console.error('Error stopping mic stream:', e);
        res.status(500).json({ status: 'error', message: e.message });
    }
}

async function playPlaylist(req, res) {
    try {
        if (!(await assertStreamingEnabled(res))) return;
        const loop = req.query.loop === 'true' || req.body?.loop === true;
        const result = await stream.playPlaylist({ loop });
        return res.json({ status: 'success', message: result.message });
    } catch (e) {
        console.error('Error playPlaylist:', e);
        const status = e.code === 'MODE_BUSY' ? 409 : 500;
        return res.status(status).json({ status: 'error', message: e.message || 'play playlist failed', code: e.code });
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

async function nextTrack(_req, res) {
    try {
        if (!(await assertStreamingEnabled(res))) return;
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
        if (!(await assertStreamingEnabled(res))) return;
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
        if (!(await assertStreamingEnabled(res))) return;
        stream.resume();
        return res.json({ status: 'success', message: 'เล่นต่อ' });
    } catch (e) {
        console.error('Error resumePlaylist:', e);
        return res.status(500).json({ status: 'error', message: e.message || 'resume failed' });
    }
}

module.exports = { 
    status,
    stopMic,
    startFile,
    startYoutube,
    playPlaylist,
    stopAll,
    nextTrack,
    prevTrack,
    pause,
    resume
};
