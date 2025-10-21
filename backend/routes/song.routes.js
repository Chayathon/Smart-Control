const router = require("express").Router();

const ctrl = require("../controllers/song.controller");
const { upload } = require('../services/song.service');
const { authenticateToken } = require("../middleware/auth");

router.get('/', authenticateToken, ctrl.getSongList);
router.post('/uploadSongFile', authenticateToken, upload.single('song'), ctrl.uploadSongFile);
router.post('/uploadSongYT', authenticateToken, ctrl.uploadSongYT);
router.delete("/remove/:songId", authenticateToken, ctrl.deleteSong);

module.exports = router;