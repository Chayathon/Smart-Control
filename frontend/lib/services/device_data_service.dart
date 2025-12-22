// lib/services/device_data_service.dart
//
// ✅ หน้าที่ไฟล์นี้:
// - ดึงข้อมูล device data ผ่าน HTTP
// - subscribe WebSocket สำหรับ realtime
//
// ✅ บั๊กที่แก้:
// Backend ของคุณส่ง WS แบบ "batch" คือ { data: [ {...}, {...} ] }
// แต่เดิม Flutter คิดว่าได้ Map แถวเดียว → onData() จะได้ object ที่ไม่มี nodeId/flag/alarms → กลายเป็น null
// แก้โดย: ถ้า payload มี key 'data' เป็น List → แตก list แล้ว onData ทีละ item

import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:smart_control/core/network/api_service.dart';

typedef Json = Map<String, dynamic>;

/// ตัว model บาง ๆ (ถ้าหน้าจอเก่าอ้าง `DeviceData` เฉย ๆ จะคอมไพล์ผ่าน)
/// หมายเหตุ: ถ้าหน้าจอเก่าคาดหวัง property แบบจิ้มผ่าน dot (เช่น data.acV)
/// จะไม่เจอ (เพราะเราเก็บเป็น raw Map)
class DeviceData {
  final Map<String, dynamic> raw;
  DeviceData(this.raw);
}

class DeviceDataService {
  DeviceDataService._internal();
  static final DeviceDataService instance = DeviceDataService._internal();

  WebSocketChannel? _channel;

  /// HTTP: ดึงรายการ (รองรับทั้ง response เป็น Map{data:[...]} หรือเป็น List ตรง ๆ)
  Future<List<dynamic>> fetchAll({required String path}) async {
    final api = await ApiService.private();
    final res = await api.get(path);

    // เคสปกติ: { status: 'success', data: [...] }
    if (res is Map && res['data'] is List) {
      return List<dynamic>.from(res['data']);
    }

    // เคสบางระบบ: คืนเป็น List ตรง ๆ
    if (res is List) return res;

    return const [];
  }

  /// ✅ alias ให้กับชื่อเก่า
  Future<List<dynamic>> fetchRecent(String path) => fetchAll(path: path);

  /// ✅ Realtime: รองรับ payload ได้ 3 แบบ
  /// 1) { doc: {...} }                     (บางระบบชอบห่อ doc)
  /// 2) { data: [ {...}, {...} ] }         (ของคุณตอนนี้ / batch)
  /// 3) { ...row... }                      (ยิงมาแถวเดียวตรง ๆ)
  void subscribeToRealtime(
    void Function(Map<String, dynamic>) onData, {
    required String url,
  }) {
    // ปิด channel เก่าก่อน (กันซ้อนหลาย connection)
    try {
      _channel?.sink.close();
    } catch (_) {}

    _channel = WebSocketChannel.connect(Uri.parse(url));

    _channel!.stream.listen(
      (message) {
        try {
          // 1) decode JSON (รองรับทั้ง String และ bytes)
          final decoded = _safeDecode(message);

          // ถ้า decode ไม่ได้ หรือไม่ใช่ Map → ไม่ทำอะไร
          if (decoded is! Map<String, dynamic>) return;

          // 2) Case: { doc: {...} }
          // บางระบบส่งมาเป็น { doc: row }
          if (decoded.containsKey('doc') && decoded['doc'] is Map) {
            onData(Map<String, dynamic>.from(decoded['doc'] as Map));
            return;
          }

          // 3) Case: { data: [ {...}, {...} ] }  ✅ สำคัญสุดของโปรเจกต์คุณ
          // backend ของคุณ broadcastDeviceData({ data: batch })
          // ถ้าไม่แตก list → UI จะอ่าน nodeId/flag/alarms ไม่เจอ → null
          if (decoded.containsKey('data') && decoded['data'] is List) {
            final list = List.from(decoded['data'] as List);

            // แตก batch ทีละแถว ส่งเข้า UI
            for (final item in list) {
              if (item is Map) {
                onData(Map<String, dynamic>.from(item));
              }
            }
            return;
          }

          // 4) Case: ได้แถวเดียวตรง ๆ
          onData(decoded);
        } catch (_) {
          // ถ้า parse พลาด อย่าให้ crash
        }
      },
      onError: (err) {
        // ถ้าต้องการ log เพิ่มค่อยใส่
        // print('[DeviceDataService] ws error: $err');
      },
      onDone: () {
        // ถ้าต้องการ auto-reconnect ค่อยเพิ่มภายหลัง
        // print('[DeviceDataService] ws done');
      },
    );
  }

  /// ✅ alias ให้กับชื่อเก่า
  void subscribeRealtime(
    void Function(Map<String, dynamic>) onData, {
    required String url,
  }) =>
      subscribeToRealtime(onData, url: url);

  /// decode message ที่มาเป็น String หรือ bytes
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
