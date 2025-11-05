const express = require('express');
const router = express.Router();
const { postSeed, getList, deleteAll, postAppend, putStreamEnabled, getStreamEnabledCtrl } = require('../controllers/device.controller');
const { authenticateToken } = require('../middleware/auth');

router.get('/', authenticateToken, getList);
router.post('/seed', postSeed);
router.post('/append', postAppend);
router.delete('/', deleteAll);

router.get('/stream-enabled', authenticateToken, getStreamEnabledCtrl);
router.put('/stream-enabled', authenticateToken, putStreamEnabled);

module.exports = router;
