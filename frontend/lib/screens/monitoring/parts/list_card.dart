// lib/screens/monitoring/parts/mini_stats.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

<<<<<<< HEAD
/// ความสูงการ์ดทุกใบ ให้เท่ากันหมด
const double _kTileHeight = 110;

/// metric key ที่ใช้กับค่าจริงจาก backend (เหลือแค่ 4 ตัว)
/// oat = On Air Target (ไม่ใช่อุณหภูมิ)
enum MetricKey {
  dcV,
  dcA,
  dcW,
  oat,
}

String metricLabel(MetricKey k) {
  switch (k) {
    case MetricKey.dcV:
      return 'DC Voltage';
    case MetricKey.dcA:
      return 'DC Current';
    case MetricKey.dcW:
      return 'DC Power';
    case MetricKey.oat:
      return 'On Air Target';
  }
}

String unitOf(MetricKey k) {
  switch (k) {
    case MetricKey.dcV:
      return 'V';
    case MetricKey.dcA:
      return 'A';
    case MetricKey.dcW:
      return 'W';
    case MetricKey.oat:
      // OAT = On Air Target → ไม่มีหน่วย
      return '';
=======
/// ===== ตัวกรองและชนิดอุปกรณ์ =====
enum TypeFilter { all, lighting, wave, sim }
enum StatusFilter { all, online, offline }
enum MonitoringKind { lighting, wirelessWave, wirelessSim }

typedef Json = Map<String, dynamic>;

/// ===== แผงลิสต์ + ส่วนตัวกรอง (ค่าจริง) =====
class MonitoringListPanel extends StatelessWidget {
  final List<Json> items; // ใช้ Json (ค่าจริง)
  final String? selectedId; // devEui / deviceId ที่เลือก
  final Color cardBg, border, accent, textColor;
  final ScrollController listController;

  final ValueChanged<Json> onSelectEntry;

  /// ยังรับไว้เพื่อไม่ให้กระทบโค้ดเดิม แต่จะไม่ถูกใช้งานแล้ว
  final void Function(Json row, int nextLighting) onToggleLighting;

  final TypeFilter typeFilter;
  final ValueChanged<TypeFilter> onChangeTypeFilter;

  final StatusFilter statusFilter;
  final ValueChanged<StatusFilter> onChangeStatusFilter;

  final int totalCount, onlineCount, offlineCount;

  /// helper จากหน้าหลัก
  final MonitoringKind Function(Json row) kindOf;
  final bool Function(Json row) onlineOf;

  const MonitoringListPanel({
    super.key,
    required this.items,
    required this.selectedId,
    required this.cardBg,
    required this.border,
    required this.accent,
    required this.textColor,
    required this.listController,
    required this.onSelectEntry,
    required this.onToggleLighting,
    required this.typeFilter,
    required this.onChangeTypeFilter,
    required this.statusFilter,
    required this.onChangeStatusFilter,
    required this.totalCount,
    required this.onlineCount,
    required this.offlineCount,
    required this.kindOf,
    required this.onlineOf,
  });

  /// ตอนนี้ใช้ระบบเดียว = ระบบไร้สาย (ซิม)
  String _systemTitle(MonitoringKind k) {
    return 'ระบบไร้สาย (ซิม)';
  }

  /// ====== ดึง ID หลักของโหนด ======
  /// ลำดับ:
  /// 1) meta.deviceId
  /// 2) meta.devEui
  /// 3) meta.no
  /// 4) row.devEui
  String? _idOf(Json row) {
    final meta = row['meta'];
    if (meta is Map) {
      final deviceId = meta['deviceId'];
      if (deviceId is String && deviceId.isNotEmpty) {
        return deviceId;
      }

      final devEui = meta['devEui'];
      if (devEui is String && devEui.isNotEmpty) {
        return devEui;
      }

      final no = meta['no'];
      if (no != null) {
        return no.toString();
      }
    }

    final devEui = row['devEui'];
    if (devEui is String && devEui.isNotEmpty) {
      return devEui;
    }

    return null;
  }

  /// ====== ดึงชื่อที่ใช้แสดงในลิสต์ ======
  /// ลำดับการเลือกชื่อ:
  /// 1) row.name
  /// 2) meta.name
  /// 3) meta.no   → "NODE{no}"
  /// 4) _idOf(row)
  /// 5) '-'
  String _nameOf(Json row) {
    final name = (row['name'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;

    final meta = row['meta'];
    if (meta is Map) {
      final metaName = (meta['name'] ?? '').toString().trim();
      if (metaName.isNotEmpty) return metaName;

      final no = meta['no'];
      if (no != null) {
        final noStr = no.toString();
        return 'NODE$noStr';
      }
    }

    return _idOf(row) ?? '-';
  }

  DateTime? _toDate(dynamic v) {
    try {
      if (v == null) return null;
      if (v is DateTime) return v.toLocal();
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v).toLocal();
      if (v is String && v.isNotEmpty) return DateTime.parse(v).toLocal();
    } catch (_) {}
    return null;
  }

  String _hhmmss(DateTime dt) {
    final t = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // ===== แถบตัวกรอง (ตัดตัวกรองระบบออก เหลือเฉพาะสถานะ) =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // ไม่ใช้ TypeDropdown แล้ว เหลือเฉพาะปุ่มสถานะ
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      primary: false,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Status3DButton(
                            type: StatusFilter.all,
                            label: 'All ($totalCount)',
                            selected: statusFilter == StatusFilter.all,
                            onTap: () =>
                                onChangeStatusFilter(StatusFilter.all),
                          ),
                          const SizedBox(width: 8),
                          Status3DButton(
                            type: StatusFilter.online,
                            label: 'Online ($onlineCount)',
                            selected: statusFilter == StatusFilter.online,
                            onTap: () =>
                                onChangeStatusFilter(StatusFilter.online),
                          ),
                          const SizedBox(width: 8),
                          Status3DButton(
                            type: StatusFilter.offline,
                            label: 'Offline ($offlineCount)',
                            selected: statusFilter == StatusFilter.offline,
                            onTap: () =>
                                onChangeStatusFilter(StatusFilter.offline),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ===== ลิสต์อุปกรณ์ =====
            Expanded(
              child: Scrollbar(
                controller: listController,
                thumbVisibility: true,
                child: ListView.separated(
                  controller: listController,
                  primary: false,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final row = items[i];
                    final id = _idOf(row);
                    final isSelected =
                        selectedId != null && id == selectedId;

                    final wrap = (Widget child) => GestureDetector(
                          onTap: () => onSelectEntry(row),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            curve: Curves.easeOut,
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: isSelected
                                  ? Colors.blue[50]
                                  : Colors.transparent,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.blue
                                    : Colors.transparent,
                                width: isSelected ? 1.2 : 0.0,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color:
                                            Colors.blue.withOpacity(0.15),
                                        blurRadius: 12,
                                        spreadRadius: 1,
                                        offset: const Offset(0, 4),
                                      )
                                    ]
                                  : [],
                            ),
                            child: child,
                          ),
                        );

                    final k = kindOf(row);
                    final systemTitle = _systemTitle(k);
                    final order = i + 1;

                    // ตอนนี้ใช้แต่ Wireless Tile จริงทั้งหมด
                    return wrap(
                      _WirelessTileReal(
                        row: row,
                        kind: k,
                        order: order,
                        deviceTitle: _nameOf(row),
                        systemTitle: systemTitle,
                        accent: Colors.black87,
                        textColor: Colors.black87,
                        border: border,
                        isOnline: onlineOf(row),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===== ดรอปดาวน์ (ปุ่ม 3D) — ยังเก็บ class ไว้แต่ไม่ได้ใช้งานใน UI แล้ว =====
class TypeDropdown extends StatelessWidget {
  final TypeFilter value;
  final ValueChanged<TypeFilter> onChanged;
  const TypeDropdown({super.key, required this.value, required this.onChanged});

  String _labelOf(TypeFilter v) {
    switch (v) {
      case TypeFilter.all:
        return 'ทั้งหมด';
      case TypeFilter.lighting:
        return 'ระบบไฟส่องสว่าง';
      case TypeFilter.wave:
        return 'ระบบไร้สายแบบคลื่น';
      case TypeFilter.sim:
        return 'ระบบไร้สายแบบซิม';
    }
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
  }
}

<<<<<<< HEAD
Color metricColor(MetricKey k) {
  switch (k) {
    case MetricKey.dcV:
      return const Color(0xFF06B6D4); // ฟ้าอมเขียว
    case MetricKey.dcA:
      return const Color(0xFF14B8A6); // เขียวอมฟ้า
    case MetricKey.dcW:
      return const Color(0xFFEF4444); // แดง
    case MetricKey.oat:
      return const Color(0xFFFB923C); // OAT โทนส้มอุ่น ๆ
  }
}

/// Widget MiniStats ใช้ค่าจริงจาก current (row จาก backend)
class MiniStats extends StatelessWidget {
  /// row ปัจจุบันจาก backend (อาจเป็น null ถ้ายังไม่เลือก)
  final Map<String, dynamic>? current;

  /// metric ที่เลือกอยู่ (เอาไว้เน้น tile ว่า active)
  final MetricKey activeMetric;

  /// เปลี่ยน metric (ให้ parent setState)
  final void Function(MetricKey) onSelectMetric;

  const MiniStats({
    super.key,
    required this.current,
    required this.activeMetric,
    required this.onSelectMetric,
  });

  static const Color kBorderNormal = Color(0x1A000000);
  static const Color kBorderActive = Color(0x9900BBF9);

  @override
  Widget build(BuildContext context) {
    final row = current;
    if (row == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: const Text(
          'เลือกอุปกรณ์จากลิสต์ทางซ้ายเพื่อดูรายละเอียด',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54),
=======
  List<PopupMenuEntry<TypeFilter>> _buildItems(double w) {
    const innerLeftText = 10.0;
    const innerRightText = 8.0;
    const v = 10.0;
    const edge = 8.0;

    PopupMenuEntry<TypeFilter> _item(TypeFilter val, String text,
        {double topExtra = 0, double bottomExtra = 0}) {
      return PopupMenuItem(
        value: val,
        padding: EdgeInsets.zero,
        child: SizedBox(
          width: w,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              innerLeftText,
              v + topExtra,
              innerRightText,
              v + bottomExtra,
            ),
            child: Text(text, overflow: TextOverflow.ellipsis),
          ),
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
        ),
      );
    }

    final online = _onlineOf(row);

<<<<<<< HEAD
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 12.0;
                final specs = _buildTiles(
                  row,
                  online: online,
                );

                if (specs.isEmpty) {
                  return const Center(
                    child: Text(
                      'ไม่มีข้อมูลค่าทางไฟฟ้าสำหรับอุปกรณ์นี้',
                      style: TextStyle(color: Colors.black45),
                    ),
                  );
                }

                // 2 คอลัมน์
                final colW = (constraints.maxWidth - spacing) / 2;

                final children = specs.map<Widget>((t) {
                  switch (t.kind) {
                    case _TileKind.spacer:
                      return _SpacerTile(width: colW);

                    case _TileKind.status:
                      return _StatusTile(
                        width: colW,
                        online: t.boolValue ?? false,
                        deviceName: t.title ?? '-',
                      );

                    case _TileKind.onAirTarget:
                      return _OnAirTargetTile(
                        width: colW,
                        value: t.boolValue ?? false,
                      );

                    case _TileKind.metric:
                      final m = t.metric!;
                      final value = t.value!;
                      final unit = t.unit ?? unitOf(m);
                      final color = metricColor(m);
                      final isActive = (m == activeMetric);

                      final List<double> lineValues =
                          value.isFinite ? [value, value, value] : const <double>[];

                      return _MetricTile(
                        width: colW,
                        title: t.title ?? metricLabel(m),
                        value: value,
                        unit: unit,
                        pathValues: lineValues,
                        color: color,
                        active: isActive,
                        onTap: () => onSelectMetric(m),
                      );
                  }
                }).toList();

                return SingleChildScrollView(
                  child: Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: children,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ===================== tile builder =====================

  List<_TileSpec> _buildTiles(
    Map<String, dynamic> row, {
    required bool online,
  }) {
    final tiles = <_TileSpec>[];

    final deviceName = _nameOf(row);

    // การ์ดแรก: สถานะอุปกรณ์ + ชื่ออุปกรณ์ + online/offline
    tiles.add(
      _TileSpec.status(
        online: online,
        deviceName: deviceName,
      ),
    );

    // Metric ที่เหลือจริงจาก backend: DC
    _maybeAddMetricTile(row, tiles, 'DC Voltage', MetricKey.dcV);
    _maybeAddMetricTile(row, tiles, 'DC Current', MetricKey.dcA);
    _maybeAddMetricTile(row, tiles, 'DC Power', MetricKey.dcW);
    // **ลบการ์ด On Air Target (ตัวเลข) ออก ตาม requirement**
    // _maybeAddMetricTile(row, tiles, 'On Air Target', MetricKey.oat);

    // สถานะ OnAir (ใช้ oat + เช็ค online)
    final onAir = _onAirTarget(row);
    tiles.add(_TileSpec.onAirTarget(onAir));

    // ให้เป็นจำนวนคู่ (2 คอลัมน์)
    if (tiles.length.isOdd) {
      tiles.add(_TileSpec.spacer());
    }

    return tiles;
  }

  void _maybeAddMetricTile(
    Map<String, dynamic> row,
    List<_TileSpec> tiles,
    String title,
    MetricKey key,
  ) {
    final v = _metricValue(row, key);
    if (v == null) return;
    tiles.add(
      _TileSpec.metric(
        title: title,
        unit: unitOf(key),
        value: v,
        metric: key,
      ),
    );
  }

  // ===================== helpers =====================

  String _nameOf(Map<String, dynamic> row) {
    // 1) ถ้ามี name ให้ใช้ก่อน
    final name = (row['name'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;

    // 2) ถ้าไม่มี name ให้ใช้เลข no แล้วขึ้นต้นด้วย "Node"
    final meta = row['meta'];
    if (meta is Map) {
      final noMeta = meta['no'];
      if (noMeta is int) return 'Node$noMeta';
      if (noMeta is String && noMeta.isNotEmpty) return 'Node$noMeta';
    }

    final rootNo = row['no'];
    if (rootNo is int) return 'Node$rootNo';
    if (rootNo is String && rootNo.isNotEmpty) return 'Node$rootNo';

    // 3) สุดท้าย fallback เป็น devEui
    final devEui =
        (row['devEui'] ?? row['meta']?['devEui'] ?? '').toString();
    if (devEui.isNotEmpty) return devEui;

    return '-';
  }

  bool _onlineOf(Map<String, dynamic> row) {
    final tsRaw = row['timestamp'];

    DateTime? ts;
    if (tsRaw is DateTime) {
      ts = tsRaw.toUtc();
    } else if (tsRaw is String && tsRaw.isNotEmpty) {
      ts = DateTime.tryParse(tsRaw)?.toUtc();
    } else if (tsRaw is int) {
      // เผื่อเก็บเป็น millisecondsSinceEpoch
      ts = DateTime.fromMillisecondsSinceEpoch(tsRaw, isUtc: true);
    }

    if (ts == null) return false;

    final diff = DateTime.now().toUtc().difference(ts);
    return diff.inSeconds <= 5;
  }

  /// แปลงค่า oat เป็นสถานะ On Air Target (กำลังประกาศ / ไม่ได้ประกาศ)
  bool _onAirTarget(Map<String, dynamic> row) {
    // ถ้าอุปกรณ์ Offline ให้ถือว่า "ไม่ได้ประกาศ" เสมอ
    if (!_onlineOf(row)) return false;

    final raw = row['oat']; // ใช้เฉพาะ oat ตัวเดียว

    if (raw is bool) return raw;
    if (raw is num) return raw != 0;

    if (raw is String && raw.trim().isNotEmpty) {
      final s = raw.trim().toLowerCase();

      if (s == 'true' || s == 'on' || s == 'yes') return true;
      if (s == 'false' || s == 'off' || s == 'no') return false;

      final n = double.tryParse(s);
      if (n != null) return n != 0;
    }

    return false;
  }

  int _decimalPlaces(MetricKey k) {
    switch (k) {
      case MetricKey.oat:
        // OAT เป็นค่า target ธรรมดา (ไม่ใช่ °C) แต่ให้แสดงทศนิยม 2 ตำแหน่งเหมือนเดิม
        return 2;
      case MetricKey.dcV:
      case MetricKey.dcA:
      case MetricKey.dcW:
        return 2;
    }
  }

  double? _metricValue(Map<String, dynamic> row, MetricKey k) {
    dynamic raw;
    switch (k) {
      case MetricKey.dcV:
        raw = row['dcV'];
        break;
      case MetricKey.dcA:
        raw = row['dcA'];
        break;
      case MetricKey.dcW:
        raw = row['dcW'];
        break;
      case MetricKey.oat:
        raw = row['oat'];

        // ถ้า Offline ให้บังคับแสดงเป็น 0 ทันที
        if (!_onlineOf(row)) {
          raw = 0;
        }
        break;
    }

    final v = _toDouble(raw);
    if (v == null) return null;
    final dp = _decimalPlaces(k);
    final factor = math.pow(10, dp).toDouble();
    return (v * factor).roundToDouble() / factor;
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is bool) return v ? 1 : 0;
    if (v is num) return v.toInt();
    if (v is String && v.isNotEmpty) return int.tryParse(v);
    return null;
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    if (v is String && v.isNotEmpty) return double.tryParse(v);
    return null;
  }
}

// ===================== Tile model =====================

enum _TileKind {
  metric,
  status,
  onAirTarget,
  spacer,
}

class _TileSpec {
  final _TileKind kind;
  final String? title;
  final String? unit;
  final double? value;
  final bool? boolValue;
  final MetricKey? metric;

  _TileSpec._(
    this.kind, {
    this.title,
    this.unit,
    this.value,
    this.boolValue,
    this.metric,
  });

  factory _TileSpec.metric({
    required String title,
    required String unit,
    required double value,
    required MetricKey metric,
  }) =>
      _TileSpec._(
        _TileKind.metric,
        title: title,
        unit: unit,
        value: value,
        metric: metric,
      );

  factory _TileSpec.status({
    required bool online,
    required String deviceName,
  }) =>
      _TileSpec._(
        _TileKind.status,
        boolValue: online,
        title: deviceName,
      );

  factory _TileSpec.onAirTarget(bool v) =>
      _TileSpec._(_TileKind.onAirTarget, boolValue: v);

  factory _TileSpec.spacer() => _TileSpec._(_TileKind.spacer);
}

// ===================== Metric Tile =====================

class _MetricTile extends StatelessWidget {
  final double width;
  final String title;
  final double value;
  final String unit;
  final List<double> pathValues;
  final bool active;
  final VoidCallback? onTap;
  final Color color;

  const _MetricTile({
    super.key,
    required this.width,
    required this.title,
    required this.value,
    required this.unit,
    required this.pathValues,
    required this.active,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        active ? MiniStats.kBorderActive : MiniStats.kBorderNormal;
    const bgColor = Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: width,
        height: _kTileHeight,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _fmt(value),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    if (unit.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3.0),
                        child: Text(
                          unit,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 34,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: CustomPaint(
                  painter: _SparkPainter(
                    pathValues,
                    lineColor: color,
                    isActive: active,
                  ),
                ),
              ),
            ),
          ],
        ),
=======
  @override
  Widget build(BuildContext context) {
    return _TypeDropdownButton3D(
      label: _labelOf(value),
      onTap: (boxContext) async {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          final box = boxContext.findRenderObject() as RenderBox;
          final overlay =
              Overlay.of(boxContext).context.findRenderObject() as RenderBox;
          final offset = box.localToGlobal(Offset.zero, ancestor: overlay);

          final buttonW = box.size.width;
          final menuW = buttonW;
          final left = offset.dx;
          final top = offset.dy + box.size.height + 4.0;
          final right = overlay.size.width - left - menuW;

          final selected = await showMenu<TypeFilter>(
            context: boxContext,
            color: Colors.white,
            elevation: 8,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            position: RelativeRect.fromLTRB(
                left, top, right, overlay.size.height - top),
            items: _buildItems(menuW),
          );

          if (selected != null) onChanged(selected);
        });
      },
    );
  }
}

/// ปุ่ม 3D ของ dropdown
class _TypeDropdownButton3D extends StatelessWidget {
  final String label;
  final void Function(BuildContext buttonContext) onTap;

  const _TypeDropdownButton3D({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (buttonContext) {
        return InkWell(
          onTap: () => onTap(buttonContext),
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 150,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    offset: Offset(3, 5),
                    blurRadius: 10,
                  ),
                  BoxShadow(
                    color: Color(0x66FFFFFF),
                    offset: Offset(-3, -3),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Flexible(
                    fit: FlexFit.loose,
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.expand_more, size: 18),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// ===== ปุ่มสถานะ 3D =====
class Status3DButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final StatusFilter type; // all / online / offline

  const Status3DButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    Color baseSelected;
    switch (type) {
      case StatusFilter.online:
        baseSelected = Colors.green[600]!;
        break;
      case StatusFilter.offline:
        baseSelected = Colors.red[600]!;
        break;
      case StatusFilter.all:
      default:
        baseSelected = const Color(0xFF48CAE4);
        break;
    }

    final bg = selected ? baseSelected : Colors.white;
    final txt = selected ? Colors.white : Colors.black87;
    final border = selected
        ? baseSelected.withOpacity(.95)
        : Colors.grey[300]!;
    final shadow = selected
        ? <BoxShadow>[
            BoxShadow(
              color: baseSelected.withOpacity(.35),
              offset: const Offset(2, 3),
              blurRadius: 10,
            ),
            BoxShadow(
              color: Colors.white.withOpacity(.55),
              offset: const Offset(-2, -2),
              blurRadius: 6,
            ),
          ]
        : const <BoxShadow>[
            BoxShadow(
              color: Color(0x33000000),
              offset: Offset(3, 5),
              blurRadius: 10,
            ),
            BoxShadow(
              color: Color(0xF2FFFFFF),
              offset: Offset(-3, -3),
              blurRadius: 10,
            ),
          ];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
          boxShadow: shadow,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: txt,
          ),
        ),
      ),
    );
  }
}

/// ======================= Wireless Tile (ค่าจริง) =======================
class _WirelessTileReal extends StatelessWidget {
  final Json row;
  final MonitoringKind kind;
  final int order; // เลขลำดับ
  final String deviceTitle; // บรรทัดบนสุด
  final String systemTitle; // ต่อท้ายชื่ออุปกรณ์
  final Color accent, textColor, border;
  final bool isOnline;

  const _WirelessTileReal({
    required this.row,
    required this.kind,
    required this.order,
    required this.deviceTitle,
    required this.systemTitle,
    required this.accent,
    required this.textColor,
    required this.border,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    final lat = row['lat'];
    final lng = row['lng'];
    final ts = row['timestamp'];
    final t = _toDate(ts);
    final timeLabel = t != null ? _hhmmss(t) : '-';

    // DC metrics จากฐานข้อมูลปัจจุบัน
    final dcV = row['dcV'];
    final dcA = row['dcA'];
    final dcW = row['dcW'];
    final oat = row['oat'];

    const vGapBetweenTitleAndBelow = 8.0;

    final titleTextStyle = const TextStyle(
      fontWeight: FontWeight.w900,
      fontSize: 20,
      letterSpacing: .2,
      color: Colors.black87,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // (เลข.) ชื่ออุปกรณ์ | ป้ายระบบ | Online
          Row(
            children: [
              Text('$order.', style: titleTextStyle),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  deviceTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: titleTextStyle,
                ),
              ),
              const SizedBox(width: 8),
              _SystemPill.familyWirelessOrLighting(
                kind: kind,
                text: systemTitle,
              ),
              const SizedBox(width: 8),
              OnlineGlowBadge(isOnline: isOnline),
            ],
          ),

          const SizedBox(height: vGapBetweenTitleAndBelow),

          // Meta Row
          _MetaRowLeftLatLngRightTime(
            lat: lat,
            lng: lng,
            timeLabel: timeLabel,
          ),

          const SizedBox(height: vGapBetweenTitleAndBelow),

          // Metrics — ✅ เอาเฉพาะ DC + OAT (ตัด battery / RSSI / SNR ออก)
          MetricList(
            items: [
              MetricItem('DC Voltage', _fmtNum(dcV, suffix: ' V')),
              MetricItem('DC Current', _fmtNum(dcA, suffix: ' A')),
              MetricItem('DC Power', _fmtNum(dcW, suffix: ' W')),
              MetricItem('OAT', _fmtNum(oat)), // จะระบุหน่วยเพิ่มก็ได้ เช่น ' °C'
            ],
          ),
        ],
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
      ),
    );
  }

<<<<<<< HEAD
  String _fmt(double n) {
    if (!n.isFinite) return '-';
    final abs = n.abs();
    if (abs >= 100) return n.toStringAsFixed(1);
    return n.toStringAsFixed(2);
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> values;
  final Color lineColor;
  final bool isActive;

  _SparkPainter(
    this.values, {
    required this.lineColor,
    this.isActive = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || values.length < 2) return;

    final minY = values.reduce(math.min);
    final maxY = values.reduce(math.max);
    final range = (maxY - minY).abs() < 0.0001 ? 1 : (maxY - minY);

    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final y =
          size.height - ((values[i] - minY) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = isActive ? 2.2 : 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.isActive != isActive;
  }
}

class _SpacerTile extends StatelessWidget {
  final double width;
  const _SpacerTile({required this.width});

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: width, height: 0);
}

// ------------------- Status Tile -------------------

class _StatusTile extends StatelessWidget {
  final double width;
  final bool online;
  final String deviceName;

  const _StatusTile({
    super.key,
    required this.width,
    required this.online,
    required this.deviceName,
=======
  String _fmtNum(dynamic v, {String suffix = ''}) {
    if (v == null) return '-';
    if (v is num) {
      final isInt = v is int || v == v.roundToDouble();
      return isInt
          ? '${v.toString()}$suffix'
          : '${v.toStringAsFixed(2)}$suffix';
    }
    return '$v$suffix';
  }

  DateTime? _toDate(dynamic v) {
    try {
      if (v == null) return null;
      if (v is DateTime) return v.toLocal();
      if (v is int) {
        return DateTime.fromMillisecondsSinceEpoch(v).toLocal();
      }
      if (v is String && v.isNotEmpty) {
        return DateTime.parse(v).toLocal();
      }
    } catch (_) {}
    return null;
  }

  String _hhmmss(DateTime dt) {
    final t = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}

/// ===== แถว Meta: (ซ้าย) Lat/Lng | (ขวา) เวลาอัปเดต =====
class _MetaRowLeftLatLngRightTime extends StatelessWidget {
  final dynamic lat;
  final dynamic lng;
  final String timeLabel;

  const _MetaRowLeftLatLngRightTime({
    required this.lat,
    required this.lng,
    required this.timeLabel,
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
  });

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    const bgColor = Colors.white;
    const borderColor = MiniStats.kBorderNormal;

    final statusText = online ? 'ออนไลน์' : 'ออฟไลน์';
    final statusColor = online ? Colors.green : Colors.red;
    final circleColor = statusColor;

    return Container(
      width: width,
      height: _kTileHeight,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'สถานะอุปกรณ์',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ชื่ออุปกรณ์ + สถานะข้อความ
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deviceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: circleColor.withOpacity(0.45),
                      blurRadius: 14,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.power_settings_new,
                  color: Colors.white,
                  size: 25,
                ),
              ),
            ],
=======
    final metaStyle = TextStyle(
      fontSize: 12,
      color: Colors.grey[800],
      fontWeight: FontWeight.w600,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // LEFT: Lat/Lng
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.place, size: 16, color: Colors.red[600]),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  (lat is num && lng is num)
                      ? 'Lat ${lat.toStringAsFixed(6)}, Lng ${lng.toStringAsFixed(6)}'
                      : 'ตำแหน่ง -',
                  style: metaStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        // RIGHT: Updated time
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule, size: 16, color: Colors.blue[600]),
            const SizedBox(width: 6),
            Text(
              timeLabel != '-' ? 'อัปเดต $timeLabel' : 'อัปเดต -',
              style: metaStyle,
            ),
          ],
        ),
      ],
    );
  }
}

