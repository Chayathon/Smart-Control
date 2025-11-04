import 'dart:convert';
import 'package:http/http.dart' as http;
import '../screens/monitoring/models/device_data_model.dart';

class DeviceDataService {
  final String baseUrl = 'http://localhost:8080';

  Future<List<DeviceData>> fetchDeviceData() async {
    final url = Uri.parse('$baseUrl/deviceData');

    final response = await http.get(url, headers: {
      'Content-Type': 'application/json',
    });

    if (response.statusCode == 200) {
      final Map<String, dynamic> body = jsonDecode(response.body);
      if (body['status'] == 'success' && body['data'] != null) {
        final List<dynamic> list = body['data'];
        return list.map((item) => DeviceData.fromJson(item)).toList();
      } else {
        throw Exception('รูปแบบข้อมูลไม่ถูกต้อง');
      }
    } else {
      throw Exception('ไม่สามารถดึงข้อมูลได้: ${response.statusCode}');
    }
  }
}
