/// Centralized application configuration and endpoints.
///
/// Keep network endpoints and timeouts in one place to avoid duplication
/// and make environment switches easier.
class AppConfig {
  // Base HTTP endpoint for REST APIs
  static const String baseUrl = 'http://192.168.1.83:8080';

  // WebSocket endpoints
  static const String wsMic = 'ws://192.168.1.83:8080/ws/mic';
  static const String wsStatus = 'ws://192.168.1.83:8080/ws/status';

  // Server-Sent Events endpoints
  static const String ssePlaylistStatus =
      'http://192.168.1.83:8080/playlist/stream/status-sse';

  // Network timeouts
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 20);
}