/// ===== ป้ายชื่อระบบแบบ “มีไอคอนนำหน้า” =====
class _SystemPill extends StatelessWidget {
  final String text;
  final Gradient gradient;
  final IconData icon;
  const _SystemPill({
    required this.text,
    required this.gradient,
    required this.icon,
  });

  factory _SystemPill.familyWirelessOrLighting({
    required MonitoringKind kind,
    required String text,
  }) {
    switch (kind) {
      case MonitoringKind.lighting:
        return _SystemPill(
          text: text,
          icon: Icons.light_mode_outlined,
          gradient: const LinearGradient(
            colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        );
      case MonitoringKind.wirelessWave:
        return _SystemPill(
          text: text,
          icon: Icons.wifi_tethering,
          gradient: const LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        );
      case MonitoringKind.wirelessSim:
        return _SystemPill(
          text: text,
          icon: Icons.sim_card,
          gradient: const LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: .2,
            ),
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
          ),
        ],
      ),
    );
  }
}

<<<<<<< HEAD
// ------------------- _OnAirTargetTile -------------------

class _OnAirTargetTile extends StatelessWidget {
  final double width;
  final bool value;

  const _OnAirTargetTile({
    super.key,
    required this.width,
    required this.value,
  });
=======
/// ===== แบดจ์ Online/Offline =====
class OnlineGlowBadge extends StatelessWidget {
  final bool isOnline;
  const OnlineGlowBadge({super.key, required this.isOnline});
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c

