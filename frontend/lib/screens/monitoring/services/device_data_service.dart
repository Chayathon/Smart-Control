// *** เปลี่ยนการ Import: ลบ http และ dart:io ***

// ใช้ package import สำหรับ core files
import 'package:smart_control/core/network/api_service.dart';
import 'package:smart_control/core/network/api_exceptions.dart'; 

// ใช้ relative path สำหรับ model
import '../models/device_data.dart'; 

class DeviceDataService {
  
  // Endpoint ถูกต้องแล้ว
  static const String _deviceDataEndpoint = '/deviceData'; 

  // สร้าง ApiService แบบ public (ไม่ต้องการ Token) แบบ Lazy
  final Future<ApiService> _apiServiceFuture = ApiService.public(); 

  Future<List<DeviceData>> fetchDeviceData() async {
    try {
      final apiService = await _apiServiceFuture; 

      final List<DeviceData> data = await apiService.get<List<DeviceData>>(
        _deviceDataEndpoint,
        // decoder จะรับค่าที่เป็น List ของ JSON Objects มาจาก Dio
        decoder: (jsonArray) {
          if (jsonArray is List) {
             // แปลง List ของ JSON Objects ให้เป็น List<DeviceData>
             return jsonArray.map((e) => DeviceData.fromJson(e)).toList();
          }
          throw Exception('Invalid data format received from API: Not a List.');
        },
      );
      
      return data;
      
    } on ApiException catch (e) {
      // จับ Error ที่ถูกแปลงมาจาก DioException ใน ApiService
      print('Failed to load device data: ${e.message}');
      throw e; // โยนต่อให้ FutureBuilder จัดการ
    } catch (e) {
      // ดักจับ Errors อื่นๆ 
      print('An unknown error occurred: $e');
      throw Exception('An unknown error occurred: $e');
    }
  }
}