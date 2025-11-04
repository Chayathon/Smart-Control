// dart:convert / http not needed because ApiService (Dio) returns decoded JSON
import 'package:smart_control/core/network/api_service.dart';
import '../screens/monitoring/models/device_data_model.dart';

class DeviceDataService {
  // final String baseUrl = 'http://localhost:8080';

  Future<List<DeviceData>> fetchDeviceData() async {
    // final url = Uri.parse('$baseUrl/deviceData');

    // final response = await http.get(url, headers: {
    //   'Content-Type': 'application/json',
    // });

    final api = await ApiService.public();

    final dynamic responseBody = await api.get('/deviceData');

    if (responseBody is Map<String, dynamic>) {
      if (responseBody['status'] == 'success' && responseBody['data'] != null) {
        final List<dynamic> list = responseBody['data'] as List<dynamic>;
        return list
            .map((item) => DeviceData.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    }

    throw Exception('รูปแบบข้อมูลไม่ถูกต้อง');
  }
}