  @override
  Widget build(BuildContext context) {
    final Color circleColor = value
        ? const Color(0xFF48CAE4) // กำลังประกาศ = ฟ้า
        : Colors.grey.shade400;   // ไม่ได้ประกาศ = เทา

    final String statusText =
        value ? 'กำลังประกาศ' : 'ไม่ได้ประกาศ';

    const borderColor = MiniStats.kBorderNormal;
    const bgColor = Colors.white;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {}, // แสดงสถานะอย่างเดียว
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: width,
          height: _kTileHeight,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'สถานะ On Air Target',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    statusText,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: circleColor,
                      shape: BoxShape.circle,
                      boxShadow: value
                          ? [
                              BoxShadow(
                                color: circleColor.withOpacity(0.45),
                                blurRadius: 14,
                                spreadRadius: 3,
                              ),
                            ]
                          : [],
                    ),
                    child: const Icon(
                      Icons.volume_up,
                      color: Colors.white,
                      size: 25,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
<<<<<<< HEAD
=======

class MetricList extends StatelessWidget {
  final List<MetricItem> items;

  /// callback สำหรับ tap ดวงไฟ Lighting (ตอนนี้ไม่ใช้แล้ว)
  final void Function(bool currentOn)? onToggleLighting;

  const MetricList({
    super.key,
    required this.items,
    this.onToggleLighting,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (m) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      m.label,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (m.isLighting && m.lightingOn != null)
                    _LightingStatusIcon(
                      isOn: m.lightingOn!,
                      onTap: onToggleLighting == null
                          ? null
                          : () => onToggleLighting!(m.lightingOn!),
                    )
                  else
                    Text(
                      m.value,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class MetricItem {
  final String label;
  final String value;

  /// ใช้สำหรับ row Lighting
  final bool isLighting;
  final bool? lightingOn;

  MetricItem(this.label, this.value)
      : isLighting = false,
        lightingOn = null;

  /// constructor พิเศษสำหรับ Lighting (ตอนนี้ไม่ถูกเรียกใช้แล้ว)
  MetricItem.lighting({required bool isOn})
      : label = 'Lighting',
        value = isOn ? 'เปิด' : 'ปิด',
        isLighting = true,
        lightingOn = isOn;
}

/// ดวงไฟสถานะ (ใช้แทนข้อความ เปิด/ปิด ใน Metric "Lighting")
class _LightingStatusIcon extends StatelessWidget {
  final bool isOn;
  final VoidCallback? onTap;

  const _LightingStatusIcon({
    required this.isOn,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final circleColor =
        isOn ? Colors.amber.shade400 : Colors.grey.shade400;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: circleColor,
          shape: BoxShape.circle,
          boxShadow: isOn
              ? [
                  BoxShadow(
                    color: circleColor.withOpacity(0.45),
                    blurRadius: 14,
                    spreadRadius: 3,
                  ),
                ]
              : [],
        ),
        child: const Icon(
          Icons.lightbulb,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
