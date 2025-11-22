/// Centralized application configuration and endpoints.
///
/// Keep network endpoints and timeouts in one place to avoid duplication
/// and make environment switches easier.
class AppConfig {
  // Base HTTP endpoint for REST APIs
  static const String baseUrl = 'http://192.168.1.83:8080';
  // static const String baseUrl = 'http://localhost:8080';

  // WebSocket endpoints
  static const String wsMic = 'ws://192.168.1.83:8080/ws/mic';
  static const String wsStatus = 'ws://192.168.1.83:8080/ws/status';

  // ✅ NEW: realtime deviceData WS
  static const String wsDeviceData = 'ws://localhost:8080/ws/device-data';

  // Server-Sent Events endpoints
  static const String ssePlaylistStatus =
      'http://192.168.1.83:8080/playlist/stream/status-sse';

  // ===== REST paths =====
  // ✅ เพิ่ม path สำหรับโหลด deviceData ครั้งแรก
  static const String deviceDataPath = '/deviceData';

  // Network timeouts
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 20);
}
