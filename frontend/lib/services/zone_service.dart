import 'dart:convert';

import 'package:smart_control/core/network/api_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ZoneService {
  ZoneService._internal();

  static final ZoneService instance = ZoneService._internal();

  WebSocketChannel? _channel;
  String statusWsUrl = 'ws://192.168.1.83:8080/ws/status';

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

  Future<List<dynamic>> getDevicesStatus() async {
    final api = await ApiService.private();
    final result = await api.get('/mqtt/devices/status');
    return result as List<dynamic>;
  }

  /// Toggles all streams depending on current devices status.
  /// If at least one device is playing, it will stop all; otherwise it will start all.
  Future<void> toggleAllStreamsBasedOnStatus() async {
    final statuses = await getDevicesStatus();
    final anyPlaying = statuses.any(
      (z) => z['data'] != null && z['data']['is_playing'] == true,
    );
    final api = await ApiService.private();
    await api.post(
      '/mqtt/publish',
      data: {
        'topic': 'mass-radio/all/command',
        'payload': {'set_stream': !anyPlaying},
      },
    );
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
