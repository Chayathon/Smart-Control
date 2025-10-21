const stream = require('../services/stream.service');
const multer = require('multer')
const { isHttpUrl } = require('../utils/parse');
const Song = require("../models/Song")
const path = require('path');
const fs = require('fs');

const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        const uploadDir = path.join(__dirname, '../uploads');
        if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir);
        cb(null, uploadDir);
    },
    filename: function (req, file, cb) {
        const safeName = req.body.filename
            ? req.body.filename.replace(/[^a-zA-Z0-9ก-๙\-_ ]/g, '')
            : `song-${Date.now()}`;
        const uniqueSuffix = Math.random().toString(36).slice(2);
        cb(null, `${safeName}-${uniqueSuffix}.mp3`);
    }
});

const fileFilter = (req, file, cb) => {
    if (file.mimetype === 'audio/mpeg') {
        cb(null, true);
    } else {
        cb(new Error('Only MP3 files are allowed!'), false);
    }
};

const upload = multer({ storage, fileFilter });

async function startFile(req, res) {
    const filePath = req.query.path || req.body?.path;
    try {
        await stream.startLocalFile(filePath);
        res.json({ status: 'success', filePath });
    } catch (e) {
        console.error('Error starting stream:', e);
        res.status(500).json({ status: 'error', message: e.message || 'start failed' });
    }
}

function status(_req, res) {
    res.json({ status: 'success', data: stream.getStatus() });
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
        const loop = req.query.loop === 'true' || req.body?.loop === true;
        const result = await stream.playPlaylist({ loop });
        return res.json({ status: 'success', message: result.message });
    } catch (e) {
        console.error('Error playPlaylist:', e);
        return res.status(500).json({ status: 'error', message: e.message || 'play playlist failed' });
    }
}

async function stopPlaylist(_req, res) {
    try {
        const result = await stream.stopPlaylist();
        return res.json({ status: 'success', message: result.message });
    } catch (e) {
        console.error('Error stopPlaylist:', e);
        return res.status(500).json({ status: 'error', message: e.message || 'stop playlist failed' });
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

async function pausePlaylist(_req, res) {
    try {
        stream.pause();
        return res.json({ status: 'success', message: 'หยุดชั่วคราว' });
    } catch (e) {
        console.error('Error pausePlaylist:', e);
        return res.status(500).json({ status: 'error', message: e.message || 'pause failed' });
    }
}

async function resumePlaylist(_req, res) {
    try {
        stream.resume();
        return res.json({ status: 'success', message: 'เล่นต่อ' });
    } catch (e) {
        console.error('Error resumePlaylist:', e);
        return res.status(500).json({ status: 'error', message: e.message || 'resume failed' });
    }
}

module.exports = { 
    status,
    startFile,
    stopMic,
    playPlaylist,
    stopPlaylist,
    nextTrack,
    prevTrack,
    pausePlaylist,
    resumePlaylist
};
