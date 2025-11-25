const router = require('express').Router();
const ctrl = require('../controllers/stream.controller');
const { authenticateToken } = require('../middleware/auth');

router.get('/status', ctrl.status);
router.get('/audio', ctrl.streamAudio);
router.post('/enable', authenticateToken, ctrl.enableStream);
router.post('/disable', authenticateToken, ctrl.disableStream);

router.get('/start-file', ctrl.startFile);
router.get('/start-youtube', ctrl.startYoutube);
router.get('/start-playlist', authenticateToken, ctrl.startPlaylist);
router.get('/pause', authenticateToken, ctrl.pause);
router.get('/resume', authenticateToken, ctrl.resume);
router.get('/next-track', authenticateToken, ctrl.nextTrack);
router.get('/prev-track', authenticateToken, ctrl.prevTrack);
router.get('/stop', authenticateToken, ctrl.stopAll);

module.exports = router;
