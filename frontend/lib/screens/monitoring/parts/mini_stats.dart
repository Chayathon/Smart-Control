import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../monitoring_mock.dart';
import '../monitoring_mock.dart'
    show MonitoringEntry, MonitoringKind, MetricKey, LightingData, WirelessData, MonitoringMock;

class MiniStats extends StatelessWidget {
  final MonitoringEntry? current;
  final MetricKey activeMetric;
  final ValueChanged<MetricKey> onSelectMetric;
  final VoidCallback? onToggleLighting;

  const MiniStats({
    super.key,
    required this.current,
    required this.activeMetric,
    required this.onSelectMetric,
    this.onToggleLighting,
  });

  static const Color kCyan = Color(0xFF00BBF9);
  static const Color kBorderNormal = Color(0x1A000000);
  static const Color kBorderActive = Color(0x9900BBF9);

  @override
  Widget build(BuildContext context) {
    final e = current;
    final tileSpecs = _buildTiles(e);

    return LayoutBuilder(
      builder: (_, constraints) {
        const spacing = 12.0;
        
        final colW = (constraints.maxWidth - spacing) / 2;
        final N_ROWS = (e?.kind == MonitoringKind.lighting) ? 3 : 2;
        const RUN_SPACING = spacing;
        final totalHeight = constraints.maxHeight;
        final cardHeight = (totalHeight - (N_ROWS - 1) * RUN_SPACING) / N_ROWS;

        final tiles = tileSpecs.map<Widget>((t) {
          if (t.kind == _TileKind.spacer) {
            return _SpacerTile(width: colW, height: cardHeight);
          }

          if (t.kind == _TileKind.lightingStatus) {
            final entryId = e?.id;
            return _LightingTile(
              width: colW,
              entryId: entryId,
              onToggled: (bool next) {
                if (entryId != null) {
                  MonitoringMock.updateLightingStatus(entryId, next);
                }
                onToggleLighting?.call();
              },
              height: cardHeight,
            );
          }

          if (t.kind == _TileKind.onAirTarget) {
            return _OnAirTargetTile(
              width: colW,
              value: t.boolValue ?? false,
              height: cardHeight,
            );
          }

          // 🎯 แก้ไข: ใช้ข้อมูล Sparkline จริงจาก History (Mock.getSparklineData)
          final List<double> lineValues = (t.metric != null && e?.id != null)
              ? MonitoringMock.getSparklineData(t.metric!, e!.id)
              : const <double>[];

          return _MetricTile(
            width: colW,
            height: cardHeight,
            title: t.title!,
            value: t.value!,
            unit: t.unit!,
            color: _colorByTitle(t.title!),
            pathValues: lineValues,
            active: t.metric == activeMetric,
            onTap: t.metric == null ? null : () => onSelectMetric(t.metric!),
          );
        }).toList();

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: tiles,
        );
      },
    );
  }

  // --- (ส่วนอื่น ๆ ของ MiniStats เหมือนเดิม) ---
  List<_TileSpec> _buildTiles(MonitoringEntry? e) {
    if (e == null) return [];

    if (e.kind == MonitoringKind.lighting) {
      final d = e.data as LightingData;
      return [
        _numTile('AC Voltage', MetricKey.acV, d.acV, 'V'),
        _numTile('AC Current', MetricKey.acA, d.acA, 'A'),
        _numTile('AC Power', MetricKey.acW, d.acW, 'W'),
        _numTile('AC Frequency', MetricKey.acHz, d.acHz, 'Hz'),
        _numTile('AC Energy', MetricKey.acKWh, d.acKWh, 'kWh'),
        _TileSpec.lightStatus(),
      ];
    } else {
      final d = e.data as WirelessData;
      return [
        _numTile('DC Voltage', MetricKey.dcV, d.dcV, 'V'),
        _numTile('DC Current', MetricKey.dcA, d.dcA, 'A'),
        _numTile('DC Power', MetricKey.dcW, d.dcW, 'W'),
        _TileSpec.onAirTarget(d.onAirTarget),
      ];
    }
  }

  _TileSpec _numTile(String title, MetricKey key, double value, String unit) {
    return _TileSpec.metric(title: title, unit: unit, value: value, metric: key);
  }

  // ❌ ลบฟังก์ชัน _expandSparkFrom ออก
  // static List<double> _expandSparkFrom(double base) { ... }

  static Color _colorByTitle(String t) {
    if (t.contains('Voltage')) return const Color(0xFF22C55E);
    if (t.contains('Current')) return const Color(0xFF60A5FA);
    if (t.contains('Power')) return const Color(0xFFF97316);
    if (t.contains('Frequency')) return const Color(0xFFA78BFA);
    if (t.contains('Energy')) return const Color(0xFFFACC15);
    return Colors.black;
  }
}

enum _TileKind { metric, lightingStatus, onAirTarget, spacer }

class _TileSpec {
  final _TileKind kind;
  final String? title;
  final String? unit;
  final double? value;
  final bool? boolValue;
  final MetricKey? metric;

  _TileSpec._(this.kind, {this.title, this.unit, this.value, this.boolValue, this.metric});

  factory _TileSpec.metric({
    required String title,
    required String unit,
    required double value,
    required MetricKey metric,
  }) =>
      _TileSpec._(_TileKind.metric, title: title, unit: unit, value: value, metric: metric);

  factory _TileSpec.lightStatus() => _TileSpec._(_TileKind.lightingStatus);

