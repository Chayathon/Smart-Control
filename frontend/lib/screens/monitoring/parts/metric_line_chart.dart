// lib/screens/monitoring/parts/metric_line_chart.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../monitoring_mock.dart';

// ******************************************************
// * ข้อมูลและฟังก์ชันช่วยเหลือถูกย้ายไปที่ monitoring_mock.dart
// ******************************************************

class MetricLineChart extends StatefulWidget {
  final List<MonitoringEntry> items;
  final String? selectedId;
  final MetricKey metric;

  const MetricLineChart({
    super.key,
    required this.items,
    required this.selectedId,
    required this.metric,
  });

  @override
  State<MetricLineChart> createState() => _MetricLineChartState();
}

class _MetricLineChartState extends State<MetricLineChart> {
  int? _hitIndex;
  // ✅ เพิ่ม state สำหรับช่วงเวลาที่เลือก
  HistorySpan _selectedSpan = HistorySpan.day7; 

  MonitoringEntry?
  get _current {
    final items = widget.items;
    final id = widget.selectedId;
    if (items.isEmpty) return null;
    if (id == null) return items.first;
    try {
      return items.firstWhere((e) => e.id == id);
    } catch (_) {
      return items.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _current;
    final border = Colors.grey[200]!;
    final title = e == null ? 'กราฟ' : '${metricLabel(widget.metric)} — ${entryLabel(e)}';
    // ✅ ส่ง _selectedSpan ไปยัง historyFor
    final history = (e == null) ?
        <HistoryPoint>[] : historyFor(e, span: _selectedSpan); 
    final unit = e == null ? '' : unitOf(widget.metric); 
    final pts = _extract(history, widget.metric);
    // ✅ ดึงสีหลักมาใช้ในกราฟ
    final mainColor = metricColor(widget.metric); 
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 
                  16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header (ปุ่มเลือกวันมาอยู่แถวเดียวกับ Title ชิดขวา)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10), // ปรับ padding ล่างให้สวยงาม
              child: Row( // <-- เปลี่ยนเป็น Row เพื่อให้อยู่แถวเดียวกัน
                mainAxisAlignment: MainAxisAlignment.spaceBetween, // <-- จัดให้อยู่ซ้าย-ขวา
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. Title
                  Expanded( // <-- ห่อด้วย Expanded เพื่อไม่ให้ชื่อกราฟดันปุ่มจนล้น
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
               
                  // 2. Time Range Selector
                  _buildTimeRangeSelector(), 
                ],
              ),
            ),
            const Divider(height: 1),

