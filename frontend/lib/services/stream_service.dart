import 'package:smart_control/core/network/api_service.dart';

class StreamService {
  static final StreamService _instance = StreamService._internal();
  factory StreamService() => _instance;
  StreamService._internal();

  static StreamService get instance => _instance;

  Future<Map<String, dynamic>> enableStream() async {
    final api = await ApiService.private();
    return await api.post<Map<String, dynamic>>(
      '/stream/enable',
      decoder: (data) => data as Map<String, dynamic>,
    );
  }

  Future<Map<String, dynamic>> disableStream() async {
    final api = await ApiService.private();
    return await api.post<Map<String, dynamic>>(
      '/stream/disable',
      decoder: (data) => data as Map<String, dynamic>,
    );
  }

  Future<List<dynamic>> getStatus() async {
    final api = await ApiService.private();
    return await api.get<List<dynamic>>(
      '/mqtt/status',
      decoder: (data) => data as List<dynamic>,
    );
  }

  // Playback control methods
  Future<void> playPlaylist() async {
    final api = await ApiService.private();
    await api.get('/stream/start-playlist');
  }

  Future<void> playFile(String songId) async {
    final api = await ApiService.private();
    await api.get('/stream/start-file', query: {'songId': songId});
  }

  Future<void> playYoutube(String url) async {
    final api = await ApiService.private();
    await api.get('/stream/start-youtube', query: {'url': url});
  }

  Future<void> pause() async {
    final api = await ApiService.private();
    await api.get('/stream/pause');
  }

  Future<void> resume() async {
    final api = await ApiService.private();
    await api.get('/stream/resume');
  }

  Future<void> stop() async {
    final api = await ApiService.private();
    await api.get('/stream/stop');
  }

  Future<void> next() async {
    final api = await ApiService.private();
    await api.get('/stream/next-track');
  }

  Future<void> prev() async {
    final api = await ApiService.private();
    await api.get('/stream/prev-track');
  }

  Future<Map<String, dynamic>> getStreamStatus() async {
    final api = await ApiService.private();
    final response = await api.get('/stream/status');
    return response['data'] ?? response;
  }
}