  factory _TileSpec.onAirTarget(bool v) => _TileSpec._(_TileKind.onAirTarget, boolValue: v);

  factory _TileSpec.spacer() => _TileSpec._(_TileKind.spacer);
}

class _MetricTile extends StatelessWidget {
  final double width;
  final double height;
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
    required this.height,
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
    final borderColor = active ? MiniStats.kBorderActive : MiniStats.kBorderNormal;
    const bgColor = Colors.white;

    // 🎯 การแก้ไข: เพิ่ม BoxDecoration และ InkWell เพื่อให้ Card มี Border/Shadow และกดได้
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: width,
        height: height,
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.black54)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_fmt(value),
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.black)),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3.0),
                      child: Text(unit,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54)),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 12),

            Expanded(
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

  _SparkPainter(this.values, {required this.lineColor, this.isActive = false});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final minY = values.reduce(math.min);
    final maxY = values.reduce(math.max);
    final range = (maxY - minY).abs() < 0.0001 ? 1 : (maxY - minY);

    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final y = size.height - ((values[i] - minY) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // 🔹 เส้นกราฟ (แก้ไขความหนาและรูปแบบปลาย)
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0 // 🎯 แก้ไข: ให้เส้นบางและเรียบขึ้น
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt; // 🎯 แก้ไข: ให้ปลายตัดตรง
    canvas.drawPath(path, paint);

    // ❌ ลบโค้ดวาดเส้นแนวนอนกลาง (Baseline) ออก
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
  final double height;
  const _SpacerTile({required this.width, required this.height});
  @override
  Widget build(BuildContext context) => SizedBox(width: width, height: height);
}

// ------------------- _LightingTile (ถูกแก้ไข: พื้นหลังและ Title) -------------------
class _LightingTile extends StatelessWidget {
  final double width;
  final double height;
  final String? entryId;
  final ValueChanged<bool>? onToggled;

  const _LightingTile({
    required this.width,
    required this.height,
    required this.entryId,
    required this.onToggled,
  });

  @override
  Widget build(BuildContext context) {
    const borderColor = MiniStats.kBorderNormal;
    const bgColor = Colors.white;

    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: Colors.transparent, // 🎯 แก้ไข: เป็น Transparent เพื่อให้ Container ด้านในกำหนด Decoration ได้
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () { /* Tap handled by the button inside */ },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            // 🎯 การแก้ไข: เพิ่ม BoxDecoration เหมือน _MetricTile
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔹 1. ส่วน Title (เปลี่ยนเป็น 'สถานะไฟ')
                const Text('สถานะไฟ', // 🎯 แก้ไข: เปลี่ยนชื่อเป็นภาษาไทย
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.black54)),
                
                const SizedBox(height: 8),
                // ... (ส่วนปุ่ม ON/OFF เหมือนเดิม)
                Expanded(
                  child: Center(
                    child: ValueListenableBuilder<List<MonitoringEntry>>(
                      valueListenable: MonitoringMock.itemsNotifier,
                      builder: (context, _, __) {
                        final e = (entryId == null)
                            ? null
                            : MonitoringMock.findById(entryId);
                        final isOn = (e?.data is LightingData)
                            ? (e!.data as LightingData).statusLighting
                            : false;
                        final base = isOn ? const Color(0xFF17C964) : const Color(0xFFFF4D4F);
                        final statusText = isOn ? 'ON' : 'OFF';
                        
                        return InkWell(
                          onTap: () {
                            final next = !isOn;
                            if (entryId != null) {
                              MonitoringMock.updateLightingStatus(entryId!, next);
                            }
                            onToggled?.call(next);
                          },
                          borderRadius: BorderRadius.circular(99),
                          child: Container(
                            width: 70,
                            height: 70,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: base,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: base.withOpacity(0.4),
                                    blurRadius: 24,
                                    spreadRadius: 4)
                              ],
                            ),
                            child: Text(statusText,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18)),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------- _OnAirTargetTile (ถูกแก้ไข: พื้นหลังและ Title) -------------------
class _OnAirTargetTile extends StatelessWidget {
  final double width;
  final double height;
  final bool value;

  const _OnAirTargetTile({required this.width, required this.height, required this.value});

  @override
  Widget build(BuildContext context) {
    final base = value ? const Color(0xFF17C964) : const Color(0xFFFF4D4F);
    final statusText = value ? 'ON' : 'OFF';

    const borderColor = MiniStats.kBorderNormal;
    const bgColor = Colors.white;

    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: Colors.transparent, // 🎯 แก้ไข: เป็น Transparent เพื่อให้ Container ด้านในกำหนด Decoration ได้
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () { /* Tap handled by the button inside */ },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            // 🎯 การแก้ไข: เพิ่ม BoxDecoration เหมือน _MetricTile
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔹 1. ส่วน Title (เปลี่ยนเป็น 'สถานะเป้าหมาย')
                const Text('สถานะเป้าหมาย', // 🎯 แก้ไข: เปลี่ยนชื่อเป็นภาษาไทย
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.black54)),
                
                const SizedBox(height: 8),

                // ... (ส่วนปุ่ม ON/OFF เหมือนเดิม)
                Expanded(
                  child: Center(
                    child: Container(
                      width: 70,
                      height: 70,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: base,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: base.withOpacity(0.4), blurRadius: 24, spreadRadius: 4)
                        ],
                      ),
                      child: Text(statusText,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}