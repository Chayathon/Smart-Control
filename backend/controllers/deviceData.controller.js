// D:\mass_smart_city\Smart-Control\backend\controllers\deviceData.controller.js
const deviceDataService = require('../services/deviceData.service'); // ดึง Service มาใช้งาน

// Controller สำหรับดึงรายการข้อมูล DeviceData (ล่าสุด 50 รายการ)
async function getDeviceDataList(req, res) {
    try {
        const list = await deviceDataService.getDeviceDataList();
        res.json({ status: 'success', data: list });
    } catch (error) {
        console.error('Error getting device data list:', error);
        res.status(500).json({ 
            status: 'error', 
            message: error.message || 'get device data list failed' 
        });
    }
}

// Controller สำหรับดึงข้อมูล DeviceData ล่าสุด 1 รายการ
async function getLatestDeviceData(req, res) {
    try {
        const data = await deviceDataService.getLatestDeviceData();
        if (!data) {
             return res.status(404).json({
                status: 'error',
                message: 'Device data not found'
            });
        }
        res.json({ status: 'success', data: data });
    } catch (error) {
        console.error('Error getting latest device data:', error);
        res.status(500).json({ 
            status: 'error', 
            message: error.message || 'get latest device data failed' 
        });
    }
}

module.exports = { getDeviceDataList, getLatestDeviceData }