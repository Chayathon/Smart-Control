const router = require("express").Router();

const ctrl = require("../controllers/song.controller");
const { upload } = require('../services/song.service');
const { authenticateToken } = require("../middleware/auth");

router.get('/', authenticateToken, ctrl.getSongList);
router.get('/:id', authenticateToken, ctrl.getSongById);
router.get('/except-in-playlist', authenticateToken, ctrl.getSongExceptInPlaylist);
router.post('/uploadSongFile', authenticateToken, upload.single('song'), ctrl.uploadSongFile);
router.post('/uploadSongYT', authenticateToken, ctrl.uploadSongYT);
router.patch('/update/:id', authenticateToken, ctrl.updateSongName);
router.delete("/remove/:songId", authenticateToken, ctrl.deleteSong);

module.exports = router;