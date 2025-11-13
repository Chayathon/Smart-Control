import 'package:smart_control/core/network/api_service.dart';

class ScheduleService {
  static Future<List<dynamic>> getSchedules() async {
    final api = await ApiService.private();
    final result = await api.get("/schedule");

    if (result['ok'] == true && result['data'] != null) {
      return result['data'] as List<dynamic>;
    }
    return [];
  }

  static Future<Map<String, dynamic>?> getScheduleById(
    String scheduleId,
  ) async {
    final api = await ApiService.private();
    final result = await api.get('/schedule/$scheduleId');

    if (result['ok'] == true && result['data'] != null) {
      return result['data'] as Map<String, dynamic>;
    }
    return null;
  }

  static Future<List<dynamic>> getSongs() async {
    final api = await ApiService.private();
    final result = await api.get("/song");

    if (result['status'] == 'success' && result['data'] != null) {
      return result['data'] as List<dynamic>;
    }
    return [];
  }

  static Future<bool> createSchedule(Map<String, dynamic> scheduleData) async {
    final api = await ApiService.private();
    final result = await api.post("/schedule/save", data: scheduleData);
    return result['ok'] == true;
  }

  static Future<bool> updateSchedule(
    String scheduleId,
    Map<String, dynamic> scheduleData,
  ) async {
    final api = await ApiService.private();
    final result = await api.put(
      "/schedule/update/$scheduleId",
      data: scheduleData,
    );
    return result['ok'] == true;
  }

  static Future<bool> changeStatus(String scheduleId, bool isActive) async {
    final api = await ApiService.private();
    final result = await api.patch(
      "/schedule/change-status/$scheduleId",
      data: {'is_active': isActive},
    );
    return result['ok'] == true;
  }

  static Future<bool> deleteSchedule(String scheduleId) async {
    final api = await ApiService.private();
    final result = await api.delete("/schedule/delete/$scheduleId");
    return result['ok'] == true;
  }
}
