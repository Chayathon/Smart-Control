const router = require('express').Router();
const ctrl = require('../controllers/stream.controller');
const { authenticateToken } = require('../middleware/auth');

router.get('/status', ctrl.status);

// Mic control endpoint
router.post('/mic/stop', authenticateToken, ctrl.stopMic);

router.get('/start-playlist', authenticateToken, ctrl.playPlaylist);
router.get('/stop', authenticateToken, ctrl.stopAll);
router.get('/next-track', authenticateToken, ctrl.nextTrack);
router.get('/prev-track', authenticateToken, ctrl.prevTrack);
router.get('/pause', authenticateToken, ctrl.pause);
router.get('/resume', authenticateToken, ctrl.resume);

router.get('/start-file', ctrl.startFile);
router.get('/start-youtube', ctrl.startYoutube);

module.exports = router;
