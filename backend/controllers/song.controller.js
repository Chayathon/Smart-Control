const song = require('../services/song.service');

function isHttpUrl(u) {
    try {
        const x = new URL(u);
        return x.protocol === 'http:' || x.protocol === 'https:';
    } catch {
        return false;
    }
}

async function getSongList(req, res) {
    try {
        const list = await song.getSongList();
        res.json({ status: 'success', data: list });
    } catch (error) {
        console.error('Error getting song list:', error);
        res.status(500).json({ status: 'error', message: error.message || 'get song list failed' });
    }
}

async function uploadSongFile(req, res) {
    try {
        const { filename } = req.body;
        const file = req.file;

        if (!file) {
            return res.status(400).json({ status: 'error', message: 'No file uploaded' });
        }

        const created = await song.uploadSongFile(file, filename);

        return res.json({
            status: 'success',
            message: 'Song uploaded successfully',
            file: created.fileName,
            name: created.name,
            url: created.url
        });
    } catch (err) {
        console.error('uploadSongFile error:', err);
        return res.status(500).json({ status: 'error', message: err.message });
    }
}

async function uploadSongYT(req, res) {
    try {
        const { url, filename } = req.body || {};
        if (!url || !isHttpUrl(url)) {
            return res.status(400).json({ status: 'error', message: 'ต้องระบุ URL ที่ถูกต้อง' });
        }

        const result = await song.uploadSongYT(url, filename);

        return res.json({
            status: 'success',
            message: 'Song uploaded successfully',
            data: {
                id: result.id,
                name: result.name,
                file: result.fileName,
                url: result.url
            }
        });
    } catch (e) {
        console.error('Error uploading song:', e);
        return res.status(500).json({ status: 'error', message: e.message || 'upload failed' });
    }
}

async function deleteSong(req, res) {
    try {
        const { songId } = req.params;
        console.log("id:", songId);
        if (!songId) {
            return res.status(400).json({ status: 'error', message: 'songId is required' });
        }

        const result = await song.deleteSong(songId);

        return res.json({ status: 'success', ...result });
    } catch (e) {
        console.error('Error deleteSong:', e);
        return res.status(500).json({ status: 'error', message: e.message || 'delete song failed' });
    }
}

module.exports = { getSongList, uploadSongFile, uploadSongYT, deleteSong }