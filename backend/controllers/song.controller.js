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
        res.json({ ok: true, data: list });
    } catch (err) {
        console.error('Error getting song list:', err);
        res.status(500).json({ ok: false, message: err.message || 'get song list failed' });
    }
}

async function getSongById(req, res) {
    try {
        const { id } = req.params;

        if (!id) {
            return res.status(400).json({
                ok: false,
                message: 'Song ID is required'
            });
        }

        const data = await song.getSongById(id);

        return res.json({
            ok: true,
            data
        });
    } catch (err) {
        console.error('Error getting song by ID:', err);
        res.status(500).json({
            ok: false,
            message: err.message
        })
    }
}

async function getSongExceptInPlaylist(req, res) {
    try {
        const list = await song.getSongExceptInPlaylist();
        res.json({ ok: true, data: list });
    } catch (err) {
        res.status(500).json({ ok: false, message: err.message || 'get songs failed' });
    }
}

async function uploadSongFile(req, res) {
    try {
        const { filename } = req.body;
        const file = req.file;

        if (!file) {
            return res.status(400).json({
                ok: false,
                message: 'ไม่พบไฟล์ที่อัปโหลด'
            });
        }

        const nameExists = await song.checkNameExists(filename);

        if (nameExists) {
            return res.status(409).json({
                ok: false,
                message: 'ชื่อเพลงนี้มีอยู่ในระบบแล้ว'
            });
        }

        const created = await song.uploadSongFile(file, filename);

        return res.json({
            ok: true,
            file: created.fileName,
            name: created.name,
            url: created.url
        });
    } catch (err) {
        console.error('uploadSongFile error:', err);
        const status = err.status || err.statusCode || 500;

        return res.status(status).json({
            ok: false,
            message: err.message || 'Internal server error'
        });
    }
}

async function uploadSongYT(req, res) {
    try {
        const { url, filename } = req.body || {};
        if (!url || !isHttpUrl(url)) {
            return res.status(400).json({ ok: false, message: 'ต้องระบุ URL ที่ถูกต้อง' });
        }

        const nameExists = await song.checkNameExists(filename);

        if (nameExists) {
            return res.status(409).json({
                ok: false,
                message: 'ชื่อเพลงนี้มีอยู่ในระบบแล้ว'
            });
        }

        const result = await song.uploadSongYT(url, filename);

        return res.json({
            ok: true,
            data: {
                id: result.id,
                name: result.name,
                file: result.fileName,
                url: result.url
            }
        });
    } catch (err) {
        console.error('Error uploading song:', err);
        const status = err.status || err.statusCode || 500;

        return res.status(status).json({
            ok: false,
            message: err.message || 'Internal server error'
        });
    }
}

async function updateSongName(req, res) {
    try {
        const { id } = req.params;
        const { newName } = req.body;

        if (!id || !newName) {
            return res.status(400).json({
                ok: false,
                message: 'Song ID and new name are required'
            });
        }

        const nameExists = await song.checkNameExists(newName, id);

        if (nameExists) {
            return res.status(409).json({
                ok: false,
                message: 'ชื่อเพลงนี้มีอยู่ในระบบแล้ว'
            });
        }

        const updatedSong = await song.updateSongName(id, newName);

        return res.json({
            ok: true,
            data: updatedSong
        });
    } catch (err) {
        console.error('Error updating song name:', err);
        const status = err.status || err.statusCode || 500;

        return res.status(status).json({
            ok: false,
            message: err.message || 'Internal server error'
        });
    }
}

async function deleteSong(req, res) {
    try {
        const { songId } = req.params;
        console.log("id:", songId);

        if (!songId) {
            return res.status(400).json({ ok: false, message: 'songId is required' });
        }

        const result = await song.deleteSong(songId);

        return res.json({ ok: true, ...result });
    } catch (err) {
        console.error('Error deleting song:', err);
        const status = err.status || err.statusCode || 500;

        return res.status(status).json({
            ok: false,
            message: err.message || 'Internal server error'
        });
    }
}

module.exports = { getSongList, getSongById, getSongExceptInPlaylist, uploadSongFile, uploadSongYT, updateSongName, deleteSong }