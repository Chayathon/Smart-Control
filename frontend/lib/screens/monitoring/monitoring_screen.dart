// lib/screens/monitoring/monitoring_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;

import 'package:smart_control/core/config/app_config.dart';
import 'package:smart_control/services/device_data_service.dart';

import 'parts/map_card.dart';
import 'parts/list_card.dart'; // MonitoringKind, TypeFilter, StatusFilter
import 'parts/notification.dart'; // NotificationCenter + NodeAlarmSummary
import 'parts/mini_stats.dart'; // MetricKey
import 'parts/metric_line_chart.dart'; // กราฟจริง

typedef Json = Map<String, dynamic>;

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  final _svc = DeviceDataService.instance;

  /// เก็บรายการล่าสุด (1 row ต่อ 1 nodeId - ใช้ meta.no)
  final List<Json> _items = [];

  /// history ตาม nodeId (ใช้กับกราฟ)
  final Map<String, List<Json>> _historyById = {};

  // UI states
  bool _loading = true;
  String? _error;
  Timer? _tick; // ให้ time-ago รีเฟรชเองทุก 1 วินาที
  String? _selectedId; // nodeId ที่เลือก (เช่น "no1")

  // ฟิลเตอร์
  TypeFilter _typeFilter = TypeFilter.all;
  StatusFilter _statusFilter = StatusFilter.all;

  // metric ปัจจุบัน (ส่งให้ MiniStats / กราฟ)
  // เริ่มต้นใช้ DC Voltage เป็น metric หลัก
  MetricKey _activeMetric = MetricKey.vdc;

  // Map camera states
  final MapController _mapController = MapController();
  late latlng.LatLng _currentCenter;
  double _currentZoom = 18.0;
  int _camAnimToken = 0;

  final _listController = ScrollController();

  // ===== Notification Center states (แบบใหม่: ระดับโหนด) =====
  bool _showNotificationCenter = false;

  /// key = nodeId (เช่น "no1"), value = summary alarm ของโหนดนั้น ๆ
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
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
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

      // ✅ สร้าง _nodeAlarms จาก "แถวล่าสุด" เท่านั้น
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
            '⚡ [Monitoring] realtime row nodeId=${_idOf(row)} alarms=${row['alarms']} flag=${row['flag']}');
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

  /// รวมข้อมูลเข้ากับเดิมโดยอิง nodeId และใช้ "timestamp ล่าสุดจริง ๆ"
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

  /// ดึง alarms จาก row ให้กลายเป็น Map<String,int>
  ///
  /// รองรับ alarms จาก backend ใหม่:
  /// {
  ///   acSensor,   // 0/1
  ///   acVoltage,  // 0/1/2
  ///   acCurrent,  // 0/1
  ///   dcSensor,   // 0/1
  ///   dcVoltage,  // 0/1/2
  ///   dcCurrent,  // 0/1
  ///   oat         // 0/1
  /// }
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
  }

  /// อัปเดต summary alarm ระดับ "โหนด" (1 การ์ดต่อโหนดใน NotificationCenter)
  ///
  /// ใช้ "ข้อมูลล่าสุดของแต่ละโหนด" เป็นตัวตัดสิน:
  /// - ถ้าแถวนี้เก่ากว่า timestamp ที่เคยจำไว้ของโหนดนั้น → ข้าม
  /// - ถ้าแถวนี้ใหม่สุดและไม่มี alarm / สถานะให้แสดง → ลบโหนดนี้ออกจาก _nodeAlarms
  /// - ถ้าแถวนี้ใหม่สุดและมีอย่างน้อย 1 field → เก็บเป็น NodeAlarmSummary
  ///
  /// ✅ พิเศษ:
  /// - field `online` & `oat` ให้เก็บทั้งค่า 0 และ 1 (สถานะ)
  /// - field อื่น (acSensor/acVoltage/.../dcCurrent) เก็บเฉพาะค่าที่ != 0
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
    final alarms = _extractAlarms(row['alarms']);

    // ✅ เก็บ field ที่ต้องแสดงบนการ์ด
    final abnormal = <String, int>{};

    alarms.forEach((key, value) {
      if (value == null) return;

      if (key == 'online' || key == 'oat') {
        // ✅ online & oat: เก็บทั้ง 0 และ 1 เป็นสถานะ
        abnormal[key] = _asInt(value) ?? 0;
      } else {
        // field อื่น: เก็บเฉพาะค่าที่ != 0 (ผิดปกติเท่านั้น)
        final intVal = _asInt(value);
        if (intVal != null && intVal != 0) {
          abnormal[key] = intVal;
        }
      }
    });

    if (abnormal.isEmpty) {
      // ✅ ไม่มีอะไรให้แสดง (ไม่มี alarm และไม่มีสถานะ online/oat)
      //    → ลบโหนดนี้ออกจากแผงแจ้งเตือน
      debugPrint(
          '✅ [Monitoring] clear alarm nodeId=$id (no alarms & no online/oat field)');
      _nodeAlarms.remove(id);
      return;
    }

    final existing = _nodeAlarms[id];

    if (existing == null) {
      // โหนดนี้เพิ่งมีข้อมูลแจ้งเตือน/สถานะครั้งแรก
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

  /// ตอนนี้มีระบบเดียวคือ wireless (SIM)
  MonitoringKind _kindOf(Json row) {
    return MonitoringKind.wirelessSim;
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

  Json _normalize(dynamic raw) {
    final Map<String, dynamic> m =
        (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

    // timestamp: {"$date": "..."} | "..." | epoch
    final ts = m['timestamp'];
    DateTime? t;
    if (ts is Map && ts[r'$date'] != null) {
      t = _toDate(ts[r'$date']);
    } else {
      t = _toDate(ts);
    }
    m['timestamp'] = (t ?? DateTime.now().toUtc()).toIso8601String();

    m['meta'] = (m['meta'] is Map)
        ? Map<String, dynamic>.from(m['meta'])
        : <String, dynamic>{};

    // status ตอนนี้ไม่ได้ใช้แล้ว แต่คง field ไว้เผื่ออนาคต
    m['status'] =
        (m['status'] ?? '').toString().isNotEmpty ? m['status'] : 'unknown';

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
    final lng =
        coords.map((p) => p.longitude).reduce((a, b) => a + b) / coords.length;
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

    // ฟิลเตอร์ชนิด
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
      }
    }).toList();

    // เรียงตามชื่ออุปกรณ์ (A→Z)
    byType.sort(
      (a, b) => _nameOf(a).toUpperCase().compareTo(
            _nameOf(b).toUpperCase(),
          ),
    );

    final totalCount = byType.length;
    final onlineCount = byType.where(_onlineOf).length;
    final offlineCount = totalCount - onlineCount;

    // ฟิลเตอร์สถานะ
    final filtered = byType.where((row) {
      switch (_statusFilter) {
        case StatusFilter.all:
          return true;
        case StatusFilter.online:
          return _onlineOf(row);
        case StatusFilter.offline:
          return !_onlineOf(row);
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
                                            MonitoringListPanel(
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
                                              MonitoringListPanel(
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
                                              selectedRow == null
                                                  ? null
                                                  : _nameOf(
                                                      selectedRow),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 4,
                                        child: MiniStats(
                                          current:
                                              selectedRow,
                                          activeMetric:
                                              _activeMetric,
                                          onSelectMetric: (m) =>
                                              setState(() =>
                                                  _activeMetric =
                                                      m),
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
