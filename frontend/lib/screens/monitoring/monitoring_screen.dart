// lib/screens/monitoring/monitoring_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;

import 'monitoring_mock.dart';
import 'parts/map_card.dart';
import 'parts/list_card.dart';
import 'parts/metric_line_chart.dart';
import 'parts/mini_stats.dart';
import 'parts/notification.dart'; 

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});
  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen>
    with TickerProviderStateMixin {
  late List<MonitoringEntry> items;

  TypeFilter typeFilterEnum = TypeFilter.all;
  StatusFilter statusFilterEnum = StatusFilter.all;

  bool _showNotificationCenter = false; 

  // *** เปลี่ยนเป็นตัวแปรที่สามารถเปลี่ยนแปลงได้ (ไม่มี final) ***
  int _unreadCount = 2; // Mock: ถ้า > 0 จะแสดงจุดสีแดง
  // **********************************************************

  String? selectedId;

  final MapController _mapController = MapController();
  late latlng.LatLng _currentCenter;
  double _currentZoom = 18.0;
  int _camAnimToken = 0;

  final _listController = ScrollController();
  static const double _focusZoom = 19.5;

  final ScrollController _pageScroll = ScrollController();

  MetricKey? _metricKey;

  @override
  void initState() {
    super.initState();
    items = _assignOrder(List.of(MonitoringMock.items));
    _currentCenter = _avgCenter(items);
    _currentZoom = 18.0;

    if (items.isNotEmpty) {
      selectedId = items.first.id;
      _metricKey = _defaultMetricFor(items.first);
    }
  }
  
  // *** เมธอดสำหรับจัดการเมื่อ Mark All As Read ถูกเรียก ***
  void _markAllNotifsAsRead() {
    setState(() {
      _unreadCount = 0; // เซ็ตให้เป็น 0 เพื่อซ่อน Dot Badge
    });
  }
  // ***************************************************

  List<MonitoringEntry> _assignOrder(List<MonitoringEntry> src) {
    int lightingNo = 1;
    int wirelessNo = 1;
    return src
        .map<MonitoringEntry>((e) {
          if (e.kind == MonitoringKind.lighting) {
            return e.copyWith(order: lightingNo++);
          } else {
            return e.copyWith(order: wirelessNo++);
          }
        })
        .toList(growable: false);
  }

  bool _isOnline(MonitoringEntry e) {
    if (e.kind == MonitoringKind.lighting) {
      return (e.data as LightingData).online;
    } else {
      return (e.data as WirelessData).online;
    }
  }

  MetricKey _defaultMetricFor(MonitoringEntry e) {
    return e.kind == MonitoringKind.lighting ? MetricKey.acV : MetricKey.dcV;
  }

  MonitoringEntry? get _current {
    if (items.isEmpty) return null;
    if (selectedId == null) return items.first;
    try {
      return items.firstWhere((e) => e.id == selectedId);
    } catch (_) {
      return items.first;
    }
  }

  void _selectEntry(MonitoringEntry e) {
    setState(() {
      selectedId = e.id;
      _metricKey = _defaultMetricFor(e);
    });
    _smoothFocusMapOn(e);
  }

  void _smoothFocusMapOn(MonitoringEntry e) {
    final target = latlng.LatLng(e.lat, e.lng);
    _animateMapTo(target, _focusZoom, const Duration(milliseconds: 420));
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
      return t < 0.5 ? 4 * t * t * t : 1 - (-2 * t + 2) * (-2 * t + 2) * (-2 * t + 2) / 2;
    }

    for (var i = 1; i <= steps; i++) {
      Future.delayed(per * i, () {
        if (token != _camAnimToken) return;
        final t = easeInOut(i / steps);
        final lat = start.latitude + (target.latitude - start.latitude) * t;
        final lng = start.longitude + (target.longitude - start.longitude) * t;
        final zoom = startZoom + (targetZoom - startZoom) * t;
        _mapController.move(latlng.LatLng(lat, lng), zoom);
        if (i == steps) {
          _currentCenter = latlng.LatLng(lat, lng);
          _currentZoom = zoom;
        }
      });
    }
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

    final byType = items.where((e) {
      switch (typeFilterEnum) {
        case TypeFilter.all:
          return true;
        case TypeFilter.lighting:
          return e.kind == MonitoringKind.lighting;
        case TypeFilter.wave:
          return e.kind == MonitoringKind.wirelessWave;
        case TypeFilter.sim:
          return e.kind == MonitoringKind.wirelessSim;
      }
    }).toList();

    final totalCount = byType.length;
    final onlineCount = byType.where(_isOnline).length;
    final offlineCount = totalCount - onlineCount;

    final filtered = byType.where((e) {
      switch (statusFilterEnum) {
        case StatusFilter.all:
          return true;
        case StatusFilter.online:
          return _isOnline(e);
        case StatusFilter.offline:
          return !_isOnline(e);
      }
    }).toList();

    final double mapHeight = isNarrow ? 200 : 220;
    final double listHeight = isNarrow ? 320 : 360;
    final double chartHeight = isNarrow ? 340 : 420;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'ตรวจสอบสถานะ',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        actions: [
          // Dot Badge Logic
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                IconButton(
                  tooltip: 'แจ้งเตือน',
                  icon: const Icon(Icons.notifications_active_outlined, size: 28, color: Colors.black),
                  onPressed: () {
                    setState(() {
                      _showNotificationCenter = !_showNotificationCenter;
                    });
                  },
                ),
                // *** Badge จะแสดงเมื่อ _unreadCount > 0 เท่านั้น ***
                if (_unreadCount > 0)
                  const Positioned( 
                    right: 8,
                    top: 8,
                    child: SizedBox(
                      width: 8, 
                      height: 8, 
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack( 
        children: [
          // 1. เนื้อหาหน้าจอหลัก (โค้ดเดิม)
          Scrollbar(
            controller: _pageScroll,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _pageScroll,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ... (ส่วน Map, List, Chart โค้ดเดิม)
                  if (isNarrow)
                    Column(
                      children: [
                        SizedBox(
                          height: mapHeight,
                          child: MapCard(
                            mapController: _mapController,
                            items: filtered,
                            center: _currentCenter,
                            border: border,
                            onMarkerTap: (e, list) {
                              setState(() {
                                selectedId = e.id;
                                _metricKey = _defaultMetricFor(e);
                              });
                              _smoothFocusMapOn(e);
                              _scrollToEntry(e, list);
                            },
                            isOnline: _isOnline,
                            selectedId: selectedId,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: listHeight,
                          child: MonitoringListPanel(
                            items: filtered,
                            selectedId: selectedId,
                            cardBg: cardBg,
                            border: border,
                            accent: accent,
                            textColor: textColor,
                            listController: _listController,
                            onToggleLighting: _toggleLighting,
                            onSelectEntry: _selectEntry,
                            typeFilter: typeFilterEnum,
                            onChangeTypeFilter: (v) => setState(() => typeFilterEnum = v),
                            statusFilter: statusFilterEnum,
                            onChangeStatusFilter: (v) => setState(() => statusFilterEnum = v),
                            totalCount: totalCount,
                            onlineCount: onlineCount,
                            offlineCount: offlineCount,
                          ),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      height: mapHeight + 12 + listHeight,
                      child: Row(
                        children: [
                          Expanded(
                            child: MapCard(
                              mapController: _mapController,
                              items: filtered,
                              center: _currentCenter,
                              border: border,
                              onMarkerTap: (e, list) {
                                setState(() {
                                  selectedId = e.id;
                                  _metricKey = _defaultMetricFor(e);
                                });
                                _smoothFocusMapOn(e);
                                _scrollToEntry(e, list);
                              },
                              isOnline: _isOnline,
                              selectedId: selectedId,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: MonitoringListPanel(
                              items: filtered,
                              selectedId: selectedId,
                              cardBg: cardBg,
                              border: border,
                              accent: accent,
                              textColor: textColor,
                              listController: _listController,
                              onToggleLighting: _toggleLighting,
                              onSelectEntry: _selectEntry,
                              typeFilter: typeFilterEnum,
                              onChangeTypeFilter: (v) => setState(() => typeFilterEnum = v),
                              statusFilter: statusFilterEnum,
                              onChangeStatusFilter: (v) => setState(() => statusFilterEnum = v),
                              totalCount: totalCount,
                              onlineCount: onlineCount,
                              offlineCount: offlineCount,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: SizedBox(
                          height: chartHeight,
                          child: MetricLineChart(
                            items: filtered,
                            selectedId: selectedId,
                            metric: _metricKey ??
                                ((_current?.kind == MonitoringKind.lighting)
                                    ? MetricKey.acV
                                    : MetricKey.dcV),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 4,
                        child: SizedBox(
                          height: chartHeight,
                          child: MiniStats(
                            current: _current,
                            activeMetric: _metricKey ??
                                ((_current?.kind == MonitoringKind.lighting)
                                    ? MetricKey.acV
                                    : MetricKey.dcV),
                            onSelectMetric: (m) => setState(() => _metricKey = m),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // 2. กล่องแจ้งเตือน (Notification Center)
          if (_showNotificationCenter)
            Positioned(
              top: 0, 
              right: 16, 
              child: NotificationCenter(
                onClose: () => setState(() => _showNotificationCenter = false),
                onMarkAllAsRead: _markAllNotifsAsRead, // *** ส่งฟังก์ชันนี้ไปให้ NotificationCenter ***
              ),
            ),
        ],
      ),
    );
  }
  
  // (โค้ดเมธอดอื่นๆ เดิม)
  void _toggleLighting(MonitoringEntry entry) {
    if (entry.kind != MonitoringKind.lighting) return;
    setState(() {
      final d = (entry.data as LightingData);
      final idx = items.indexWhere((x) => x.id == entry.id);
      if (idx == -1) return;

      items[idx] = entry.copyWith(
        data: LightingData(
          acV: d.acV,
          acA: d.acA,
          acW: d.acW,
          acHz: d.acHz,
          acKWh: d.acKWh,
          online: d.online,
          statusLighting: !d.statusLighting,
        ),
        updatedAt: DateTime.now(),
      );
    });
  }

  latlng.LatLng _avgCenter(List<MonitoringEntry> entries) {
    if (entries.isEmpty) return latlng.LatLng(13.6580, 100.6608);
    final lat =
        entries.map((e) => e.lat).reduce((a, b) => a + b) / entries.length;
    final lng =
        entries.map((e) => e.lng).reduce((a, b) => a + b) / entries.length;
    return latlng.LatLng(lat, lng);
  }

  void _scrollToEntry(MonitoringEntry target, List<MonitoringEntry> list) {
    final idx = list.indexWhere((e) => e.id == target.id);
    if (idx == -1) return;
    _listController.animateTo(
      (idx * 132).toDouble(),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }
}