const { setupPlaylist, getPlaylist } = require('../services/playlist.service');
const stream = require('../services/stream.service')

async function postSetupPlaylist(req, res) {
    try {
        const { playlist } = req.body;
        const result = await setupPlaylist(playlist);
        res.json({ ok: true, result });
    } catch (e) {
        res.status(400).json({ ok: false, error: e.message });
    }
}

async function getPlaylistSong(req, res) {
    try {
        const list = await getPlaylist();
        res.json({ ok: true, list });
    } catch (e) {
        res.status(400).json({ ok: false, error: e.message });
    }
}

async function getPlaylistStatus(_req, res) {
    try {
        const status = stream.getStatus();
        // avoid nesting large objects; pick only essentials
        const payload = {
            isPlaying: status.isPlaying,
            isPaused: status.isPaused,
            playlistMode: status.playlistMode,
            currentIndex: status.currentIndex,
            totalSongs: status.totalSongs,
            loop: status.loop,
            currentSong: status.currentSong || null,
        };
        return res.json({ status: 'success', ...payload });
    } catch (e) {
        console.error('Error getPlaylistStatus:', e);
        return res.status(500).json({ status: 'error', message: e.message || 'get status failed' });
    }
}

module.exports = {
    postSetupPlaylist,
    getPlaylistSong,
    getPlaylistStatus,
};
