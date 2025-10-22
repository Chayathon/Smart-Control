const router = require('express').Router();
const ctrl = require('../controllers/stream.controller');
const { authenticateToken } = require('../middleware/auth');

router.get('/status', ctrl.status);

// Mic control endpoint
router.post('/mic/stop', authenticateToken, ctrl.stopMic);

router.get('/start-playlist', authenticateToken, ctrl.playPlaylist);
router.get('/stop-playlist', authenticateToken, ctrl.stopPlaylist);
router.get('/next-track', authenticateToken, ctrl.nextTrack);
router.get('/prev-track', authenticateToken, ctrl.prevTrack);
router.get('/pause-playlist', authenticateToken, ctrl.pausePlaylist);
router.get('/resume-playlist', authenticateToken, ctrl.resumePlaylist);

router.get('/start-file', ctrl.startFile);
router.get('/start-youtube', ctrl.startYoutube);

module.exports = router;
