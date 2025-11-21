// lib/screens/monitoring/parts/mini_stats.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ความสูงการ์ดทุกใบ ให้เท่ากันหมด
const double _kTileHeight = 110;

<<<<<<< HEAD
/// metric key ที่ใช้กับค่าจริงจาก backend (เหลือแค่ 4 ตัว)
/// oat = On Air Target (ไม่ใช่อุณหภูมิ)
=======
/// metric key ที่ใช้กับค่าจริงจาก backend (เหลือเฉพาะ DC เท่านั้น)
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
enum MetricKey {
  dcV,
  dcA,
  dcW,
<<<<<<< HEAD
  oat,
=======
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
}

String metricLabel(MetricKey k) {
  switch (k) {
    case MetricKey.dcV:
      return 'DC Voltage';
    case MetricKey.dcA:
      return 'DC Current';
    case MetricKey.dcW:
      return 'DC Power';
<<<<<<< HEAD
    case MetricKey.oat:
      return 'On Air Target';
=======
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
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
<<<<<<< HEAD
    case MetricKey.oat:
      // OAT = On Air Target → ไม่มีหน่วย
      return '';
=======
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
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
<<<<<<< HEAD
    case MetricKey.oat:
      return const Color(0xFFFB923C); // OAT โทนส้มอุ่น ๆ
=======
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
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
<<<<<<< HEAD
=======

  /// กด toggle lighting (เคยใช้กับ NODE1, ตอนนี้ไม่ใช้แล้วแต่เก็บ signature ไว้กันพัง)
  final VoidCallback onToggleLighting;
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c

  const MiniStats({
    super.key,
    required this.current,
    required this.activeMetric,
    required this.onSelectMetric,
<<<<<<< HEAD
=======
    required this.onToggleLighting,
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
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
<<<<<<< HEAD
=======
    final hasDC = _hasDC(row);
    final onAir = _onAirTarget(row);
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c

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
<<<<<<< HEAD
                final specs = _buildTiles(
                  row,
                  online: online,
                );

=======

                final specs = _buildTiles(
                  row,
                  online: online,
                  hasDC: hasDC,
                  onAir: onAir,
                );

>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
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

<<<<<<< HEAD
=======
                    case _TileKind.lightingStatus:
                      // ตอนนี้ไม่ใช้แล้ว (ไม่เรียกใช้ใน _buildTiles)
                      return _SpacerTile(width: colW);

>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
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
<<<<<<< HEAD
=======
    required bool hasDC,
    required bool onAir,
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
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

<<<<<<< HEAD
    // Metric ที่เหลือจริงจาก backend: DC + OAT (On Air Target)
    _maybeAddMetricTile(row, tiles, 'DC Voltage', MetricKey.dcV);
    _maybeAddMetricTile(row, tiles, 'DC Current', MetricKey.dcA);
    _maybeAddMetricTile(row, tiles, 'DC Power', MetricKey.dcW);
    _maybeAddMetricTile(row, tiles, 'On Air Target', MetricKey.oat);

    // สถานะ OnAir (ถ้ามี field onAir* ใน row)
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
    final name = (row['name'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;

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
=======
    // ระบบปัจจุบัน = ระบบไร้สาย (DC) ทุกโหนด
    if (hasDC) {
      _maybeAddMetricTile(row, tiles, 'DC Voltage', MetricKey.dcV);
      _maybeAddMetricTile(row, tiles, 'DC Current', MetricKey.dcA);
      _maybeAddMetricTile(row, tiles, 'DC Power', MetricKey.dcW);
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
    }

    // ตอนนี้ไม่มี Battery / RSSI / SNR แล้ว ไม่ต้องเพิ่มการ์ดพวกนี้

    // การ์ด On Air Target (สถานะเป้าหมาย)
    tiles.add(_TileSpec.onAirTarget(onAir));

    // ให้เป็นจำนวนคู่ (2 คอลัมน์)
    if (tiles.length.isOdd) {
      tiles.add(_TileSpec.spacer());
    }

    return tiles;
  }

<<<<<<< HEAD
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

=======
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
    // ✅ ดึงจาก meta ก่อน
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

    // fallback สุดท้าย devEui (ถ้ามีจากที่อื่น)
    final devEui =
        (row['devEui'] ?? row['meta']?['devEui'] ?? '').toString();
    if (devEui.isNotEmpty) return devEui;

    return '-';
  }

  bool _onlineOf(Map<String, dynamic> row) {
    final s = (row['status'] ?? '').toString().toLowerCase();
    if (s == 'on') return true;
    if (s == 'off') return false;
    if (row['online'] is bool) return row['online'] as bool;
    return false;
  }

  bool _lightingOn(Map<String, dynamic> row) {
    final v = _toInt(row['lighting']);
    return v == 1;
  }

  bool _onAirTarget(Map<String, dynamic> row) {
    // ✅ ลำดับการอ่านค่า: oat -> onAirTarget -> on_air_target -> onAir
    final raw =
        row['oat'] ?? row['onAirTarget'] ?? row['on_air_target'] ?? row['onAir'];

    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final s = raw.toLowerCase();
      if (s == 'true' || s == 'on' || s == 'yes' || s == '1') return true;
      if (s == 'false' || s == 'off' || s == '0') return false;
    }
    return false;
  }

  bool _hasDC(Map<String, dynamic> row) {
    // ✅ ตอนนี้ดูแค่ dcV/dcA/dcW ตาม backend
    return row['dcV'] != null ||
        row['dcA'] != null ||
        row['dcW'] != null;
  }

  int _decimalPlaces(MetricKey k) {
    // ตอนนี้ใช้ 2 หลักทศนิยมเหมือนกันหมด
    return 2;
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

>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
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
<<<<<<< HEAD
=======
  lightingStatus,
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
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

<<<<<<< HEAD
=======
  factory _TileSpec.lightStatus(bool isOn) =>
      _TileSpec._(_TileKind.lightingStatus, boolValue: isOn);

>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
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
<<<<<<< HEAD
        height: _kTileHeight,
=======
        height: _kTileHeight, // ✅ ให้สูงเท่ากับการ์ดอื่น
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
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
<<<<<<< HEAD
=======
                    ),
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
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
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
<<<<<<< HEAD
              height: 34,
=======
              height: 34, // ลดลงนิดให้พอดีกับ _kTileHeight
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
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
<<<<<<< HEAD

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
      height: _kTileHeight, // ✅ เท่าการ์ดอื่น
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
          ),
        ],
      ),
    );
  }
}

