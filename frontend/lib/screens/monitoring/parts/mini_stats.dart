import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ความสูงการ์ดของ metric (AC/DC)
const double _kTileHeight = 90;

/// metric key ที่ใช้กับค่าจริงจาก backend
/// DC 3 + AC 5 + OAT
/// oat = On Air Target (ไม่ใช่อุณหภูมิ)
enum MetricKey {
  // DC side
  dcV, // DC Voltage
  dcA, // DC Current
  dcW, // DC Power

  // AC side (5 ตัว)
  acV, // AC Voltage
  acA, // AC Current
  acW, // AC Power
  acfreq, // AC Frequency
  acEngy, // AC Energy

  // อื่น ๆ
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

    case MetricKey.acV:
      return 'AC Voltage';
    case MetricKey.acA:
      return 'AC Current';
    case MetricKey.acW:
      return 'AC Power';
    case MetricKey.acfreq:
      return 'AC Frequency';
    case MetricKey.acEngy:
      return 'AC Energy';

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

    case MetricKey.acV:
      return 'V';
    case MetricKey.acA:
      return 'A';
    case MetricKey.acW:
      return 'W';
    case MetricKey.acfreq:
      return 'Hz';
    case MetricKey.acEngy:
      return 'kWh';

    case MetricKey.oat:
      // OAT = On Air Target → ไม่มีหน่วย
      return '';
  }
}