            // Canvas + gestures
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) {
                  if (pts.isEmpty) return;
                  final hit = _nearestIndex(pts, d.localPosition, context);
                  setState(() => _hitIndex = hit);
                },
                onHorizontalDragUpdate: (d) {
                  if (pts.isEmpty) return;
                  final render = context.findRenderObject() as RenderBox?;
                  if (render == null) return;
                  final local = render.globalToLocal(d.globalPosition);
                  final hit = _nearestIndex(pts, local, context);
                  setState(() => _hitIndex = hit);
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 16, 12),
                  child: _ChartCanvas(
                    points: pts,
                    unit: unit,
                    hitIndex: _hitIndex,
                    mainColor: mainColor, // <-- ส่งสีหลักเข้าไป
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Widget สำหรับปุ่มเลือกช่วงเวลา
  Widget _buildTimeRangeSelector() {
    // เอา SingleChildScrollView ออก และปรับ padding
    return Padding( // <-- ใช้ Padding ห่อเพื่อเพิ่มระยะห่างด้านซ้ายจาก Title
      padding: const EdgeInsets.only(left: 12.0), 
      child: Row( // Row ที่เก็บปุ่มทั้งหมด
        children: HistorySpan.values.map((s) {
          final isSelected = s == _selectedSpan;
          // แปลง enum (day1) เป็น label (1, 7, 15, 30)
          final label = s.name.substring(3).toUpperCase(); 
          
          // เพิ่ม 'D' ต่อท้ายตัวเลข
          final displayLabel = label + 'D'; 

          return Padding(
            padding: const EdgeInsets.only(left: 8.0), // ใช้ left เพื่อเว้นระยะห่างระหว่างปุ่ม
            child: InkWell(
              onTap: () => setState(() {
                _selectedSpan = s;
                _hitIndex = null; // รีเซ็ต hitIndex เมื่อเปลี่ยนช่วงเวลา
              }),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ?
                      Colors.blue.shade50 : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Colors.blue.shade600 : Colors.grey.shade300,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  displayLabel, // ใช้ displayLabel
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.blue.shade800 : Colors.black54,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  static List<_Pt> _extract(List<HistoryPoint> list, MetricKey m) {
    return list.map((p) {
      final y = valueForMetric(p, m); 
      if (y == null) return null;
      return _Pt(p.ts, y);
    }).whereType<_Pt>().toList(growable: false);
  }

  int _nearestIndex(List<_Pt> pts, Offset localPos, BuildContext ctx) {
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return 0;
    final size = box.size;
    const left = 54.0, right = 12.0, top = 10.0, bottom = 28.0;
    final chartW = size.width - left - right;
    final minT = pts.first.t;
    final maxT = pts.last.t;
    double totalSec = maxT.difference(minT).inSeconds.toDouble();
    if (totalSec <= 0) totalSec = 1;

    final x = (localPos.dx - left).clamp(0, chartW);
    final sec = (x / chartW) * totalSec;
    final target = minT.add(Duration(seconds: sec.round()));

    int best = 0;
    int bestDiff = (pts[0].t.difference(target).inMilliseconds).abs();
    for (int i = 1; i < pts.length; i++) {
      final diff = (pts[i].t.difference(target).inMilliseconds).abs();
      if (diff < bestDiff) { best = i; bestDiff = diff;
      }
    }
    return best;
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
  // ✅ เพิ่มสีหลัก
  final Color mainColor; 
  const _ChartCanvas({
    required this.points, 
    required this.unit, 
    this.hitIndex,
    required this.mainColor, // <-- เพิ่ม mainColor ใน constructor
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ChartPainter(
        points: points, 
        unit: unit, 
        hitIndex: hitIndex,
        mainColor: mainColor, // <-- ส่งสีไป Painter
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<_Pt> points;
  final String unit;
  final int? hitIndex;
  // ✅ เพิ่มสีหลัก
  final Color mainColor; 
  _ChartPainter({
    required this.points, 
    required this.unit, 
    required this.hitIndex,
    required this.mainColor, // <-- รับ mainColor
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    // margins
    const left = 54.0, right = 12.0, top = 10.0, bottom = 32.0;
    final chart = Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    // axis paint
    final axis = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 1;

    // painter for text
    final tp = TextPainter(
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );
    const labelStyle = TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.w600);

    // Y range
    double minY = points.map((e) => e.y).reduce(math.min);
    double maxY = points.map((e) => e.y).reduce(math.max);
    if (minY == maxY) { minY -= 1; maxY += 1;
    }
    final yPad = (maxY - minY) * 0.08;
    minY -= yPad; maxY += yPad;
    // X range
    final minT = points.first.t;
    final maxT = points.last.t;
    double totalSec = maxT.difference(minT).inSeconds.toDouble();
    if (totalSec <= 0) totalSec = 1.0;

    // horizontal grid + y labels
    const yDiv = 4;
    for (int i = 0; i <= yDiv; i++) {
      final ty = chart.top + chart.height * (1 - i / yDiv);
      canvas.drawLine(Offset(chart.left, ty), Offset(chart.right, ty), axis);

      final val = minY + (maxY - minY) * (i / yDiv);
      final digits = ((maxY - minY) > 10) ? 0 : 2;
      tp.text = TextSpan(text: '${val.toStringAsFixed(digits)} $unit', style: labelStyle);
      tp.layout();
      tp.paint(canvas, Offset(chart.left - 8 - tp.width, ty - tp.height / 2));
    }

    // vertical grid + x labels
    const xDiv = 4;
    for (int i = 0; i <= xDiv; i++) {
      final tx = chart.left + chart.width * (i / xDiv);
      canvas.drawLine(Offset(tx, chart.top), Offset(tx, chart.bottom), axis);

      final sec = totalSec * (i / xDiv);
      final dt = minT.add(Duration(seconds: sec.round()));
      final label = _fmtTime(dt, spanSeconds: totalSec); // ใช้ spanSeconds ในการตัดสินใจรูปแบบ
      tp.text = TextSpan(text: label, style: labelStyle);
      tp.layout();
      tp.paint(canvas, Offset(tx - tp.width / 2, chart.bottom + 6));
    }

    // main line
    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final nx = chart.left + chart.width * (p.t.difference(minT).inSeconds / totalSec);
      final ny = chart.bottom - chart.height * ((p.y - minY) / (maxY - minY));
      if (i == 0) {
        path.moveTo(nx, ny);
      } else {
        path.lineTo(nx, ny);
      }
    }
    final linePaint = Paint()
      ..color = mainColor // <-- ใช้ mainColor ที่ส่งมา
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    // marker
    if (hitIndex != null && hitIndex! >= 0 && hitIndex! < points.length) {
      final p = points[hitIndex!];
      final nx = chart.left + chart.width * (p.t.difference(minT).inSeconds / totalSec);
      final ny = chart.bottom - chart.height * ((p.y - minY) / (maxY - minY));
      // vertical guideline
      final vline = Paint()
        ..color = mainColor.withOpacity(0.5) // <-- ใช้ mainColor
        ..strokeWidth = 1;
      canvas.drawLine(Offset(nx, chart.top), Offset(nx, chart.bottom), vline);

      // dot
      final dot = Paint()..color = mainColor; // <-- ใช้ mainColor
      canvas.drawCircle(Offset(nx, ny), 4, dot);
      canvas.drawCircle(Offset(nx, ny), 8, Paint()..color = dot.color.withOpacity(0.15));
      // tooltip
      final tooltip = '${p.y.toStringAsFixed(2)} $unit\n${_fmtTime(p.t, spanSeconds: totalSec)}';
      const pad = 8.0;
      final textPainter = TextPainter(
        text: TextSpan(
          text: tooltip,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
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

      final r = RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, boxW, boxH), const Radius.circular(8));
      final bg = Paint()..color = Colors.black.withOpacity(0.8);
      canvas.drawRRect(r, bg);
      textPainter.paint(canvas, Offset(bx + pad, by + pad));
    }
  }

  // ✅ ปรับ fmtTime: ให้ 15D/30D แสดงเวลา HH:00
  String _fmtTime(DateTime dt, {required double spanSeconds}) {
    final daySec = const Duration(days: 1).inSeconds;
    final hourSec = const Duration(hours: 1).inSeconds;

    if (spanSeconds > 10 * daySec) { // > 10 days (15D, 30D)
      final dd = dt.day.toString().padLeft(2, '0');
      final mm = dt.month.toString().padLeft(2, '0');
      final yy = dt.year.toString().substring(2);
      final hh = dt.hour.toString().padLeft(2, '0'); 
      // เปลี่ยนเป็นรูปแบบ DD/MM/YY HH:00
      return '$dd/$mm/$yy $hh:00'; 
    } else if (spanSeconds > daySec * 2) { // > 2 days (7D)
      final dd = dt.day.toString().padLeft(2, '0');
      final mm = dt.month.toString().padLeft(2, '0');
      final hh = dt.hour.toString().padLeft(2, '0');
      return '$dd/$mm $hh:00'; // DD/MM HH:00
    } else if (spanSeconds > hourSec * 2) { // > 2 hours (1D)
      final hh = dt.hour.toString().padLeft(2, '0');
      final mn = dt.minute.toString().padLeft(2, '0');
      return '$hh:$mn'; // HH:MM
    } else { // short span (default mock)
      final hh = dt.hour.toString().padLeft(2, '0');
      final mn = dt.minute.toString().padLeft(2, '0');
      final ss = dt.second.toString().padLeft(2, '0');
      return '$hh:$mn:$ss'; // HH:MM:SS
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.points != points ||
      old.unit != unit || 
      old.hitIndex != hitIndex ||
      old.mainColor != mainColor; 
}