// ------------------- Lighting Tile (ตอนนี้ไม่ใช้แล้ว) -------------------

class _LightingTile extends StatelessWidget {
  final double width;
  final bool isOn;
  final VoidCallback onToggle;

  const _LightingTile({
    super.key,
    required this.width,
    required this.isOn,
    required this.onToggle,
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
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
        : Colors.grey.shade400;   // ไม่ได้ประกาศ = เทา

    final String statusText =
        value ? 'กำลังประกาศ' : 'ไม่ได้ประกาศ';

    const borderColor = MiniStats.kBorderNormal;
    const bgColor = Colors.white;

<<<<<<< HEAD
=======
    final circleColor =
        isOn ? Colors.amber.shade400 : Colors.grey.shade400;
    final statusText = isOn ? 'เปิดไฟ' : 'ปิดไฟ';

>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
<<<<<<< HEAD
        onTap: () {}, // แสดงสถานะอย่างเดียว
=======
        onTap: onToggle,
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
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
<<<<<<< HEAD
                'สถานะ On Air Target',
=======
                'สถานะไฟ',
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
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
<<<<<<< HEAD
                      boxShadow: value
                          ? [
                              BoxShadow(
                                color: circleColor.withOpacity(0.45),
                                blurRadius: 14,
                                spreadRadius: 3,
=======
                      boxShadow: isOn
                          ? [
                              BoxShadow(
                                color: circleColor.withOpacity(0.45),
                                blurRadius: 18,
                                spreadRadius: 4,
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
                              ),
                            ]
                          : [],
                    ),
                    child: const Icon(
<<<<<<< HEAD
                      Icons.volume_up,
=======
                      Icons.lightbulb,
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
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
    // 🎨 สีตามเงื่อนไข
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
        onTap: () {}, // แค่แสดงผล ไม่ต้องกดได้
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
                'สถานะเป้าหมาย',
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
>>>>>>> 1108a46ed975f4d799932e5d036b7a46243f6d9c
