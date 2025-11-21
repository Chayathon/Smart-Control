// lib/screens/monitoring/monitoring_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;

import 'package:smart_control/core/config/app_config.dart';
import 'package:smart_control/services/device_data_service.dart';

import 'parts/map_card.dart';
<<<<<<< HEAD
import 'parts/list_card.dart' as lc; // MonitoringKind, TypeFilter, StatusFilter, MonitoringListPanel
import 'parts/notification.dart'; // NotificationCenter + NodeAlarmSummary
import 'parts/mini_stats.dart' as ms; // MetricKey + MiniStats
=======
import 'parts/list_card.dart'; // MonitoringKind, TypeFilter, StatusFilter
import 'parts/notification.dart'; // NotificationCenter + NodeAlarmSummary
import 'parts/mini_stats.dart'; // MetricKey
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
import 'parts/metric_line_chart.dart'; // กราฟจริง

typedef Json = Map<String, dynamic>;

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  final _svc = DeviceDataService.instance;

<<<<<<< HEAD
  /// เก็บรายการล่าสุด (1 row ต่อ 1 nodeId - ใช้ meta.no)
=======
  /// เก็บรายการล่าสุด (1 row ต่อ 1 nodeId)
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
  final List<Json> _items = [];

  /// history ตาม nodeId (ใช้กับกราฟ)
  final Map<String, List<Json>> _historyById = {};

  // UI states
  bool _loading = true;
  String? _error;
<<<<<<< HEAD
  Timer? _tick; // ให้ time-ago รีเฟรชเองทุก 1 วินาที
  String? _selectedId; // nodeId ที่เลือก (เช่น "no1")

  // ฟิลเตอร์
  lc.TypeFilter _typeFilter = lc.TypeFilter.all;
  lc.StatusFilter _statusFilter = lc.StatusFilter.all;

  // metric ปัจจุบัน (ส่งให้ MiniStats / กราฟ)
  // เริ่มต้นใช้ DC Voltage เป็น metric หลัก
  ms.MetricKey _activeMetric = ms.MetricKey.dcV;
=======
  Timer? _tick; // ให้ time-ago รีเฟรชเองทุก 15 วินาที
  String? _selectedId; // nodeId ที่เลือก (เดิมคือ devEui)

  // ฟิลเตอร์
  TypeFilter _typeFilter = TypeFilter.all;
  StatusFilter _statusFilter = StatusFilter.all;

  // metric ปัจจุบัน (ส่งให้ MiniStats / กราฟ)
  // ✅ ตอนนี้ใช้ DC เท่านั้น
  MetricKey _activeMetric = MetricKey.dcV;
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c

  // Map camera states
  final MapController _mapController = MapController();
  late latlng.LatLng _currentCenter;
  double _currentZoom = 18.0;
  int _camAnimToken = 0;

  final _listController = ScrollController();

<<<<<<< HEAD
  // ===== Notification Center states (แบบใหม่: ระดับโหนด) =====
  bool _showNotificationCenter = false;

  /// key = nodeId (เช่น "no1"), value = summary alarm ของโหนดนั้น ๆ
=======
  // ===== Notification Center states (ระดับโหนด) =====
  bool _showNotificationCenter = false;

  /// key = nodeId, value = summary alarm ของโหนดนั้น ๆ
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
  final Map<String, NodeAlarmSummary> _nodeAlarms = {};

  /// timestamp ล่าสุดของแต่ละโหนด (ใช้ตัดสินว่า row ไหนใหม่สุด)
  final Map<String, DateTime> _latestTsById = {};

  /// จำนวนโหนดที่ยังไม่ได้อ่าน (ใช้ทำจุดแดงบนไอคอนกระดิ่ง)
  int get _unreadCount =>
      _nodeAlarms.values.where((n) => n.hasUnread).length;

  @override
  void initState() {
    super.initState();
    _currentCenter = const latlng.LatLng(13.6580, 100.6608);
    _init();
<<<<<<< HEAD
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
=======
    _tick = Timer.periodic(const Duration(seconds: 15), (_) {
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
      if (mounted) setState(() {});
    });
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    // เคลียร์ state เดิมให้เริ่มจากข้อมูลรอบนี้ล้วน ๆ
    _items.clear();
    _historyById.clear();
    _nodeAlarms.clear();
    _latestTsById.clear();

    try {
      // 1) โหลดครั้งแรกผ่าน REST
      final list = await _svc.fetchAll(path: AppConfig.deviceDataPath);
      debugPrint('🔍 [Monitoring] fetched rows = ${list.length}');
      final normalized = list.map<Json>(_normalize).toList();

      // ✅ รอบแรก: เก็บ history + สร้าง _items ให้เหลือแค่ "แถวล่าสุดของแต่ละโหนด"
      for (final row in normalized) {
        _upsert(
          row,
          fromRealtime: false,
          updateAlarm: false, // ยังไม่แตะ _nodeAlarms ในรอบแรก
        );
      }

<<<<<<< HEAD
      // ✅ สร้าง _nodeAlarms จาก "แถวล่าสุด" เท่านั้น
=======
      // ✅ สร้าง _nodeAlarms จาก "แถวล่าสุด" เท่านั้น (ใช้ flag ปัจจุบัน)
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
      _rebuildNodeAlarmsFromLatest();

      debugPrint(
          '🔔 [Monitoring] nodeAlarms after init = ${_nodeAlarms.length}');

      _currentCenter = _avgCenter(_items);
      _selectedId ??= _items.isNotEmpty ? _idOf(_items.first) : null;

      setState(() => _loading = false);

      // 2) เปิด WebSocket แบบเรียลไทม์
      _svc.subscribeToRealtime((msg) {
        final row = _normalize(msg);
        debugPrint(
<<<<<<< HEAD
            '⚡ [Monitoring] realtime row nodeId=${_idOf(row)} alarms=${row['alarms']} flag=${row['flag']}');
=======
            '⚡ [Monitoring] realtime row nodeId=${_idOf(row)} flag=${row['flag'] ?? row['flags']}');
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
        _upsert(
          row,
          fromRealtime: true, // อัปเดต + ถือว่ามีเหตุการณ์ใหม่
        );
        debugPrint(
            '🔔 [Monitoring] nodeAlarms after realtime = ${_nodeAlarms.length}');
        if (mounted) setState(() {});
      }, url: AppConfig.wsDeviceData);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'โหลดข้อมูลล้มเหลว: $e';
      });
    }
  }

