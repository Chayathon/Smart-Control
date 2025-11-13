const schedule = require('../services/schedule.service');
const schedulerService = require('../services/scheduler.service');

async function getScheduleStatus(_req, res) {
    try {
        const status = schedulerService.getScheduleStatus();
        res.json({ ok: true, data: status });
    } catch (err) {
        console.error('Error in getScheduleStatus controller:', err);
        res.status(500).json({
            success: false,
            error: 'Internal server error'
        });
    }
}

async function stopSchedulePlayback(_req, res) {
    try {
        const result = await schedulerService.stopSchedulePlayback();
        res.json({ ok: true, result });
    } catch (err) {
        console.error('Error in stopSchedulePlayback controller:', err);
        res.status(500).json({
            success: false,
            error: 'Internal server error'
        });
    }
}

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

async function getScheduleById(req, res) {
    try {
        const { id } = req.params;

        if (!id) {
            return res.status(400).json({
                success: false,
                error: 'Missing schedule ID',
            });
        }

        const result = await schedule.getScheduleById(id);
        res.json({ ok: true, data: result });
    } catch (err) {
        console.error('Error in getScheduleById controller:', err);
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

async function updateSchedule(req, res) {
    try {
        const { id } = req.params;
        const scheduleData = req.body;

        if (!id || !scheduleData) {
            return res.status(400).json({
                success: false,
                error: 'Missing parameters',
            });
        }

        const result = await schedule.updateSchedule(id, scheduleData);
        res.json({ ok: true, result });
    } catch (err) {
        console.error('Error in updateSchedule controller:', err);
        res.status(500).json({
            success: false,
            error: 'Internal server error',
        });
    }
}

async function changeScheduleStatus(req, res) {
    try {
        const { id } = req.params;
        const { is_active } = req.body;

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

async function deleteSchedule(req, res) {
    try {
        const { id } = req.params;

        if(!id) {
            return res.status(400).json({
                success: false,
                error: 'Missing schedule ID',
            });
        }

        const result = await schedule.deleteSchedule(id);
        res.json({ ok: true, result });
    } catch (err) {
        console.error('Error in deleteSchedule controller:', err);
        res.status(500).json({
            success: false,
            error: 'Internal server error',
        });
    }
}

module.exports = { 
    getSchedules, 
    getScheduleById, 
    saveSchedule, 
    updateSchedule, 
    changeScheduleStatus, 
    deleteSchedule,
    getScheduleStatus,
    stopSchedulePlayback
};