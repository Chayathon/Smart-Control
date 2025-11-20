// lib/services/device_data_service.dart
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:smart_control/core/network/api_service.dart';

typedef Json = Map<String, dynamic>;

/// ตัว model บาง ๆ (ถ้าหน้าจอเก่าอ้าง `DeviceData` เฉย ๆ จะคอมไพล์ผ่าน)
/// หมายเหตุ: ถ้าหน้าจอเก่าคาดหวัง property แบบจิ้มผ่าน dot (เช่น data.acV)
/// จะไม่เจอ (เพราะเราเก็บเป็น raw Map) แนะนำใช้ทางเลือก A ดีกว่า
class DeviceData {
  final Map<String, dynamic> raw;
  DeviceData(this.raw);
}

class DeviceDataService {
  DeviceDataService._internal();
  static final DeviceDataService instance = DeviceDataService._internal();

  WebSocketChannel? _channel;

  /// ใหม่ (เราใช้ในโค้ดชุดล่าสุด)
  Future<List<dynamic>> fetchAll({required String path}) async {
    final api = await ApiService.private();
    final res = await api.get(path);
    if (res is Map && res['data'] is List) {
      return List<dynamic>.from(res['data']);
    }
    if (res is List) return res;
    return const [];
  }

  /// ✅ alias ให้กับชื่อเก่า
  Future<List<dynamic>> fetchRecent(String path) => fetchAll(path: path);

  /// ใหม่ (เราใช้ในโค้ดชุดล่าสุด)
  void subscribeToRealtime(
    void Function(Map<String, dynamic>) onData, {
    required String url,
  }) {
    try {
      _channel?.sink.close();
    } catch (_) {}

    _channel = WebSocketChannel.connect(Uri.parse(url));
    _channel!.stream.listen(
      (message) {
        try {
          final data = _safeDecode(message);
          if (data is Map<String, dynamic>) {
            if (data.containsKey('doc') && data['doc'] is Map) {
              onData(Map<String, dynamic>.from(data['doc']));
            } else {
              onData(data);
            }
          }
        } catch (_) {}
      },
      onError: (_) {},
      onDone: () {},
    );
  }

  /// ✅ alias ให้กับชื่อเก่า
  void subscribeRealtime(
    void Function(Map<String, dynamic>) onData, {
    required String url,
  }) => subscribeToRealtime(onData, url: url);

  dynamic _safeDecode(dynamic message) {
    if (message is String) {
      return jsonDecode(message);
    }
    if (message is List<int>) {
      return jsonDecode(utf8.decode(message));
    }
    return null;
  }

  void dispose() {
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }
}