<<<<<<< HEAD
  /// รวมข้อมูลเข้ากับเดิมโดยอิง nodeId และใช้ "timestamp ล่าสุดจริง ๆ"
=======
  /// รวมข้อมูลเข้ากับเดิมโดยอิง nodeId (meta.deviceId / NODE{no})
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
  /// fromRealtime:
  ///   - false = โหลดจากฐานข้อมูลครั้งแรก
  ///   - true  = ข้อมูล realtime จาก WebSocket
  /// updateAlarm:
  ///   - true  = อัปเดต _nodeAlarms ด้วย
  ///   - false = ใช้ตอน init รอบแรก (ค่อยไป rebuild ทีหลัง)
  void _upsert(
    Json row, {
    required bool fromRealtime,
    bool updateAlarm = true,
  }) {
    final id = _idOf(row);
    if (id == null) return;

    // ✅ เก็บ history ให้กราฟ
    final hist = _historyById.putIfAbsent(id, () => <Json>[]);
    hist.add(row);

    final idx = _items.indexWhere((x) => _idOf(x) == id);

    if (idx == -1) {
      // ยังไม่เคยมี node นี้ → ใช้ row นี้เป็นค่าแรก
      _items.insert(0, row);
      if (updateAlarm) {
        _updateNodeAlarmFromRow(row, fromRealtime: fromRealtime);
      }
      return;
    }

    // มี node นี้อยู่แล้ว → อัปเดตเฉพาะถ้า row นี้ "ใหม่กว่า" เดิม
    final existing = _items[idx];

    final existingTs = _toDate(existing['timestamp']) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final newTs = _toDate(row['timestamp']) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    if (newTs.isBefore(existingTs)) {
      // แถวนี้เก่ากว่า → ไม่แตะการ์ด/แจ้งเตือน
      return;
    }

    // row ใหม่นี้คือค่าล่าสุดของโหนด → override ค่าเดิม
    final merged = {...existing, ...row};
    merged['timestamp'] = row['timestamp'] ?? existing['timestamp'];

    _items[idx] = merged;

    if (updateAlarm) {
      _updateNodeAlarmFromRow(merged, fromRealtime: fromRealtime);
    }
  }

  /// ใช้หลังจากโหลดครั้งแรกเสร็จ
  /// สร้าง _nodeAlarms จากค่า “ล่าสุดของแต่ละโหนด” ใน _items
  void _rebuildNodeAlarmsFromLatest() {
    _nodeAlarms.clear();
    _latestTsById.clear();

    for (final row in _items) {
      _updateNodeAlarmFromRow(row, fromRealtime: false);
    }
  }

