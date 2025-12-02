const router = require('express').Router();
const ctrl = require('../controllers/settings.controller');
const { authenticateToken } = require('../middleware/auth');
const lineNotifyService = require('../services/line-notify.service');

router.get('/', authenticateToken, ctrl.getAllSettings);

router.get('/:key', authenticateToken, ctrl.getSetting);

router.put('/:key', authenticateToken, ctrl.updateSetting);

router.post('/bulk', authenticateToken, ctrl.updateMultipleSettings);

router.post('/reset', authenticateToken, ctrl.resetSettings);

// Stream configuration endpoints
router.get('/stream-config', authenticateToken, ctrl.getStreamConfig);
router.put('/stream-config', authenticateToken, ctrl.updateStreamConfig);

// LINE notification test endpoint
router.post('/line-notify/test', authenticateToken, async (req, res) => {
    try {
        const result = await lineNotifyService.testNotification();
        res.json(result);
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
});

module.exports = router;
