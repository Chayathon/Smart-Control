const router = require("express").Router();
const ctrl = require("../controllers/song.controller");
const { authenticateToken } = require("../middleware/auth");

router.get('/', authenticateToken, ctrl.getSongList);
router.post('/uploadSongFile', authenticateToken, ctrl.uploadSongFile);
router.post('/uploadSongYT', authenticateToken, ctrl.uploadSongYT);
router.delete("/remove/:songId", authenticateToken, ctrl.deleteSong);

module.exports = router;