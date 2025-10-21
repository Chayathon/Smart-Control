import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;

import 'monitoring_mock.dart';
import 'parts/map_card.dart';
import 'parts/list_card.dart'; // enums TypeFilter/StatusFilter อยู่ในไฟล์นี้

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

  String? selectedId;

  final MapController _mapController = MapController();
  latlng.LatLng _currentCenter = latlng.LatLng(13.6580, 100.6608);
  double _currentZoom = 18.0;
  int _camAnimToken = 0;

  final _listController = ScrollController();
  static const double _focusZoom = 19.5;

  @override
  void initState() {
    super.initState();
    items = _assignOrder(List.of(monitoringMoukup));
    _currentCenter = _avgCenter(items);
    _currentZoom = 18.0;
  }

  List<MonitoringEntry> _assignOrder(List<MonitoringEntry> src) {
    int lightingNo = 1;
    int wirelessNo = 1;
    return src.map((e) {
      if (e.kind == MonitoringKind.lighting) {
        return e.copyWith(order: lightingNo++);
      } else {
        return e.copyWith(order: wirelessNo++);
      }
    }).toList();
  }

  bool _isOnline(MonitoringEntry e) {
    if (e.kind == MonitoringKind.lighting) {
      return (e.data as LightingData).online;
    } else {
      return (e.data as WirelessData).online;
    }
  }

  void _selectEntry(MonitoringEntry e) {
    setState(() => selectedId = e.id);
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

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0.5,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          'ตรวจสอบสถานะ (Monitoring)',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'แจ้งเตือน',
            icon: Icon(Icons.notifications_active_outlined,
                size: 28, color: Colors.amber[700]), // << ใหญ่ขึ้น
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ตั้งค่าการแจ้งเตือน (mock)')),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: LayoutBuilder(
          builder: (context, c) {
            final isNarrow = c.maxWidth < 900;

            if (!isNarrow) {
              return Column(
                children: [
                  const SizedBox(height: 4),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: MapCard(
                            mapController: _mapController,
                            items: filtered,
                            center: _currentCenter,
                            border: border,
                            onMarkerTap: (e, list) {
                              setState(() => selectedId = e.id);
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
                ],
              );
            }

            return Column(
              children: [
                SizedBox(
                  height: 320,
                  child: MapCard(
                    mapController: _mapController,
                    items: filtered,
                    center: _currentCenter,
                    border: border,
                    onMarkerTap: (e, list) {
                      setState(() => selectedId = e.id);
                      _smoothFocusMapOn(e);
                      _scrollToEntry(e, list);
                    },
                    isOnline: _isOnline,
                    selectedId: selectedId,
                  ),
                ),
                const SizedBox(height: 12),
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
            );
          },
        ),
      ),
    );
  }

  void _toggleLighting(MonitoringEntry entry) {
    if (entry.kind != MonitoringKind.lighting) return;
    setState(() {
      final d = (entry.data as LightingData);
      final idx = items.indexWhere((x) => x.id == entry.id);
      if (idx == -1) return;

      items[idx] = entry.copyWith(
        data: LightingData(
          acV: d.acV, acA: d.acA, acW: d.acW, acHz: d.acHz, acKWh: d.acKWh,
          online: d.online, statusLighting: !d.statusLighting,
        ),
        updatedAt: DateTime.now(),
      );
    });
  }

  latlng.LatLng _avgCenter(List<MonitoringEntry> entries) {
    if (entries.isEmpty) return latlng.LatLng(13.6580, 100.6608);
    final lat = entries.map((e) => e.lat).reduce((a, b) => a + b) / entries.length;
    final lng = entries.map((e) => e.lng).reduce((a, b) => a + b) / entries.length;
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
