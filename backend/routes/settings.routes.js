const router = require('express').Router();
const ctrl = require('../controllers/settings.controller');
const { authenticateToken } = require('../middleware/auth');

router.get('/', authenticateToken, ctrl.getAllSettings);

router.get('/:key', authenticateToken, ctrl.getSetting);

router.put('/:key', authenticateToken, ctrl.updateSetting);

router.post('/bulk', authenticateToken, ctrl.updateMultipleSettings);

router.post('/reset', authenticateToken, ctrl.resetSettings);

// Stream configuration endpoints
router.get('/stream-config', authenticateToken, ctrl.getStreamConfig);
router.put('/stream-config', authenticateToken, ctrl.updateStreamConfig);

module.exports = router;
