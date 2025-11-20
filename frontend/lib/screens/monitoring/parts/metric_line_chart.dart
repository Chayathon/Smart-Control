// lib/screens/monitoring/parts/metric_line_chart.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'mini_stats.dart'; // ใช้ MetricKey จากไฟล์นี้

typedef Json = Map<String, dynamic>;

/// ช่วงเวลาประวัติ
enum HistorySpan { day1, day7, day15, day30 }

class MetricLineChart extends StatefulWidget {
  /// history ของ devEui ที่เลือก (มาจาก MonitoringScreen._historyForId)
  final List<Json> history;

  /// metric ที่เลือก (จาก MiniStats)
  final MetricKey metric;

  /// ชื่ออุปกรณ์ (ใช้แสดงใน title)
  final String? deviceName;

  const MetricLineChart({
    super.key,
    required this.history,
    required this.metric,
    required this.deviceName,
  });

  @override
  State<MetricLineChart> createState() => _MetricLineChartState();
}

class _MetricLineChartState extends State<MetricLineChart> {
  int? _hitIndex;

  /// เริ่มต้นที่ 1D
  HistorySpan _selectedSpan = HistorySpan.day1;

  @override
  Widget build(BuildContext context) {
    // ===== เตรียมข้อมูลสำหรับกราฟ =====
    final pts = _buildPoints(
      widget.history,
      widget.metric,
      _selectedSpan,
    );
    final unit = _unitOf(widget.metric);
    final mainColor = _metricColor(widget.metric);

    final metricTitle = _metricLabel(widget.metric);
    final title = widget.deviceName == null
        ? metricTitle
        : '$metricTitle — ${widget.deviceName}';

    final border = Colors.grey[200]!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ===== Header: Title + ปุ่มช่วงเวลา =====
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildTimeRangeSelector(),
                ],
              ),
            ),
            const Divider(height: 1),

            // ===== ตัวกราฟ =====
            Expanded(
              child: pts.isEmpty
                  ? const Center(
                      child: Text(
                        'ยังไม่มีข้อมูลสำหรับช่วงเวลานี้',
                        style: TextStyle(
                          color: Colors.black45,
                          fontSize: 13,
                        ),
                      ),
                    )
                  : GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (d) {
                        if (pts.isEmpty) return;
                        final hit =
                            _nearestIndex(pts, d.localPosition, context);
                        setState(() => _hitIndex = hit);
                      },
                      onHorizontalDragUpdate: (d) {
                        if (pts.isEmpty) return;
                        final render =
                            context.findRenderObject() as RenderBox?;
                        if (render == null) return;
                        final local = render.globalToLocal(d.globalPosition);
                        final hit = _nearestIndex(pts, local, context);
                        setState(() => _hitIndex = hit);
                      },
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(12, 10, 16, 12),
                        child: _ChartCanvas(
                          points: pts,
                          unit: unit,
                          hitIndex: _hitIndex,
                          mainColor: mainColor,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// ปุ่มเลือกช่วงเวลาแบบ segmented control
  Widget _buildTimeRangeSelector() {
    final options = <HistorySpan, String>{
      HistorySpan.day1: '1D',
      HistorySpan.day7: '7D',
      HistorySpan.day15: '15D',
      HistorySpan.day30: '30D',
    };

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.entries.map((e) {
          final span = e.key;
          final label = e.value;
          final isSelected = span == _selectedSpan;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                setState(() {
                  _selectedSpan = span;
                  _hitIndex = null;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.blue.shade600
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color:
                        isSelected ? Colors.white : Colors.black54,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ===== สร้างจุดกราฟจาก history จริง =====
  List<_Pt> _buildPoints(
    List<Json> history,
    MetricKey metric,
    HistorySpan span,
  ) {
    if (history.isEmpty) return const [];

    // 1) แปลงเป็นคู่ (ts, value) และ sort ตามเวลา (ใช้เวลาเดิมจากฐานข้อมูล)
    final ptsRaw = <_Pt>[];
    for (final row in history) {
      final ts = _parseTs(row['timestamp']);
      if (ts == null) continue;

      final v = _valueForMetric(row, metric);
      if (v == null) continue;

      ptsRaw.add(_Pt(ts, v));
    }
    if (ptsRaw.isEmpty) return const [];

    ptsRaw.sort((a, b) => a.t.compareTo(b.t));

    // 2) กรองให้เหลือเฉพาะช่วงเวลา ตามปุ่มที่เลือก
    final lastTs = ptsRaw.last.t;
    final days = switch (span) {
      HistorySpan.day1 => 1,
      HistorySpan.day7 => 7,
      HistorySpan.day15 => 15,
      HistorySpan.day30 => 30,
    };
    final from = lastTs.subtract(Duration(days: days));

    final filtered = ptsRaw
        .where((p) => !p.t.isBefore(from) && !p.t.isAfter(lastTs))
        .toList();

    return filtered;
  }

  // อ่าน timestamp จาก String / int / DateTime
  DateTime? _parseTs(dynamic v) {
    try {
      if (v == null) return null;
      if (v is DateTime) return v.toUtc();
      if (v is int) {
        // backend: timestamp: ts (ms epoch → รองรับ int)
        return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true);
      }
      if (v is String && v.isNotEmpty) {
        // รองรับ timestamp เป็น string ISO
        return DateTime.parse(v).toUtc();
      }
    } catch (_) {}
    return null;
  }

  // แปลง row -> ค่า metric (ให้ตรงกับ backend ปัจจุบัน)
  double? _valueForMetric(Json row, MetricKey metric) {
    dynamic raw;

    switch (metric) {
      case MetricKey.dcV:
        raw = row['dcV']; // ✅ จาก backend
        break;
      case MetricKey.dcA:
        raw = row['dcA']; // ✅ จาก backend
        break;
      case MetricKey.dcW:
        raw = row['dcW']; // ✅ จาก backend
        break;

      // metric อื่น ๆ ตอนนี้ไม่มีในฐานข้อมูล → ไม่ต้องอ่าน key อะไร
      default:
        return null;
    }

    if (raw == null) return null;
    if (raw is double) return raw;
    if (raw is int) return raw.toDouble();
    if (raw is num) return raw.toDouble();
    if (raw is String && raw.isNotEmpty) {
      return double.tryParse(raw);
    }
    return null;
  }

  int _nearestIndex(List<_Pt> pts, Offset localPos, BuildContext ctx) {
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return 0;
    final size = box.size;
    const left = 54.0, right = 12.0, top = 10.0, bottom = 32.0;
    final chartW = size.width - left - right;

    final minT = pts.first.t;
    final maxT = pts.last.t;
    double totalSec =
        maxT.difference(minT).inSeconds.toDouble();
    if (totalSec <= 0) totalSec = 1.0;

    final x = (localPos.dx - left).clamp(0, chartW);
    final sec = (x / chartW) * totalSec;
    final target =
        minT.add(Duration(seconds: sec.round()));

    int best = 0;
    int bestDiff =
        (pts[0].t.difference(target).inMilliseconds).abs();
    for (int i = 1; i < pts.length; i++) {
      final diff =
          (pts[i].t.difference(target).inMilliseconds).abs();
      if (diff < bestDiff) {
        best = i;
        bestDiff = diff;
      }
    }
    return best;
  }

  // ===== Helpers label / unit / สี (ให้ตรงกับ field ที่มีจริงตอนนี้: dcV/dcA/dcW) =====

  String _metricLabel(MetricKey m) {
    switch (m) {
      case MetricKey.dcV:
        return 'DC Voltage';
      case MetricKey.dcA:
        return 'DC Current';
      case MetricKey.dcW:
        return 'DC Power';

      // metric อื่น ๆ ที่ enum ยังมีอยู่ แต่ไม่มีในฐานข้อมูลตอนนี้
      default:
        return m.name; // ป้องกัน error เฉย ๆ
    }
  }

  String _unitOf(MetricKey m) {
    switch (m) {
      case MetricKey.dcV:
        return 'V';
      case MetricKey.dcA:
        return 'A';
      case MetricKey.dcW:
        return 'W';

      // อย่างอื่นตอนนี้ไม่ใช้
      default:
        return '';
    }
  }

  Color _metricColor(MetricKey m) {
    switch (m) {
      case MetricKey.dcV:
        return const Color(0xFF06B6D4); // ฟ้าอมเขียว
      case MetricKey.dcA:
        return const Color(0xFF14B8A6); // เขียวอมฟ้า
      case MetricKey.dcW:
        return const Color(0xFFEF4444); // แดง

      default:
        return Colors.blueGrey; // fallback เฉย ๆ
    }
  }
}

class _Pt {
  final DateTime t;
  final double y;
  _Pt(this.t, this.y);
}

class _ChartCanvas extends StatelessWidget {
  final List<_Pt> points;
  final String unit;
  final int? hitIndex;
  final Color mainColor;

  const _ChartCanvas({
    required this.points,
    required this.unit,
    this.hitIndex,
    required this.mainColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ChartPainter(
        points: points,
        unit: unit,
        hitIndex: hitIndex,
        mainColor: mainColor,
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<_Pt> points;
  final String unit;
  final int? hitIndex;
  final Color mainColor;

  _ChartPainter({
    required this.points,
    required this.unit,
    required this.hitIndex,
    required this.mainColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const left = 54.0, right = 12.0, top = 10.0, bottom = 32.0;
    final chart =
        Rect.fromLTRB(left, top, size.width - right, size.height - bottom);

    final axis = Paint()
      ..color = Colors.grey[300]!.withOpacity(0.35)
      ..strokeWidth = 1;

    final tp = TextPainter(
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );
    const labelStyle = TextStyle(
      color: Colors.black87,
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );

    // ==== Y range ====
    double minY = points.map((e) => e.y).reduce(math.min);
    double maxY = points.map((e) => e.y).reduce(math.max);
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    }
    final yPad = (maxY - minY) * 0.08;
    minY -= yPad;
    maxY += yPad;

    // ==== X range ====
    final minT = points.first.t;
    final maxT = points.last.t;
    double totalSec =
        maxT.difference(minT).inSeconds.toDouble();
    if (totalSec <= 0) totalSec = 1.0;

    // horizontal grid + y labels
    const yDiv = 4;
    for (int i = 0; i <= yDiv; i++) {
      final ty = chart.top + chart.height * (1 - i / yDiv);
      canvas.drawLine(
        Offset(chart.left, ty),
        Offset(chart.right, ty),
        axis,
      );

      final val = minY + (maxY - minY) * (i / yDiv);
      final digits = ((maxY - minY) > 10) ? 0 : 2;
      tp.text = TextSpan(
        text: '${val.toStringAsFixed(digits)} $unit',
        style: labelStyle,
      );
      tp.layout();
      tp.paint(
        canvas,
        Offset(chart.left - 8 - tp.width, ty - tp.height / 2),
      );
    }

    // vertical grid + x labels
    const xDiv = 4;
    for (int i = 0; i <= xDiv; i++) {
      final tx = chart.left + chart.width * (i / xDiv);
      canvas.drawLine(
        Offset(tx, chart.top),
        Offset(tx, chart.bottom),
        axis,
      );

      final sec = totalSec * (i / xDiv);
      final dt = minT.add(Duration(seconds: sec.round()));
      final label =
          _fmtTime(dt, spanSeconds: totalSec.toDouble());
      tp.text = TextSpan(text: label, style: labelStyle);
      tp.layout();
      tp.paint(
        canvas,
        Offset(tx - tp.width / 2, chart.bottom + 6),
      );
    }

    // main line + เก็บตำแหน่งจุดไว้ใช้วาด marker
    final path = Path();
    final pointPositions = <Offset>[];

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final nx = chart.left +
          chart.width *
              (p.t.difference(minT).inSeconds /
                  totalSec);
      final ny = chart.bottom -
          chart.height *
              ((p.y - minY) / (maxY - minY));

      pointPositions.add(Offset(nx, ny));

      if (i == 0) {
        path.moveTo(nx, ny);
      } else {
        path.lineTo(nx, ny);
      }
    }

    final linePaint = Paint()
      ..color = mainColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    // markers ทุกจุด
    final markerOuter = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final markerInner = Paint()
      ..color = mainColor
      ..style = PaintingStyle.fill;

    for (final pos in pointPositions) {
      canvas.drawCircle(pos, 3.5, markerOuter);
      canvas.drawCircle(pos, 2.3, markerInner);
    }

    // marker + tooltip ของจุดที่เลือก
    if (hitIndex != null &&
        hitIndex! >= 0 &&
        hitIndex! < points.length) {
      final p = points[hitIndex!];
      final nx = chart.left +
          chart.width *
              (p.t.difference(minT).inSeconds /
                  totalSec);
      final ny = chart.bottom -
          chart.height *
              ((p.y - minY) / (maxY - minY));

      final vline = Paint()
        ..color = mainColor.withOpacity(0.5)
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(nx, chart.top),
        Offset(nx, chart.bottom),
        vline,
      );

      final dot = Paint()..color = mainColor;
      canvas.drawCircle(Offset(nx, ny), 4, dot);
      canvas.drawCircle(
        Offset(nx, ny),
        8,
        Paint()..color = dot.color.withOpacity(0.15),
      );

      final tooltip =
          '${p.y.toStringAsFixed(2)} $unit\n${_fmtTime(p.t, spanSeconds: totalSec)}';
      const pad = 8.0;
      final textPainter = TextPainter(
        text: TextSpan(
          text: tooltip,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr,
      )..layout();

      final boxW = textPainter.width + pad * 2;
      final boxH = textPainter.height + pad * 2;
      double bx = nx + 10;
      double by = ny - boxH - 8;
      if (bx + boxW > size.width) bx = nx - boxW - 10;
      if (by < 0) by = ny + 8;

      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(bx, by, boxW, boxH),
        const Radius.circular(8),
      );
      final bg =
          Paint()..color = Colors.black.withOpacity(0.8);
      canvas.drawRRect(r, bg);
      textPainter.paint(canvas, Offset(bx + pad, by + pad));
    }
  }

  // เลือกรูปแบบ time label ตาม span
  String _fmtTime(DateTime dt, {required double spanSeconds}) {
    final daySec = const Duration(days: 1).inSeconds;
    final hourSec = const Duration(hours: 1).inSeconds;

    if (spanSeconds > 10 * daySec) {
      final dd = dt.day.toString().padLeft(2, '0');
      final mm = dt.month.toString().padLeft(2, '0');
      final yy = dt.year.toString().substring(2);
      return '$dd/$mm/$yy';
    } else if (spanSeconds > 2 * daySec) {
      final dd = dt.day.toString().padLeft(2, '0');
      final mm = dt.month.toString().padLeft(2, '0');
      return '$dd/$mm';
    } else if (spanSeconds > 2 * hourSec) {
      final hh = dt.hour.toString().padLeft(2, '0');
      final mn = dt.minute.toString().padLeft(2, '0');
      return '$hh:$mn';
    } else {
      final hh = dt.hour.toString().padLeft(2, '0');
      final mn = dt.minute.toString().padLeft(2, '0');
      final ss = dt.second.toString().padLeft(2, '0');
      return '$hh:$mn:$ss';
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.points != points ||
      old.unit != unit ||
      old.hitIndex != hitIndex ||
      old.mainColor != mainColor;
}
