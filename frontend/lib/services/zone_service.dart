import 'dart:async'; // ✅ NEW
import 'dart:convert';

import 'package:smart_control/core/network/api_service.dart';
import 'package:smart_control/core/config/app_config.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ZoneService {
  ZoneService._internal();

  static final ZoneService instance = ZoneService._internal();

  WebSocketChannel? _channel;
  String statusWsUrl = AppConfig.wsStatus;

  // ✅ NEW: เก็บ online/offline ของแต่ละ zone
  final Map<int, bool> _onlineByZone = {};

  // ✅ NEW: broadcast ให้หลายจอ subscribe ได้
  final _onlineStreamCtrl = StreamController<Map<int, bool>>.broadcast();

  /// ✅ NEW: stream ใช้ใน UI
  Stream<Map<int, bool>> get onlineStream => _onlineStreamCtrl.stream;

  /// ✅ NEW: snapshot ปัจจุบัน
  Map<int, bool> get currentOnlineMap => Map.unmodifiable(_onlineByZone);

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
            // ✅ NEW: อัปเดต online map จาก message ทุกตัว
            _handleStatusForOnlineMap(data);

            // callback เดิมยังทำงานเหมือนเดิม
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

  /// ✅ NEW: เรียกใช้ตอนอยากให้ WS ต่อแน่ ๆ แต่ไม่สน data ดิบ
  void ensureStatusWsConnected() {
    if (_channel != null) return;
    // ใช้ callback ว่าง ๆ ก็พอ เราไปใช้จาก onlineStream แทน
    subscribeToStatusUpdates((_) {});
  }

  /// ✅ NEW: handle ข้อมูลจาก /ws/status → map zone → online/offline
  void _handleStatusForOnlineMap(Map<String, dynamic> data) {
    // ต้องเป็น type = 'status' ถึงจะสน
    if (data['type'] != 'status') return;

    final zone = data['zone'];
    if (zone is! int) return;

    // ถ้า offline = true → offline, ถ้าไม่ใช่/ไม่มี → online
    final offline = data['offline'] == true;
    final online = !offline;

    // ถ้าไม่มีการเปลี่ยนแปลง ไม่ต้อง broadcast
    if (_onlineByZone[zone] == online) return;

    _onlineByZone[zone] = online;

    // ส่งสำเนา map ให้คนฟัง
    _onlineStreamCtrl.add(Map<int, bool>.from(_onlineByZone));
  }

  void dispose() {
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;

    // ❗ ไม่ปิด _onlineStreamCtrl นะ (กันกรณี app ยังใช้ต่อ)
    // ถ้าจะปิดจริง ๆ ต้องแน่ใจว่าไม่มีจอไหนใช้แล้ว
  }
}
