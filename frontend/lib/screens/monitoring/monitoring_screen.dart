import 'package:flutter/material.dart';
// ใช้ relative path สำหรับ model และ service
import 'models/device_data.dart';
import 'services/device_data_service.dart';
// เพิ่มการใช้ Exception ที่เรากำหนดเอง
import 'package:smart_control/core/network/api_exceptions.dart'; 

class MonitoringScreen extends StatefulWidget { 
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  late Future<List<DeviceData>> _futureDeviceData;
  final DeviceDataService _service = DeviceDataService();

  @override
  void initState() {
    super.initState();
    _futureDeviceData = _service.fetchDeviceData();
  }
  
  Future<void> _refreshData() async {
    setState(() {
      _futureDeviceData = _service.fetchDeviceData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ข้อมูลอุปกรณ์ IoT (Monitoring)'), 
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: FutureBuilder<List<DeviceData>>(
        future: _futureDeviceData,
        builder: (context, snapshot) {
          // 1. สถานะ Loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } 
          
          // 2. สถานะ Error
          else if (snapshot.hasError) {
            // ดึงข้อความ Error ที่ชัดเจนกว่าเดิม (เพราะเราใช้ ApiException)
            String errorMessage = 'เกิดข้อผิดพลาดในการโหลดข้อมูล';
            if (snapshot.error is ApiException) {
              errorMessage = (snapshot.error as ApiException).message;
            } else {
              errorMessage = snapshot.error.toString();
            }

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 60),
                    const SizedBox(height: 10),
                    Text(
                      'ข้อผิดพลาด: $errorMessage', 
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _refreshData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('ลองใหม่'),
                    )
                  ],
                ),
              ),
            );
          } 
          
          // 3. สถานะ Data Loaded
          else if (snapshot.hasData) {
            final List<DeviceData> deviceList = snapshot.data!;
            
            if (deviceList.isEmpty) {
              return const Center(child: Text('ไม่พบข้อมูลอุปกรณ์ใดๆ ในฐานข้อมูล'));
            }

            return RefreshIndicator(
              onRefresh: _refreshData,
              child: ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: deviceList.length,
                itemBuilder: (context, index) {
                  final device = deviceList[index];
                  
                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            device.name ?? 'ไม่ระบุชื่ออุปกรณ์', 
                            style: const TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.bold, 
                              color: Colors.indigo
                            ),
                          ),
                          const Divider(),
                          _buildDetailRow('สถานะ:', device.status ?? 'N/A'),
                          _buildDetailRow('กำลังไฟ (W):', device.acW?.toStringAsFixed(2) ?? 'N/A'),
                          _buildDetailRow('แรงดันไฟ (V):', device.acV?.toStringAsFixed(2) ?? 'N/A'),
                          _buildDetailRow('กระแสไฟ (A):', device.acA?.toStringAsFixed(2) ?? 'N/A'),
                          _buildDetailRow('แบตเตอรี่:', '${device.battery ?? 'N/A'}%'),
                          _buildDetailRow('เวลาล่าสุด:', device.timestamp?.toLocal().toString() ?? 'N/A'),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          }
          
          return const Center(child: Text('เริ่มต้นการโหลดข้อมูล...'));
        },
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}