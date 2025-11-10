const Schedule = require('../models/Schedule');

async function getSchedules() {
    try {
        const schedules = await Schedule.find().populate('id_song');
        return schedules;
    } catch (err) {
        console.error('Error in getSchedules:', err);
        throw err;
    }
}

async function saveSchedule(schedule) {
    try {
        const newSchedule = new Schedule(schedule);

        const savedSchedule = await newSchedule.save();
        return {
            success: true,
            message: 'บันทึกเพลงตั้งเวลาเรียบร้อย',
            data: savedSchedule,
        }
    } catch (err) {
        console.error('Error in saveSchedule:', err);
        throw err;
    }
}

async function changeScheduleStatus(id, isActive) {
    try {
        const updatedSchedule = await Schedule.findByIdAndUpdate(
            id,
            { is_active: isActive },
            { new: true }
        );

        if (!updatedSchedule) {
            throw new Error('Schedule not found');
        }

        return {
            success: true,
            message: 'เปลี่ยนสถานะเพลงตั้งเวลาเรียบร้อย',
            data: updatedSchedule,
        };
    } catch (err) {
        console.error('Error in changeScheduleStatus:', err);
        throw err;
    }
}

module.exports = { getSchedules, saveSchedule, changeScheduleStatus };