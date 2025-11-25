import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // Base HTTP endpoint for REST APIs
  static String get baseUrl =>
      dotenv.get('BASE_URL', fallback: 'http://localhost:8080');

  // WebSocket endpoints
  static String get wsMic =>
      dotenv.get('WS_MIC', fallback: 'ws://localhost:8080/ws/mic');
  static String get wsStatus =>
      dotenv.get('WS_STATUS', fallback: 'ws://localhost:8080/ws/status');
  static String get wsDeviceData => dotenv.get(
    'WS_DEVICE_DATA',
    fallback: 'ws://localhost:8080/ws/device-data',
  );

  // Server-Sent Events endpoints
  static String get ssePlaylistStatus => dotenv.get(
    'SSE_PLAYLIST_STATUS',
    fallback: 'http://localhost:8080/playlist/stream/status-sse',
  );

  // ✅ เพิ่ม path สำหรับโหลด deviceData ครั้งแรก
  static String get deviceDataPath =>
      dotenv.get('DEVICE_DATA_PATH', fallback: '/deviceData');

  // Network timeouts
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 20);
}