Color metricColor(MetricKey k) {
  switch (k) {
    case MetricKey.dcV:
      return const Color(0xFF06B6D4); // ฟ้าอมเขียว
    case MetricKey.dcA:
      return const Color(0xFF14B8A6); // เขียวอมฟ้า
    case MetricKey.dcW:
      return const Color(0xFFEF4444); // แดง

    case MetricKey.acV:
      return const Color(0xFF6366F1); // ม่วงฟ้า
    case MetricKey.acA:
      return const Color(0xFFF97316); // ส้ม
    case MetricKey.acW:
      return const Color(0xFFEAB308); // เหลือง
    case MetricKey.acfreq:
      return const Color(0xFF0EA5E9); // ฟ้า
    case MetricKey.acEngy:
      return const Color(0xFF22C55E); // เขียว

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
        ),
      );
    }

    final online = _onlineOf(row);
    final deviceName = _nameOf(row);
    final lastUpdate = _timestampOf(row);
    final onAir = _onAirTarget(row);

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

                // ===== metrics ด้านล่าง =====
                final specs = _buildMetricTiles(
                  row,
                  online: online,
                );

                // 2 คอลัมน์ สำหรับ metric
                final colW = (constraints.maxWidth - spacing) / 2;

                // 3 คอลัมน์บนสุด (Status / LastUpdate / OnAir)
                final headerW =
                    (constraints.maxWidth - spacing * 2) / 3;

                // header tiles (3 ใบบนสุด)
                final headerRow = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // สถานะอุปกรณ์
                    SizedBox(
                      width: headerW,
                      child: _StatusTile(
                        width: headerW,
                        online: online,
                        deviceName: deviceName,
                      ),
                    ),
                    const SizedBox(width: spacing),
                    // อัปเดตล่าสุด (ถ้าไม่มี timestamp ให้ใช้ spacer)
                    SizedBox(
                      width: headerW,
                      child: lastUpdate != null
                          ? _LastUpdateTile(
                              width: headerW,
                              timestamp: lastUpdate,
                            )
                          : const _SpacerTile(width: 0),
                    ),
                    const SizedBox(width: spacing),
                    // สถานะ On Air Target
                    SizedBox(
                      width: headerW,
                      child: _OnAirTargetTile(
                        width: headerW,
                        value: onAir,
                      ),
                    ),
                  ],
                );

                if (specs.isEmpty) {
                  // ถ้าไม่มี metric เลย แสดงแต่ header + ข้อความ
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        headerRow,
                        const SizedBox(height: 16),
                        const Center(
                          child: Text(
                            'ไม่มีข้อมูลค่าทางไฟฟ้าสำหรับอุปกรณ์นี้',
                            style: TextStyle(color: Colors.black45),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // children metric ด้านล่าง
                final metricChildren =
                    specs.map<Widget>((t) {
                  switch (t.kind) {
                    case _TileKind.spacer:
                      return _SpacerTile(width: colW);

                    case _TileKind.metric:
                      final m = t.metric!;
                      final value = t.value!;
                      final unit = t.unit ?? unitOf(m);
                      final color = metricColor(m);
                      final isActive = (m == activeMetric);

                      // ตอนนี้ยังใช้ค่าเดียวทำเส้นตรง
                      final List<double> lineValues =
                          value.isFinite
                              ? [value, value, value]
                              : const <double>[];

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

                    case _TileKind.status:
                    case _TileKind.onAirTarget:
                    case _TileKind.lastUpdate:
                      // ไม่ได้ใช้ใน metric grid แล้ว
                      return const SizedBox.shrink();
                  }
                }).toList();

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      headerRow,
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: metricChildren,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ===================== metric tile builder =====================

  /// สร้างเฉพาะ tiles ของ metric (AC/DC)
  List<_TileSpec> _buildMetricTiles(
    Map<String, dynamic> row, {
    required bool online,
  }) {
    final tiles = <_TileSpec>[];

    // ===== AC Metrics =====
    _maybeAddMetricTile(row, tiles, 'AC Voltage', MetricKey.acV);
    _maybeAddMetricTile(row, tiles, 'AC Current', MetricKey.acA);
    _maybeAddMetricTile(row, tiles, 'AC Power', MetricKey.acW);
    _maybeAddMetricTile(row, tiles, 'AC Frequency', MetricKey.acfreq);
    _maybeAddMetricTile(row, tiles, 'AC Energy', MetricKey.acEngy);

    // ===== DC Metrics =====
    _maybeAddMetricTile(row, tiles, 'DC Voltage', MetricKey.dcV);
    _maybeAddMetricTile(row, tiles, 'DC Current', MetricKey.dcA);
    _maybeAddMetricTile(row, tiles, 'DC Power', MetricKey.dcW);

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

  /// ดึง timestamp จาก row แล้วบังคับเป็น UTC
  DateTime? _timestampOf(Map<String, dynamic> row) {
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
    return ts;
  }

  bool _onlineOf(Map<String, dynamic> row) {
    final ts = _timestampOf(row);
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
      case MetricKey.dcV:
      case MetricKey.dcA:
      case MetricKey.dcW:
      case MetricKey.acV:
      case MetricKey.acA:
      case MetricKey.acW:
      case MetricKey.acfreq:
      case MetricKey.acEngy:
      case MetricKey.oat:
        // ให้ทุก metric แสดง 2 ตำแหน่งเหมือนกัน
        return 2;
    }
  }

  /// ✅ ดึงค่าจาก field ใหม่ของ backend:
  /// vdc, idc, wdc, vac, iac, wac, acfreq, acenergy, oat
  double? _metricValue(Map<String, dynamic> row, MetricKey k) {
    dynamic raw;
    switch (k) {
      // DC → ใช้ field ใหม่ vdc / idc / wdc
      case MetricKey.dcV:
        raw = row['vdc'];
        break;
      case MetricKey.dcA:
        raw = row['idc'];
        break;
      case MetricKey.dcW:
        raw = row['wdc'];
        break;

      // AC → ใช้ field ใหม่ vac / iac / wac / acfreq / acenergy
      case MetricKey.acV:
        raw = row['vac'];
        break;
      case MetricKey.acA:
        raw = row['iac'];
        break;
      case MetricKey.acW:
        raw = row['wac'];
        break;
      case MetricKey.acfreq:
        raw = row['acfreq'];
        break;
      case MetricKey.acEngy:
        raw = row['acenergy'];
        break;

      // OAT = target (numeric) + ถ้า offline บังคับเป็น 0
      case MetricKey.oat:
        raw = row['oat'];
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
  lastUpdate,
  spacer,
}

class _TileSpec {
  final _TileKind kind;
  final String? title;
  final String? unit;
  final double? value;
  final bool? boolValue;
  final MetricKey? metric;
  final DateTime? dateTime;

  _TileSpec._(
    this.kind, {
    this.title,
    this.unit,
    this.value,
    this.boolValue,
    this.metric,
    this.dateTime,
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

  factory _TileSpec.lastUpdate({
    required DateTime timestamp,
  }) =>
      _TileSpec._(
        _TileKind.lastUpdate,
        dateTime: timestamp,
      );

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
      ),
    );
  }

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
      final y = size.height -
          ((values[i] - minY) / range) * size.height;
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
  });

  @override
  Widget build(BuildContext context) {
    const bgColor = Colors.white;
    const borderColor = MiniStats.kBorderNormal;

    final statusText = online ? 'ออนไลน์' : 'ออฟไลน์';
    final statusColor = online ? Colors.green : Colors.red;
    final circleColor = statusColor;

    return Container(
      width: width,
      height: 94,
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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
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
          const SizedBox(height: 6),
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
                    const SizedBox(height: 2),
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
                width: 44,
                height: 44,
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
                  size: 24,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------- _OnAirTargetTile -------------------

class _OnAirTargetTile extends StatelessWidget {
  final double width;
  final bool value;

  const _OnAirTargetTile({
    super.key,
    required this.width,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final Color circleColor = value
        ? const Color(0xFF48CAE4) // กำลังประกาศ = ฟ้า
        : Colors.grey.shade400; // ไม่ได้ประกาศ = เทา

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
          height: 94,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
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
              const SizedBox(height: 6),
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
                    width: 44,
                    height: 44,
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
                      size: 24,
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

// ------------------- _LastUpdateTile -------------------

class _LastUpdateTile extends StatelessWidget {
  final double width;
  final DateTime timestamp;

  const _LastUpdateTile({
    super.key,
    required this.width,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    const borderColor = MiniStats.kBorderNormal;
    const bgColor = Colors.white;

    final localTs = timestamp.toLocal();
    final agoText = _formatTimeAgo(timestamp);
    final detailText = _formatDateTime(localTs);

    return Container(
      width: width,
      height: 94,
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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'อัปเดตล่าสุด',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agoText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detailText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.schedule_rounded,
                  color: Colors.indigo.shade400,
                  size: 22,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime tsUtc) {
    final now = DateTime.now().toUtc();
    final diff = now.difference(tsUtc);

    if (diff.inSeconds < 5) return 'เมื่อสักครู่';
    if (diff.inSeconds < 60) return '${diff.inSeconds} วินาทีที่แล้ว';
    if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
    if (diff.inHours < 24) return '${diff.inHours} ชั่วโมงที่แล้ว';
    if (diff.inDays < 30) return '${diff.inDays} วันที่แล้ว';
    return 'มากกว่า 30 วันที่แล้ว';
  }

  String _formatDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }
}
