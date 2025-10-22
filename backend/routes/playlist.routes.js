const router = require("express").Router();
const ctrl = require("../controllers/playlist.controller");
const { authenticateToken } = require("../middleware/auth");
const bus = require('../services/bus')

router.post("/save", authenticateToken, ctrl.savePlaylist);
router.get("/", authenticateToken, ctrl.getPlaylist);
router.get('/status', authenticateToken, ctrl.getPlaylistStatus);

router.get('/stream/status-sse', (req, res) => {

    res.writeHead(200, {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache, no-transform',
        'Connection': 'keep-alive',
        'X-Accel-Buffering': 'no',
    });


    const onStatus = (payload) => {
        res.write(`event: status\n`);
        res.write(`data: ${JSON.stringify(payload)}\n\n`);
    };

    bus.on('status', onStatus);

    const ping = setInterval(() => {
        res.write(`: ping\n\n`);
    }, 15000);

    req.on('close', () => {
        clearInterval(ping);
        bus.off('status', onStatus);
        try { res.end(); } catch { }
    });
});

module.exports = router;
