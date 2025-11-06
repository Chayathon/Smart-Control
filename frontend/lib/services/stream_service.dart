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
}
