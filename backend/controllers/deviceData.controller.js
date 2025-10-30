// D:\mass_smart_city\Smart-Control\backend\controllers\deviceData.controller.js

const { listDeviceData } = require('../services/deviceData.service');
const bus = require('../services/bus'); // **<<< เพิ่มบรรทัดนี้: นำเข้า Event Bus**

/**
 * ฟังก์ชันสำหรับจัดการ Request GET เพื่อดึงข้อมูล DeviceData
 */
async function getDeviceDataList(req, res) {
    try {
        const data = await listDeviceData();
        
        // --- 📢 ส่วนปล่อย Event Bus ---
        // ปล่อย Event 'status' เพื่อให้ WebSocket (wsServer.js) ส่งข้อมูล
        bus.emit('status', { 
            type: 'deviceData_list', // กำหนดประเภทข้อมูลเพื่อแยกแยะในฝั่ง Client
            payload: data            // ข้อมูล DeviceData ที่ดึงมา
        });
        console.log("[Bus] Emitted 'status' event with deviceData.");
        // -----------------------------
        
        res.json(data);
    } catch (e) {
        res.status(500).json({ ok: false, error: e.message });
    }
}

module.exports = { getDeviceDataList };