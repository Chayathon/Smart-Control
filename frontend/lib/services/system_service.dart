import 'package:smart_control/core/network/api_service.dart';

class SystemService {
  /// โหลดการตั้งค่าระบบทั้งหมด
  static Future<Map<String, dynamic>> getSettings() async {
    final api = await ApiService.private();
    final response = await api.get('/settings');

    if (response['ok'] == true) {
      return response['data'];
    }
    throw Exception('Failed to load settings');
  }

  /// บันทึกการตั้งค่าระบบแบบ bulk
  static Future<bool> saveSettings({
    required int sampleRate,
    required bool loopPlaylist,
    String? channelSecret,
    String? channelPublic,
    String? lineChannelAccessToken,
    String? lineChannelSecret,
    String? lineUserId,
    bool? lineNotifyEnabled,
    String? lineMessageStart,
    String? lineMessageEnd,
    String? appBaseUrl,
  }) async {
    try {
      final api = await ApiService.private();

      final data = {'sampleRate': sampleRate, 'loopPlaylist': loopPlaylist};

      // Add LINE settings if provided
      if (lineChannelAccessToken != null)
        data['lineChannelAccessToken'] = lineChannelAccessToken;
      if (lineChannelSecret != null)
        data['lineChannelSecret'] = lineChannelSecret;
      if (lineUserId != null) data['lineUserId'] = lineUserId;
      if (lineNotifyEnabled != null)
        data['lineNotifyEnabled'] = lineNotifyEnabled;
      if (lineMessageStart != null) data['lineMessageStart'] = lineMessageStart;
      if (lineMessageEnd != null) data['lineMessageEnd'] = lineMessageEnd;
      if (appBaseUrl != null) data['appBaseUrl'] = appBaseUrl;

      final response = await api.post('/settings/bulk', data: data);

      return response['ok'] == true;
    } catch (e) {
      throw Exception('Failed to save settings: $e');
    }
  }

  /// รีเซ็ตการตั้งค่าระบบกลับเป็นค่าเริ่มต้น
  static Future<Map<String, dynamic>> resetSettings() async {
    final api = await ApiService.private();
    final response = await api.post('/settings/reset');

    if (response['ok'] == true) {
      return response['data'];
    }
    throw Exception('Failed to reset settings');
  }
}
