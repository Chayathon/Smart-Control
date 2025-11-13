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

async function getSongById(req, res) {
    try {
        const { id } = req.params;

        if (!id) {
            return res.status(400).json({
                status: 'error',
                message: 'Song ID is required'
            });
        }

        const data = await song.getSongById(id);

        return res.json({
            status: 'success',
            data
        });
    } catch (error) {
        console.error('Error getting song by ID:', error);
        res.status(500).json({
            status: 'error',
            message: error.message
        })
    }
}

async function getSongExceptInPlaylist(req, res) {
    try {
        const list = await song.getSongExceptInPlaylist();
        res.json({ status: 'success', data: list });
    } catch (e) {
        res.status(500).json({ status: 'error', message: e.message || 'get songs failed' });
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

async function updateSongName(req, res) {
    try {
        const { id } = req.params;
        const { newName } = req.body;

        if (!id || !newName) {
            return res.status(400).json({
                status: 'error',
                message: 'Song ID and new name are required'
            });
        }

        const updatedSong = await song.updateSongName(id, newName);

        return res.json({
            status: 'success',
            data: updatedSong
        });
    } catch (error) {
        console.error('Error updating song name:', error);
        const status = error.status || error.statusCode || 500;

        return res.status(status).json({
            status: 'error',
            message: error.message || 'Internal server error'
        });
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
        console.error('Error deleting song:', e);
        const status = e.status || e.statusCode || 500;

        return res.status(status).json({
            status: 'error',
            message: e.message || 'Internal server error'
        });
    }
}

module.exports = { getSongList, getSongById, getSongExceptInPlaylist, uploadSongFile, uploadSongYT, updateSongName, deleteSong }