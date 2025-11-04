import 'package:flutter/material.dart';
import '../../services/device_data_service.dart';
import 'models/device_data_model.dart';

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({Key? key}) : super(key: key);

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  final DeviceDataService _deviceDataService = DeviceDataService();
  late Future<List<DeviceData>> _futureDeviceData;

  @override
  void initState() {
    super.initState();
    _futureDeviceData = _deviceDataService.fetchDeviceData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFe5e5e5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14213d),
        title: const Text(
          'Monitoring Device Data',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<List<DeviceData>>(
        future: _futureDeviceData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('ไม่พบข้อมูล'));
          }

          final dataList = snapshot.data!;
          return ListView.builder(
            itemCount: dataList.length,
            itemBuilder: (context, index) {
              final data = dataList[index];
              return Card(
                margin: const EdgeInsets.all(10),
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Icon(
                    Icons.sensors,
                    color: data.status == 'on'
                        ? Colors.green
                        : Colors.red,
                  ),
                  title: Text(
                    '${data.name} (${data.status})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'acW: ${data.acW?.toStringAsFixed(2)} | '
                    'acV: ${data.acV?.toStringAsFixed(2)} | '
                    'battery: ${data.battery ?? 0}%',
                  ),
                  trailing: Text(
                    data.timestamp.toLocal().toString().split('.')[0],
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
