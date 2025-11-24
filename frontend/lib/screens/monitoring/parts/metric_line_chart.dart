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

  /// ✅ เริ่มต้นที่ 1D
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          // พื้นหลังแบบ gradient บาง ๆ ให้ดู modern ขึ้น
          gradient: const LinearGradient(
            colors: [
              Color(0xFFF4F7FB),
              Color(0xFFFFFFFF),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 10),
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
                children: [
                  // icon + title
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          mainColor.withOpacity(0.85),
                          mainColor.withOpacity(0.45),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: mainColor.withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.show_chart_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title หลัก
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                            color: Colors.black87,
                            letterSpacing: .1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // 🔹 ลบคำว่า "Historical trend" ออกแล้ว
                        Text(
                          unit.isNotEmpty
                              ? '$metricTitle ($unit)'
                              : metricTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildTimeRangeSelector(mainColor),
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
                          fontWeight: FontWeight.w500,
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
                            const EdgeInsets.fromLTRB(12, 10, 16, 16),
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

  /// ปุ่มเลือกช่วงเวลาแบบ segmented control (เวอร์ชันลื่น ๆ แบบ “แถบเลื่อน”)
  Widget _buildTimeRangeSelector(Color mainColor) {
    // ใช้ list ให้ index คงที่
    final entries = <MapEntry<HistorySpan, String>>[
      const MapEntry(HistorySpan.day1, '1D'),
      const MapEntry(HistorySpan.day7, '7D'),
      const MapEntry(HistorySpan.day15, '15D'),
      const MapEntry(HistorySpan.day30, '30D'),
    ];

    final selectedIndex =
        entries.indexWhere((e) => e.key == _selectedSpan).clamp(0, entries.length - 1);
    final count = entries.length;

    double _alignX(int index) {
      if (count <= 1) return 0;
      // -1.0 (ซ้ายสุด) → +1.0 (ขวาสุด)
      return -1.0 + (2.0 * index / (count - 1));
    }

    return Container(
      width: 200, // กำหนดความกว้างให้คงที่หน่อย จะได้เลื่อนนิ่ม
      height: 32,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 🔹 แถบไฮไลต์ที่เลื่อนซ้ายขวา
          AnimatedAlign(
            alignment: Alignment(_alignX(selectedIndex), 0),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: FractionallySizedBox(
              widthFactor: 1.0 / count,
              heightFactor: 1.0,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    colors: [
                      mainColor,
                      mainColor.withOpacity(0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          // 🔹 แถว label + tap area
          Row(
            children: entries.asMap().entries.map((entry) {
              final index = entry.key;
              final span = entry.value.key;
              final label = entry.value.value;
              final isSelected = span == _selectedSpan;

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (_selectedSpan == span) return;
                    setState(() {
                      _selectedSpan = span;
                      _hitIndex = null;
                    });
                  },
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        letterSpacing: .3,
                        color: isSelected
                            ? Colors.white
                            : Colors.black54,
                      ),
                      child: Text(label),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
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
        return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true);
      }
      if (v is String && v.isNotEmpty) {
        return DateTime.parse(v).toUtc();
      }
    } catch (_) {}
    return null;
  }

  /// แปลง row -> ค่า metric (ตอนนี้รองรับเฉพาะ dcV / dcA / dcW เท่านั้น)
  double? _valueForMetric(Json row, MetricKey metric) {
    dynamic raw;
    switch (metric) {
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
        // ❌ ไม่ใช้ oat ทำกราฟแล้ว → คืน null ไปเลย
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
    const left = 54.0, right = 12.0;
    final chartW = size.width - left - right;

    final minT = pts.first.t;
    final maxT = pts.last.t;
    double totalSec = maxT.difference(minT).inSeconds.toDouble();
    if (totalSec <= 0) totalSec = 1.0;

    final x = (localPos.dx - left).clamp(0, chartW);
    final sec = (x / chartW) * totalSec;
    final target = minT.add(Duration(seconds: sec.round()));

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

  // ===== Helpers label / unit / สี =====

  String _metricLabel(MetricKey m) {
    switch (m) {
      case MetricKey.dcV:
        return 'DC Voltage';
      case MetricKey.dcA:
        return 'DC Current';
      case MetricKey.dcW:
        return 'DC Power';
      case MetricKey.oat:
        // ไม่ใช้ทำกราฟแล้ว
        return 'Metric';
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
      case MetricKey.oat:
        // ไม่ใช้ทำกราฟแล้ว
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
      case MetricKey.oat:
        // ใช้สีเดียวกับ Voltage เผื่อ fallback
        return const Color(0xFF06B6D4);
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

    // พื้นหลัง chart เบา ๆ
    final bgPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white,
          const Color(0xFFEFF4FB),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(chart);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        chart.inflate(6),
        const Radius.circular(12),
      ),
      bgPaint,
    );

    final axis = Paint()
      ..color = Colors.grey[300]!.withOpacity(0.6)
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
    double totalSec = maxT.difference(minT).inSeconds.toDouble();
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
      final isMin = i == 0;
      final isMax = i == yDiv;

      tp.text = TextSpan(
        text: '${val.toStringAsFixed(digits)} $unit',
        style: labelStyle.copyWith(
          color: isMin || isMax
              ? Colors.black87
              : Colors.grey[600],
          fontWeight:
              isMin || isMax ? FontWeight.w700 : FontWeight.w500,
        ),
      );
      tp.layout();
      tp.paint(
        canvas,
        Offset(chart.left - 10 - tp.width, ty - tp.height / 2),
      );
    }

    // vertical grid + x labels
    const xDiv = 4;
    for (int i = 0; i <= xDiv; i++) {
      final tx = chart.left + chart.width * (i / xDiv);
      canvas.drawLine(
        Offset(tx, chart.top),
        Offset(tx, chart.bottom),
        axis..color = axis.color.withOpacity(0.5),
      );

      final sec = totalSec * (i / xDiv);
      final dt = minT.add(Duration(seconds: sec.round()));
      final label = _fmtTime(dt, spanSeconds: totalSec.toDouble());
      tp.text = TextSpan(
        text: label,
        style: labelStyle.copyWith(
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
      );
      tp.layout();
      tp.paint(
        canvas,
        Offset(tx - tp.width / 2, chart.bottom + 6),
      );
    }

    // main line + เก็บตำแหน่งจุดไว้ใช้วาด marker
    final path = Path();
    final areaPath = Path();
    final pointPositions = <Offset>[];

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final nx = chart.left +
          chart.width *
              (p.t.difference(minT).inSeconds / totalSec);
      final ny = chart.bottom -
          chart.height *
              ((p.y - minY) / (maxY - minY));

      final pos = Offset(nx, ny);
      pointPositions.add(pos);

      if (i == 0) {
        path.moveTo(nx, ny);
        areaPath.moveTo(nx, chart.bottom);
        areaPath.lineTo(nx, ny);
      } else {
        path.lineTo(nx, ny);
        areaPath.lineTo(nx, ny);
      }
    }
    // ปิด path สำหรับพื้นที่ด้านล่าง
    if (pointPositions.isNotEmpty) {
      final last = pointPositions.last;
      areaPath.lineTo(last.dx, chart.bottom);
      areaPath.close();
    }

    // วาดพื้นที่ใต้กราฟแบบ gradient
    final areaPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          mainColor.withOpacity(0.25),
          mainColor.withOpacity(0.02),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(chart)
      ..style = PaintingStyle.fill;
    canvas.drawPath(areaPath, areaPaint);

    // เงาเส้นบาง ๆ
    final shadowPath = Path.from(path)
      ..shift(const Offset(0, 2));
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.12)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(shadowPath, shadowPaint);

    // เส้นหลัก
    final linePaint = Paint()
      ..color = mainColor
      ..strokeWidth = 2.4
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
      canvas.drawCircle(pos, 3.7, markerOuter);
      canvas.drawCircle(pos, 2.4, markerInner);
    }

    // marker + tooltip ของจุดที่เลือก
    if (hitIndex != null &&
        hitIndex! >= 0 &&
        hitIndex! < points.length) {
      final p = points[hitIndex!];
      final nx = chart.left +
          chart.width *
              (p.t.difference(minT).inSeconds / totalSec);
      final ny = chart.bottom -
          chart.height *
              ((p.y - minY) / (maxY - minY));

      // เส้นแนวตั้ง
      final vline = Paint()
        ..color = mainColor.withOpacity(0.55)
        ..strokeWidth = 1.2;
      canvas.drawLine(
        Offset(nx, chart.top),
        Offset(nx, chart.bottom),
        vline,
      );

      // จุด highlight
      final dot = Paint()..color = mainColor;
      canvas.drawCircle(Offset(nx, ny), 4.2, dot);
      canvas.drawCircle(
        Offset(nx, ny),
        9,
        Paint()..color = dot.color.withOpacity(0.18),
      );

      // tooltip
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
      double bx = nx + 12;
      double by = ny - boxH - 10;
      if (bx + boxW > size.width) bx = nx - boxW - 12;
      if (by < 0) by = ny + 10;

      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(bx, by, boxW, boxH),
        const Radius.circular(10),
      );
      final bg = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.black.withOpacity(0.88),
            Colors.black.withOpacity(0.80),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(r.outerRect);
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
