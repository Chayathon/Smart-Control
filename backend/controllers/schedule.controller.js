const schedule = require('../services/schedule.service');

async function getSchedules(_req, res) {
    try {
        const result = await schedule.getSchedules();
        res.json({ ok: true, data: result });
    } catch (err) {
        console.error('Error in getSchedules controller:', err);
        res.status(500).json({
            success: false,
            error: 'Internal server error'
        });
    }
}

async function saveSchedule(req, res) {
    try {
        const scheduleData = req.body;

        if (!scheduleData) {
            return res.status(400).json({
                success: false,
                error: 'Missing schedule data',
            });
        }

        const result = await schedule.saveSchedule(scheduleData);
        res.json({ ok: true, result });
    } catch (err) {
        console.error('Error in saveSchedule controller:', err);
        res.status(500).json({
            success: false,
            error: 'Internal server error',
        });
    }
}

async function changeScheduleStatus(req, res) {
    try {
        const { id, is_active } = req.body;

        if (!id || typeof is_active !== 'boolean') {
            return res.status(400).json({
                success: false,
                error: 'Missing or invalid parameters',
            });
        }

        const result = await schedule.changeScheduleStatus(id, is_active);
        res.json({ ok: true, result });
    } catch (err) {
        console.error('Error in changeScheduleStatus controller:', err);
        res.status(500).json({
            success: false,
            error: 'Internal server error',
        });
    }
}

module.exports = { getSchedules, saveSchedule, changeScheduleStatus };