<<<<<<< HEAD
  /// ดึง alarms จาก row ให้กลายเป็น Map<String,int>
  /// รองรับ alarms จาก backend ใหม่:
  /// { voltage, current, power, oat (On Air Target) }
  Map<String, int> _extractAlarms(dynamic raw) {
    if (raw is Map) {
      final result = <String, int>{};
      raw.forEach((key, value) {
        if (value == null) return;
        int? intVal;
        if (value is int) {
          intVal = value;
        } else if (value is num) {
          intVal = value.toInt();
        } else if (value is String && value.isNotEmpty) {
          intVal = int.tryParse(value);
        }
        if (intVal != null) {
          result[key.toString()] = intVal;
        }
      });
      return result;
    }
    return const {};
=======
  /// แปลง string flags 8 หลัก เช่น "01000020" → field map
  ///
  /// mapping เดิม (ยังใช้ได้กับค่า flagRaw ปัจจุบัน):
  ///  - [0] af_power
  ///  - [1] voltage
  ///  - [2] current
  ///  - [3] battery_filtered
  ///  - [4] solar_v
  ///  - [5] solar_i
  ///  - [6],[7] ยังไม่ใช้
  Map<String, int> _parseFlagsToFields(String flagsRaw) {
    final flags = flagsRaw.replaceAll(r'$', '');
    int digit(int index) {
      if (index < 0 || index >= flags.length) return 0;
      final ch = flags[index];
      final n = int.tryParse(ch);
      return n ?? 0;
    }

    return <String, int>{
      'af_power': digit(0),
      'voltage': digit(1),
      'current': digit(2),
      'battery_filtered': digit(3),
      'solar_v': digit(4),
      'solar_i': digit(5),
    };
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
  }

  /// อัปเดต summary alarm ระดับ "โหนด" (1 การ์ดต่อโหนดใน NotificationCenter)
  ///
  /// ใช้ "ข้อมูลล่าสุดของแต่ละโหนด" เป็นตัวตัดสิน:
  /// - ถ้าแถวนี้เก่ากว่า timestamp ที่เคยจำไว้ของโหนดนั้น → ข้าม
<<<<<<< HEAD
  /// - ถ้าแถวนี้ใหม่สุดและทุกค่า alarm = 0 → ลบโหนดนี้ออกจาก _nodeAlarms
  /// - ถ้าแถวนี้ใหม่สุดและมีค่า != 0 → เก็บเป็น NodeAlarmSummary
=======
  /// - ถ้าแถวนี้ใหม่สุดและทุก digit ใน flag = 0 → ลบโหนดนี้ออกจาก _nodeAlarms
  /// - ถ้าแถวนี้ใหม่สุดและมี digit != 0 → เก็บเป็น NodeAlarmSummary
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
  void _updateNodeAlarmFromRow(Json row, {required bool fromRealtime}) {
    final id = _idOf(row);
    if (id == null) return;

    // timestamp ของแถวนี้ (ถ้าไม่มีให้ fallback เป็นตอนนี้)
    final ts = _toDate(row['timestamp']) ?? DateTime.now().toUtc();

    // ถ้าเคยจำ timestamp ของโหนดนี้แล้ว และ row นี้เก่ากว่า → ไม่แตะ state เดิม
    final prevTs = _latestTsById[id];
    if (prevTs != null && ts.isBefore(prevTs)) {
      debugPrint(
          '⏩ [Monitoring] skip old row nodeId=$id ts=$ts (prev=$prevTs)');
      return;
    }

    // แถวนี้คือข้อมูลล่าสุดของโหนดนี้แล้ว
    _latestTsById[id] = ts;

    final name = _nameOf(row);
<<<<<<< HEAD
    final alarms = _extractAlarms(row['alarms']);

    // เก็บเฉพาะ field ที่ผิดปกติ ( != 0 )
    final abnormal = <String, int>{};
    alarms.forEach((key, value) {
=======

    // ใช้ flag ปัจจุบัน (ถ้าไม่มีให้ถือว่า "00000000")
    final flagRaw = (row['flags'] ?? row['flag'] ?? '').toString();
    final fields = _parseFlagsToFields(flagRaw);

    // เก็บเฉพาะ field ที่ผิดปกติ ( != 0 )
    final abnormal = <String, int>{};
    fields.forEach((key, value) {
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
      if (value != 0) {
        abnormal[key] = value;
      }
    });

    if (abnormal.isEmpty) {
<<<<<<< HEAD
      // ✅ แถวล่าสุดบอกว่าทุกค่า 0 (เช่น flag = 0000)
      //    → โหนดนี้กลับสู่ปกติ → ลบออกจากแผงแจ้งเตือน
      debugPrint(
          '✅ [Monitoring] clear alarm nodeId=$id (all zeros in latest row)');
=======
      // ✅ แถวล่าสุดบอกว่าทุกค่า 0 → โหนดนี้กลับสู่ปกติ → ลบออกจากแผงแจ้งเตือน
      debugPrint(
          '✅ [Monitoring] clear alarm nodeId=$id (flag="$flagRaw" → all zeros)');
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
      _nodeAlarms.remove(id);
      return;
    }

    final existing = _nodeAlarms[id];

    if (existing == null) {
      // โหนดนี้เพิ่งมี alarm จาก "ข้อมูลล่าสุด" เป็นครั้งแรก
      debugPrint(
          '⚠️ [Monitoring] new node alarm nodeId=$id fields=$abnormal fromRealtime=$fromRealtime');
      _nodeAlarms[id] = NodeAlarmSummary(
        nodeId: id,
        name: name,
        lastUpdated: ts,
        fields: abnormal,
        hasUnread: true, // ถือว่ายังไม่ได้อ่าน
      );
    } else {
      // อัปเดตค่า alarm ล่าสุดของโหนดนี้
      existing.lastUpdated = ts;
      existing.fields
        ..clear()
        ..addAll(abnormal);

      // ถ้าเป็น realtime หรือยังไม่เคยอ่านเลย → ถือว่ามีแจ้งเตือนใหม่
      if (fromRealtime || !existing.hasUnread) {
        existing.hasUnread = true;
      }

      debugPrint(
          '♻️ [Monitoring] update node alarm nodeId=$id fields=$abnormal fromRealtime=$fromRealtime');
    }
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is bool) return v ? 1 : 0;
    if (v is num) return v.toInt();
    if (v is String && v.isNotEmpty) return int.tryParse(v);
    return null;
  }

  // ==== Helpers สำหรับข้อมูลจริง ====

<<<<<<< HEAD
  /// ใช้ meta.no / row['no'] เป็นตัวระบุ nodeId เช่น "no1", "no2"
  String? _idOf(Json row) {
    final meta = row['meta'];
    if (meta is Map) {
      final noMeta = meta['no'];
      if (noMeta is int) {
        return 'no$noMeta';
      }
      if (noMeta is String && noMeta.isNotEmpty) {
        return noMeta;
      }
    }

    final noRoot = row['no'];
    if (noRoot is int) {
      return 'no$noRoot';
    }
    if (noRoot is String && noRoot.isNotEmpty) {
      return noRoot;
    }
=======
  /// ใช้ระบุ "ตัวตน" ของโหนด (ใช้เป็น key ใน _items / _history / _nodeAlarms)
  ///
  /// ลำดับ:
  ///  1) meta.deviceId
  ///  2) "NODE{no}" จาก meta.no
  ///  3) meta.devEui
  ///  4) row.deviceId
  ///  5) row.devEui
  String? _idOf(Json row) {
    final meta = row['meta'];
    if (meta is Map) {
      final devId = meta['deviceId']?.toString().trim();
      if (devId != null && devId.isNotEmpty) return devId;

      final no = meta['no']?.toString().trim();
      if (no != null && no.isNotEmpty) return 'NODE$no';

      final devEuiMeta = meta['devEui']?.toString().trim();
      if (devEuiMeta != null && devEuiMeta.isNotEmpty) {
        return devEuiMeta;
      }
    }

    final devIdRow = row['deviceId']?.toString().trim();
    if (devIdRow != null && devIdRow.isNotEmpty) return devIdRow;

    final devEuiRow = row['devEui']?.toString().trim();
    if (devEuiRow != null && devEuiRow.isNotEmpty) return devEuiRow;
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c

    return null;
  }

  Json? _findById(String? id) {
    if (id == null) return null;
    for (final e in _items) {
      if (_idOf(e) == id) return e;
    }
    return null;
  }

  /// ดึง history ตาม nodeId สำหรับส่งเข้า MetricLineChart
  List<Json> _historyForId(String? id) {
    if (id == null) return const [];
    final raw = _historyById[id];
    if (raw == null || raw.isEmpty) return const [];

    final list = List<Json>.from(raw);
    list.sort((a, b) {
      final ta = _toDate(a['timestamp']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final tb = _toDate(b['timestamp']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      return ta.compareTo(tb);
    });
    return list;
  }

<<<<<<< HEAD
  // helper เดิมของ lighting (ตอนนี้เรียกใช้จาก callback ข้างล่าง)
  void _toggleLightingById(String? id, int nextLighting) {
    if (id == null) return;
    final idx = _items.indexWhere((e) => _idOf(e) == id);
    if (idx == -1) return;
    _items[idx] = {
      ..._items[idx],
      'lighting': nextLighting,
    };
    setState(() {});
  }

  /// ตั้งชื่อจาก name ถ้ามี, ถ้าไม่มีก็ใช้ "Node <no>"
  String _nameOf(Json row) {
    final name = (row['name'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;

    final meta = row['meta'];
    if (meta is Map && meta['no'] != null) {
      return 'Node ${meta['no']}';
    }

    if (row['no'] != null) {
      return 'Node ${row['no']}';
    }

    return _idOf(row) ?? '-';
  }

  /// ตัดสิน online/offline จาก timestamp ล่าสุดของ record
  /// - ถ้า timestamp ภายใน 5 วินาทีล่าสุด → online
  /// - ถ้าเกิน 5 วินาที → offline
  bool _onlineOf(Json row) {
    final ts = _toDate(row['timestamp']);
    if (ts == null) return false;

    final now = DateTime.now().toUtc();
    final diff = now.difference(ts);

    // เกิน 5 วินาทีถือว่า offline
    return diff.inSeconds <= 5;
  }

  /// แยกประเภท monitoring จาก type ใหม่ใน backend
  lc.MonitoringKind _kindOf(Json row) {
    final type = (row['type'] ?? '').toString().toLowerCase();
    if (type == 'sim') {
      return lc.MonitoringKind.wirelessSim;
    }

    // fallback: ใช้ชื่อเผื่ออนาคตอยากกลับมาแยก lighting
    final name = (row['name'] ?? '').toString().toUpperCase();
    if (name.contains('LIGHT')) return lc.MonitoringKind.lighting;

    return lc.MonitoringKind.wirelessWave;
=======
  void _toggleLightingById(String? id) {
    if (id == null) return;
    final idx = _items.indexWhere((e) => _idOf(e) == id);
    if (idx == -1) return;
    final cur = _asInt(_items[idx]['lighting']) ?? 0;
    _items[idx] = {..._items[idx], 'lighting': cur == 1 ? 0 : 1};
    setState(() {});
    // TODO: ยิงคำสั่งจริงผ่าน API/WS ถ้าต้องการ
  }

  /// ชื่อแสดงผลของโหนด (ใช้ชื่อเดียวกับ MiniStats)
  String _nameOf(Json row) {
    final meta = row['meta'];
    if (meta is Map) {
      final no = meta['no']?.toString().trim();
      final deviceId = meta['deviceId']?.toString().trim();

      // ถ้ามี no → ใช้เป็น NODE{no} เช่น NODE1, NODE2
      if (no != null && no.isNotEmpty) {
        return 'NODE$no';
      }

      // ถ้าไม่มี no แต่มี deviceId → ใช้ deviceId
      if (deviceId != null && deviceId.isNotEmpty) {
        return deviceId;
      }
    }

    // ถัดมาลองใช้ name ถ้ามี
    final name = (row['name'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;

    // fallback สุดท้าย devEui (ถ้ามี)
    final devEui =
        (row['devEui'] ?? row['meta']?['devEui'] ?? '').toString();
    if (devEui.isNotEmpty) return devEui;

    return '-';
  }

  bool _onlineOf(Json row) {
    final s = (row['status'] ?? '').toString().toLowerCase();
    if (s == 'on') return true;
    if (s == 'off') return false;
    if (row['online'] is bool) return row['online'] as bool;
    return false;
  }

  /// ประเภทโหนด (ใช้กับ list_card.dart)
  ///
  /// ตอนนี้หลังบ้านมี field `type` แล้ว เช่น 'wireless', 'sim'
  /// เลยใช้ตรงนี้แทนการเช็ค acV/acA/acW แบบเดิม
  MonitoringKind _kindOf(Json row) {
    final type = (row['type'] ?? '').toString().toLowerCase();

    if (type.contains('sim')) {
      return MonitoringKind.wirelessSim;
    }
    if (type.contains('wave')) {
      return MonitoringKind.wirelessWave;
    }

    // ถ้าไม่ได้ระบุ type ชัดเจน ให้ถือว่าเป็นระบบไร้สายหลัก
    return MonitoringKind.wirelessWave;
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
  }

  DateTime? _toDate(dynamic v) {
    try {
      if (v == null) return null;
      if (v is DateTime) return v.toUtc();
      if (v is int) {
        return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true);
      }
      if (v is String && v.isNotEmpty) return DateTime.parse(v).toUtc();
    } catch (_) {}
    return null;
  }

<<<<<<< HEAD
=======
  /// normalize ให้ timestamp เป็น ISO string, meta เป็น Map, status ไม่ว่าง
  ///
  /// รูปแบบหลังบ้านตอนนี้:
  ///  - timestamp: ts
  ///  - meta: { deviceId, no, ... }
  ///  - dcV, dcA, dcW, oat, lat, lng, type, flag
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
  Json _normalize(dynamic raw) {
    final Map<String, dynamic> m =
        (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

    // timestamp: {"$date": "..."} | "..." | epoch
<<<<<<< HEAD
    final ts = m['timestamp'];
=======
    final ts = m['timestamp'] ?? m['ts'];
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
    DateTime? t;
    if (ts is Map && ts[r'$date'] != null) {
      t = _toDate(ts[r'$date']);
    } else {
      t = _toDate(ts);
    }
    m['timestamp'] = (t ?? DateTime.now().toUtc()).toIso8601String();

<<<<<<< HEAD
=======
    // meta
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
    m['meta'] = (m['meta'] is Map)
        ? Map<String, dynamic>.from(m['meta'])
        : <String, dynamic>{};

<<<<<<< HEAD
    // status ตอนนี้ไม่ได้ใช้แล้ว แต่คง field ไว้เผื่ออนาคต
    m['status'] =
        (m['status'] ?? '').toString().isNotEmpty ? m['status'] : 'unknown';

=======
    // status (ถ้าไม่มีให้เป็น 'unknown')
    m['status'] =
        (m['status'] ?? '').toString().isEmpty ? 'unknown' : m['status'];

    // ค่า dcV/dcA/dcW/oat/lat/lng/type/flag จะคงตามที่ backend ส่งมา
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
    return m;
  }

  latlng.LatLng _avgCenter(List<Json> list) {
    final coords = list
        .map((e) => (e['lat'] is num && e['lng'] is num)
            ? latlng.LatLng(
                (e['lat'] as num).toDouble(),
                (e['lng'] as num).toDouble(),
              )
            : null)
        .whereType<latlng.LatLng>()
        .toList();
    if (coords.isEmpty) {
      return const latlng.LatLng(13.6580, 100.6608);
    }
    final lat =
        coords.map((p) => p.latitude).reduce((a, b) => a + b) / coords.length;
<<<<<<< HEAD
    final lng =
        coords.map((p) => p.longitude).reduce((a, b) => a + b) / coords.length;
=======
    final lng = coords
            .map((p) => p.longitude)
            .reduce((a, b) => a + b) /
        coords.length;
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
    return latlng.LatLng(lat, lng);
  }

  void _smoothFocusMapOn(Json row) {
    if (row['lat'] is! num || row['lng'] is! num) return;
    final target = latlng.LatLng(
      (row['lat'] as num).toDouble(),
      (row['lng'] as num).toDouble(),
    );
    _animateMapTo(target, 19.5, const Duration(milliseconds: 420));
  }

  void _animateMapTo(
    latlng.LatLng target,
    double targetZoom, [
    Duration duration = const Duration(milliseconds: 380),
  ]) {
    final start = _currentCenter;
    final startZoom = _currentZoom;

    _camAnimToken++;
    final token = _camAnimToken;

    const steps = 24;
    final per = Duration(milliseconds: 1 + duration.inMilliseconds ~/ steps);

    double easeInOut(double t) {
      return t < 0.5
          ? 4 * t * t * t
          : 1 - (-2 * t + 2) * (-2 * t + 2) * (-2 * t + 2) / 2;
    }

    for (var i = 1; i <= steps; i++) {
      Future.delayed(per * i, () {
        if (token != _camAnimToken) return;
        final t = easeInOut(i / steps);
        final lat =
            start.latitude + (target.latitude - start.latitude) * t;
        final lng =
            start.longitude + (target.longitude - start.longitude) * t;
        final zoom = startZoom + (targetZoom - startZoom) * t;
        _mapController.move(latlng.LatLng(lat, lng), zoom);
        if (i == steps) {
          _currentCenter = latlng.LatLng(lat, lng);
          _currentZoom = zoom;
        }
      });
    }
  }

  // ===== Notification helpers =====
  void _toggleNotificationCenter() {
    setState(() => _showNotificationCenter = !_showNotificationCenter);
  }

  void _markAllNotifsAsRead() {
    for (final n in _nodeAlarms.values) {
      n.hasUnread = false;
    }
    setState(() {});
  }

  void _markOneAsRead(String nodeId) {
    final s = _nodeAlarms[nodeId];
    if (s != null && s.hasUnread) {
      s.hasUnread = false;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _svc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = Colors.grey[50]!;
    final cardBg = Colors.white;
    final accent = Colors.blue[700]!;
    final textColor = Colors.grey[900]!;
    final border = Colors.grey[200]!;

    final size = MediaQuery.of(context).size;
    final isNarrow = size.width < 900;

<<<<<<< HEAD
    // ฟิลเตอร์ชนิด
    final byType = _items.where((row) {
      final kind = _kindOf(row);
      switch (_typeFilter) {
        case lc.TypeFilter.all:
          return true;
        case lc.TypeFilter.lighting:
          return kind == lc.MonitoringKind.lighting;
        case lc.TypeFilter.wave:
          return kind == lc.MonitoringKind.wirelessWave;
        case lc.TypeFilter.sim:
          return kind == lc.MonitoringKind.wirelessSim;
=======
    // ฟิลเตอร์ชนิด (ตอนนี้ใช้ field type จาก backend)
    final byType = _items.where((row) {
      final kind = _kindOf(row);
      switch (_typeFilter) {
        case TypeFilter.all:
          return true;
        case TypeFilter.lighting:
          return kind == MonitoringKind.lighting;
        case TypeFilter.wave:
          return kind == MonitoringKind.wirelessWave;
        case TypeFilter.sim:
          return kind == MonitoringKind.wirelessSim;
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
      }
    }).toList();

    // เรียงตามชื่ออุปกรณ์ (A→Z)
    byType.sort(
<<<<<<< HEAD
      (a, b) => _nameOf(a).toUpperCase().compareTo(
            _nameOf(b).toUpperCase(),
          ),
=======
      (a, b) =>
          _nameOf(a).toUpperCase().compareTo(_nameOf(b).toUpperCase()),
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
    );

    final totalCount = byType.length;
    final onlineCount = byType.where(_onlineOf).length;
    final offlineCount = totalCount - onlineCount;

    // ฟิลเตอร์สถานะ
    final filtered = byType.where((row) {
<<<<<<< HEAD
      final isOnline = _onlineOf(row);
      switch (_statusFilter) {
        case lc.StatusFilter.all:
          return true;
        case lc.StatusFilter.online:
          return isOnline;
        case lc.StatusFilter.offline:
          return !isOnline;
=======
      switch (_statusFilter) {
        case StatusFilter.all:
          return true;
        case StatusFilter.online:
          return _onlineOf(row);
        case StatusFilter.offline:
          return !_onlineOf(row);
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
      }
    }).toList();

    // Map : List = 60 : 40
    final double topSectionHeight = isNarrow ? 520 : 580;
    final double mapHeight = topSectionHeight * 0.6;
    final double listHeight = topSectionHeight * 0.4;

    final double statsHeight = isNarrow ? 720 : 510;

    final selectedRow = _findById(_selectedId);

    // แปลง map → list และเรียงตามเวลาล่าสุด (ใช้ใน NotificationCenter)
    final nodeAlarmList = _nodeAlarms.values.toList()
      ..sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));

    final Widget mainContent = _loading
        ? const Center(child: CircularProgressIndicator())
        : (_error != null
            ? Center(child: Text(_error!))
            : (_items.isEmpty
                ? const Center(child: Text('ยังไม่มีข้อมูลอุปกรณ์'))
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                              children: [
                                // ===== Map + List =====
                                if (isNarrow)
                                  Column(
                                    children: [
                                      SizedBox(
                                        height: mapHeight,
                                        child: MapCard(
                                          mapController:
                                              _mapController,
                                          items: filtered,
                                          center: _currentCenter,
                                          border: border,
                                          isOnline: _onlineOf,
                                          selectedId: _selectedId,
                                          onMarkerTap:
                                              (row, list) {
                                            setState(() {
                                              _selectedId =
                                                  _idOf(row);
                                            });
                                            _smoothFocusMapOn(
                                                row);
                                            _scrollToRow(
                                                row, filtered);
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        height: listHeight,
                                        child:
<<<<<<< HEAD
                                            lc.MonitoringListPanel(
=======
                                            MonitoringListPanel(
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
                                          items: filtered,
                                          selectedId:
                                              _selectedId,
                                          cardBg: cardBg,
                                          border: border,
                                          accent: accent,
                                          textColor: textColor,
                                          listController:
                                              _listController,
                                          onSelectEntry: (row) {
                                            setState(() =>
                                                _selectedId =
                                                    _idOf(row));
                                            _smoothFocusMapOn(
                                                row);
                                          },
<<<<<<< HEAD
                                          onToggleLighting:
                                              (row,
                                                  nextLighting) {
                                            final id =
                                                _idOf(row);
                                            if (id == null) {
                                              return;
                                            }
                                            _toggleLightingById(
                                                id,
                                                nextLighting);
                                          },
=======
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
                                          typeFilter:
                                              _typeFilter,
                                          onChangeTypeFilter:
                                              (v) =>
                                                  setState(() =>
                                                      _typeFilter =
                                                          v),
                                          statusFilter:
                                              _statusFilter,
                                          onChangeStatusFilter:
                                              (v) => setState(
                                                  () =>
                                                      _statusFilter =
                                                          v),
                                          totalCount:
                                              totalCount,
                                          onlineCount:
                                              onlineCount,
                                          offlineCount:
                                              offlineCount,
                                          kindOf: _kindOf,
                                          onlineOf: _onlineOf,
<<<<<<< HEAD
=======
                                          onToggleLighting:
                                              (row,
                                                  nextLighting) {
                                            final id =
                                                _idOf(row);
                                            if (id == null)
                                              return;
                                            final idx = _items
                                                .indexWhere(
                                                    (e) =>
                                                        _idOf(
                                                            e) == id);
                                            if (idx != -1) {
                                              _items[idx] = {
                                                ..._items[idx],
                                                'lighting':
                                                    nextLighting,
                                              };
                                              setState(() {});
                                            }
                                          },
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  SizedBox(
                                    height: mapHeight +
                                        12 +
                                        listHeight,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 6,
                                          child: MapCard(
                                            mapController:
                                                _mapController,
                                            items: filtered,
                                            center:
                                                _currentCenter,
                                            border: border,
                                            isOnline: _onlineOf,
                                            selectedId:
                                                _selectedId,
                                            onMarkerTap: (row,
                                                list) {
                                              setState(() {
                                                _selectedId =
                                                    _idOf(row);
                                              });
                                              _smoothFocusMapOn(
                                                  row);
                                              _scrollToRow(row,
                                                  filtered);
                                            },
                                          ),
                                        ),
                                        const SizedBox(
                                            width: 16),
                                        Expanded(
                                          flex: 4,
                                          child:
<<<<<<< HEAD
                                              lc.MonitoringListPanel(
=======
                                              MonitoringListPanel(
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
                                            items: filtered,
                                            selectedId:
                                                _selectedId,
                                            cardBg: cardBg,
                                            border: border,
                                            accent: accent,
                                            textColor:
                                                textColor,
                                            listController:
                                                _listController,
                                            onSelectEntry:
                                                (row) {
                                              setState(() =>
                                                  _selectedId =
                                                      _idOf(
                                                          row));
                                              _smoothFocusMapOn(
                                                  row);
                                            },
<<<<<<< HEAD
                                            onToggleLighting:
                                                (row,
                                                    nextLighting) {
                                              final id =
                                                  _idOf(row);
                                              if (id == null) {
                                                return;
                                              }
                                              _toggleLightingById(
                                                  id,
                                                  nextLighting);
                                            },
=======
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
                                            typeFilter:
                                                _typeFilter,
                                            onChangeTypeFilter:
                                                (v) => setState(
                                                    () =>
                                                        _typeFilter =
                                                            v),
                                            statusFilter:
                                                _statusFilter,
                                            onChangeStatusFilter:
                                                (v) => setState(
                                                    () =>
                                                        _statusFilter =
                                                            v),
                                            totalCount:
                                                totalCount,
                                            onlineCount:
                                                onlineCount,
                                            offlineCount:
                                                offlineCount,
                                            kindOf: _kindOf,
                                            onlineOf: _onlineOf,
<<<<<<< HEAD
=======
                                            onToggleLighting:
                                                (row,
                                                    nextLighting) {
                                              final id =
                                                  _idOf(row);
                                              if (id == null)
                                                return;
                                              final idx = _items
                                                  .indexWhere(
                                                      (e) =>
                                                          _idOf(
                                                              e) == id);
                                              if (idx != -1) {
                                                _items[idx] = {
                                                  ..._items[idx],
                                                  'lighting':
                                                      nextLighting,
                                                };
                                                setState(
                                                    () {});  
                                              }
                                            },
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                const SizedBox(height: 12),

                                // ===== กราฟ + MiniStats =====
                                SizedBox(
                                  height: statsHeight,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 6,
                                        child: MetricLineChart(
                                          history:
                                              _historyForId(
                                                  _selectedId),
                                          metric:
                                              _activeMetric,
                                          deviceName:
<<<<<<< HEAD
                                              selectedRow == null
=======
                                              selectedRow ==
                                                      null
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
                                                  ? null
                                                  : _nameOf(
                                                      selectedRow),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 4,
<<<<<<< HEAD
                                        child: ms.MiniStats(
=======
                                        child: MiniStats(
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
                                          current:
                                              selectedRow,
                                          activeMetric:
                                              _activeMetric,
                                          onSelectMetric: (m) =>
                                              setState(() =>
                                                  _activeMetric =
                                                      m),
<<<<<<< HEAD
=======
                                          onToggleLighting: () =>
                                              _toggleLightingById(
                                                  _selectedId),
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  )));

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'ตรวจสอบสถานะ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        actions: [
          // 🔔 ไอคอนแจ้งเตือน + Dot badge ระบุจำนวนโหนดที่มี alarm และยังไม่อ่าน
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  tooltip: 'การแจ้งเตือน',
                  icon: const Icon(
                    Icons.notifications_active_outlined,
                    size: 26,
                  ),
                  onPressed: _toggleNotificationCenter,
                ),
                if (_unreadCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          mainContent,

          if (_showNotificationCenter)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleNotificationCenter,
                child: const SizedBox.shrink(),
              ),
            ),

          if (_showNotificationCenter)
            NotificationCenter(
              items: nodeAlarmList,
              onClose: _toggleNotificationCenter,
              onMarkAllAsRead: _markAllNotifsAsRead,
              onMarkOneAsRead: _markOneAsRead,
            ),
        ],
      ),
    );
  }

  void _scrollToRow(Json target, List<Json> list) {
    final id = _idOf(target);
    final idx = list.indexWhere((e) => _idOf(e) == id);
    if (idx == -1) return;
    _listController.animateTo(
      (idx * 132).toDouble(),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }
}
