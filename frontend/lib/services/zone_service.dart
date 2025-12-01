import 'dart:convert';

import 'package:smart_control/core/network/api_service.dart';
import 'package:smart_control/core/config/app_config.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ZoneService {
  ZoneService._internal();

  static final ZoneService instance = ZoneService._internal();

  WebSocketChannel? _channel;
  String statusWsUrl = AppConfig.wsStatus;

  Future<List<dynamic>> fetchAllZones() async {
    final api = await ApiService.private();
    final result = await api.get('/device');
    return result as List<dynamic>;
  }

  Future<Map<String, dynamic>> getStatusZone(String displayText) async {
    final api = await ApiService.private();
    final result = await api.post(
      '/mqtt/publishAndWait',
      data: {'zone': displayText},
    );
    return Map<String, dynamic>.from(result);
  }

  Future<void> setStream(String zoneNumber, bool enable) async {
    final api = await ApiService.private();
    await api.post(
      '/mqtt/publish',
      data: {
        'topic': 'mass-radio/zone$zoneNumber/command',
        'payload': {'set_stream': enable},
      },
    );
  }

  Future<void> setVolume(String zoneNumber, int volume) async {
    final api = await ApiService.private();
    await api.post(
      '/mqtt/publish',
      data: {
        'topic': 'mass-radio/zone$zoneNumber/command',
        'payload': {'set_volume': volume},
      },
    );
  }

  Future<void> setAllStreamsBasedOnStatus() async {
    final statuses = await getDevicesStatus();
    // Check if any zone has stream_enabled = true
    final anyEnabled = statuses.any(
      (z) => z['data'] != null && z['data']['stream_enabled'] == true,
    );
    final api = await ApiService.private();
    await api.post(
      '/mqtt/publish',
      data: {
        'topic': 'mass-radio/all/command',
        'payload': {'set_stream': !anyEnabled},
      },
    );
  }

  Future<void> setAllVolume(int volume) async {
    final api = await ApiService.private();
    await api.post(
      '/mqtt/publish',
      data: {
        'topic': 'mass-radio/all/command',
        'payload': {'set_volume': volume},
      },
    );
  }

  Future<List<dynamic>> getDevicesStatus() async {
    final api = await ApiService.private();
    final result = await api.get('/mqtt/status');
    return result as List<dynamic>;
  }

  /// Subscribe to realtime zone status updates. The provided callback receives
  /// the decoded JSON payload for each message.
  void subscribeToStatusUpdates(
    void Function(Map<String, dynamic>) onData, {
    String? url,
  }) {
    // Close existing channel if present
    try {
      _channel?.sink.close();
    } catch (_) {}

    final ws = url ?? statusWsUrl;
    _channel = WebSocketChannel.connect(Uri.parse(ws));
    _channel!.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message);
          if (data is Map<String, dynamic>) {
            onData(data);
          }
        } catch (e) {
          // ignore JSON errors
          // print('ZoneService: ws decode error: $e');
        }
      },
      onError: (err) {
        // print('ZoneService ws error: $err');
      },
      onDone: () {
        // closed
      },
    );
  }

  void dispose() {
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }
}
