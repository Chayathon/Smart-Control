import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'mini_stats.dart'; // ใช้ MetricKey จากไฟล์นี้

typedef Json = Map<String, dynamic>;

/// ช่วงเวลาประวัติที่เลือกบนกราฟ
enum HistorySpan { day1, day7, day15, day30 }

class MetricLineChart extends StatefulWidget {
  /// history ของ devEui ที่เลือก (มาจาก MonitoringScreen._historyForId)
  /// ***ควรส่ง "ประวัติทั้งหมดของโหนดนั้น" เข้ามา แล้วให้กราฟกรองเองตามช่วงเวลา***
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
  /// index ของจุดที่เลือก (อิงจาก list "หลังซูมแล้ว" = pts)
  int? _hitIndex;

  /// เริ่มต้นที่ 1D
  HistorySpan _selectedSpan = HistorySpan.day1;

  /// ระดับซูม (แสดงเป็น x1, x2, x4, x6, x8)
  /// ค่ามาก = ซูมเข้า (เห็นช่วงเวลาสั้นลง → จุดห่างกันมากขึ้น)
  static const List<double> _zoomLevels = [1, 2, 4, 6, 8];
  int _zoomIndex = 0; // 0 = x1 (ไม่ซูม)
  double get _zoomFactor => _zoomLevels[_zoomIndex];

  /// ตำแหน่งเลื่อน (pan) 0.0 = ซ้ายสุด (เก่าสุด), 1.0 = ขวาสุด (ใหม่สุด)
  double _pan = 1.0;

  /// index เริ่มต้นของ window ที่กำลังแสดงอยู่ (อิงจาก list ที่กรองวันแล้ว = basePoints)
  int _visibleStartIndex = 0;

  @override
  Widget build(BuildContext context) {
    // ===== เตรียมข้อมูลสำหรับกราฟ =====
    // 1) กรองตามวัน + limit จำนวนจุด -> list "ฐาน" ทั้งหมดสำหรับ span นี้
    final basePoints = _buildPoints(
      widget.history,
      widget.metric,
      _selectedSpan,
    );
    final totalPoints = basePoints.length; // ✅ จำนวนจุดทั้งหมดหลังกรองวันแล้ว

    // 2) นำไป apply zoom + pan -> list ที่เอาไปวาดบนจอ
    final pts = _applyZoom(basePoints); // 🔍 ตัดช่วงตามระดับซูม + pan

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
            // ===== Header: Title + ปุ่มช่วงเวลา + Zoom =====
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
                        // subtitle = ชื่อ metric + หน่วย
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
                  const SizedBox(width: 8),
                  _buildZoomControl(mainColor), // 🔍 ปุ่มซูม
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
                        final size = render.size;

                        // ถ้า zoom > x1 → ใช้ drag เพื่อ pan ซ้าย–ขวา
                        if (_zoomFactor > 1.0) {
                          const double left = 54.0;
                          const double right = 12.0;
                          final chartW = size.width - left - right;
                          if (chartW <= 0) return;

                          final dx = d.primaryDelta ?? d.delta.dx;
                          // drag ไปทางขวา → ดูข้อมูลเก่าขึ้น → pan ลดลง
                          final deltaPan = -(dx / chartW);

                          setState(() {
                            _pan = (_pan + deltaPan).clamp(0.0, 1.0);
                            _hitIndex =
                                null; // เลื่อนกราฟแล้ว เคลียร์ highlight ก่อน
                          });
                        } else {
                          // ถ้าไม่ zoom → drag เพื่อเลื่อน highlight เหมือนเดิม
                          final local =
                              render.globalToLocal(d.globalPosition);
                          final hit =
                              _nearestIndex(pts, local, context);
                          setState(() => _hitIndex = hit);
                        }
                      },
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(12, 10, 16, 16),
                        child: _ChartCanvas(
                          points: pts,
                          unit: unit,
                          hitIndex: _hitIndex,
                          mainColor: mainColor,
                          span: _selectedSpan, // 🔹 ส่ง span เข้าไป
                          totalPoints: totalPoints, // ✅ ใหม่
                          visibleStartIndex:
                              _visibleStartIndex, // ✅ ใหม่
                        ),
                      ),
                    ),
            ),

            // ===== แถบด้านล่าง: แสดงจุด + ปุ่มเลื่อน < > =====
            if (pts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                // ให้สูงคงที่กัน “เด้งกราฟ”
                child: SizedBox(
                  height: 56,
                  child: _buildPointNavigator(
                    pts,
                    totalPoints, // ✅ ส่ง "จำนวนจุดทั้งหมดหลังกรองวัน" เข้าไป
                    unit,
                    mainColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// ปุ่มเลือกช่วงเวลาแบบ segmented control
  Widget _buildTimeRangeSelector(Color mainColor) {
    final options = <HistorySpan, String>{
      HistorySpan.day1: '1D',
      HistorySpan.day7: '7D',
      HistorySpan.day15: '15D',
      HistorySpan.day30: '30D',
    };

    return Material(
      color: Colors.transparent,
      child: Container(
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
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                hoverColor: Colors.transparent,
                onTap: () {
                  setState(() {
                    _selectedSpan = span;
                    _hitIndex = null;
                    _zoomIndex = 0; // เปลี่ยนช่วงเวลา → reset เป็น x1
                    _pan = 1.0; // และเลื่อนไปดูข้อมูลล่าสุด
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [
                              mainColor,
                              mainColor.withOpacity(0.7),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isSelected ? null : Colors.white,
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .3,
                      color: isSelected ? Colors.white : Colors.black54,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// ปุ่ม Zoom แบบ segmented (x1 / x2 / x4 / x6 / x8)
  Widget _buildZoomControl(Color mainColor) {
    // label ของแต่ละระดับซูม ตาม _zoomLevels
    final labels = _zoomLevels.map((z) => 'x${z.toStringAsFixed(0)}').toList();

    return Material(
      color: Colors.transparent,
      child: Container(
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(labels.length, (index) {
            final label = labels[index];
            final isSelected = index == _zoomIndex;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                hoverColor: Colors.transparent,
                onTap: () {
                  setState(() {
                    _zoomIndex = index;
                    _hitIndex = null;

                    // ถ้าเป็น x1 → ดูเต็มช่วงและเลื่อนไปท้ายสุด
                    if (_zoomFactor <= 1.0) {
                      _pan = 1.0;
                    } else {
                      _pan = _pan.clamp(0.0, 1.0);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [
                              mainColor,
                              mainColor.withOpacity(0.7),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isSelected ? null : Colors.white,
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .3,
                      color: isSelected ? Colors.white : Colors.black54,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ===== แถบด้านล่าง: แสดงจุด + ปุ่มเลื่อน < > =====
  /// pts         = list จุดที่ "แสดงบนกราฟตอนนี้" (หลังซูมแล้ว)
  /// totalPoints = จำนวนจุดทั้งหมดหลังกรองวันแล้ว (basePoints.length)
  Widget _buildPointNavigator(
    List<_Pt> pts,
    int totalPoints,
    String unit,
    Color mainColor,
  ) {
    final totalAll = totalPoints; // ✅ จำนวนจุดทั้งหมดสำหรับ span นี้

    final hasHit =
        _hitIndex != null && _hitIndex! >= 0 && _hitIndex! < pts.length;

    int idxLocal = 0; // index ในหน้าจอ (pts)
    _Pt? pt;
    if (hasHit) {
      idxLocal = _hitIndex!.clamp(0, pts.length - 1);
      pt = pts[idxLocal];
    }

    // globalIndex = ลำดับจริงใน "จุดทั้งหมด" (หลังกรองวันแล้ว)
    int globalIndex = 0;
    if (hasHit && totalAll > 0) {
      globalIndex =
          (_visibleStartIndex + idxLocal).clamp(0, totalAll - 1);
    }

    // ขนาด window ปัจจุบัน + ขอบซ้าย-ขวาใน index global
    final visibleCount = pts.length;
    final maxStart = (totalAll - visibleCount).clamp(0, totalAll);
    final canPan = _zoomFactor > 1.0 && totalAll > visibleCount;

    final windowStart = _visibleStartIndex.clamp(
      0,
      totalAll == 0 ? 0 : totalAll - 1,
    );
    final windowEnd = (windowStart + visibleCount - 1).clamp(
      0,
      totalAll == 0 ? 0 : totalAll - 1,
    );

    // ปรับเงื่อนไขให้ดู "จุดทั้งหมด" ไม่ใช่แค่ในหน้าจอ
    final canGoPrev = hasHit && globalIndex > 0;
    final canGoNext =
        (hasHit && globalIndex < totalAll - 1) ||
            (!hasHit && totalAll > 0);

    final titleText =
        hasHit ? '${pt!.y.toStringAsFixed(2)} $unit' : 'ยังไม่ได้เลือกจุด';

    // ✅ subtitle แสดง "จุดที่ X/Y • เวลา"
    final subtitleText = hasHit && totalAll > 0
        ? 'จุดที่ ${globalIndex + 1}/$totalAll • ${_formatTimeForNavigator(pt!.t)}'
        : 'แตะจุดบนกราฟ หรือใช้ปุ่มเลื่อนด้านขวา';

    // ✅ แสดงเป็น "ลำดับ / จำนวนทั้งหมด" ตามที่ต้องการ (ด้านขวา)
    final indexLabel = (hasHit && totalAll > 0)
        ? '${globalIndex + 1}/$totalAll'
        : '0/$totalAll';

    // helper เล็ก ๆ สำหรับปุ่มลูกศรสไตล์ฟองกลม + เงา
    Widget navButton({
      required IconData icon,
      required bool enabled,
      required VoidCallback onTap,
    }) {
      final bgColor = enabled ? Colors.white : const Color(0xFFE5E7EB);
      final iconColor =
          enabled ? const Color(0xFF334155) : const Color(0xFF9CA3AF);
      final shadows = enabled
          ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ]
          : <BoxShadow>[];

      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: enabled ? onTap : null,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(999),
              boxShadow: shadows,
            ),
            child: Icon(
              icon,
              size: 18,
              color: iconColor,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F9FC),
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Row(
        children: [
          // === ชิปด้านซ้าย: "จุดบนกราฟ N" แบบฟอง gradient ===
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFE0ECFF),
                  Color(0xFFD6F4FF),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  child: const Icon(
                    Icons.scatter_plot_rounded,
                    size: 12,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  // ✅ ใช้จำนวน "ทั้งหมด" ไม่ใช่เฉพาะที่เห็นบนจอ
                  'จุดบนกราฟ $totalAll',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // === ข้อความกลาง 2 บรรทัด ===
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  titleText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: hasHit
                        ? const Color(0xFF0F172A)
                        : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitleText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // === ปุ่มเลื่อน + index ===
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ปุ่มก่อนหน้า
              navButton(
                icon: Icons.chevron_left_rounded,
                enabled: canGoPrev,
                onTap: () {
                  if (!canGoPrev) return;
                  setState(() {
                    if (!hasHit || totalAll <= 0) return;

                    // จุดใหม่ใน global index
                    final newGlobal =
                        (globalIndex - 1).clamp(0, totalAll - 1);

                    if (canPan && newGlobal < windowStart) {
                      // ต้องเลื่อน window ไปทางซ้ายให้ครอบ newGlobal
                      final newStart =
                          newGlobal.clamp(0, maxStart);
                      _pan = maxStart > 0
                          ? newStart / maxStart
                          : 0.0;
                      _hitIndex = newGlobal - newStart;
                    } else {
                      // ยังอยู่ใน window เดิม → เลื่อนใน pts อย่างเดียว
                      _hitIndex =
                          (idxLocal - 1).clamp(0, pts.length - 1);
                    }
                  });
                },
              ),

              const SizedBox(width: 4),

              // index
              Text(
                indexLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(width: 4),

              // ปุ่มถัดไป
              navButton(
                icon: Icons.chevron_right_rounded,
                enabled: canGoNext,
                onTap: () {
                  if (!canGoNext) return;
                  setState(() {
                    if (!hasHit) {
                      // ยังไม่เลือก → เลือกจุดแรกของ window ปัจจุบัน
                      _hitIndex = 0;
                      return;
                    }
                    if (totalAll <= 0) return;

                    final newGlobal =
                        (globalIndex + 1).clamp(0, totalAll - 1);

                    if (canPan && newGlobal > windowEnd) {
                      // ต้องเลื่อน window ไปทางขวาให้ครอบ newGlobal
                      final newStart = (newGlobal -
                              (visibleCount - 1))
                          .clamp(0, maxStart);
                      _pan = maxStart > 0
                          ? newStart / maxStart
                          : 0.0;
                      _hitIndex = newGlobal - newStart;
                    } else {
                      // ยังอยู่ใน window เดิม → เลื่อนใน pts อย่างเดียว
                      _hitIndex =
                          (idxLocal + 1).clamp(0, pts.length - 1);
                    }
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimeForNavigator(DateTime dt) {
    // ใช้รูปแบบใกล้เคียง tooltip แต่ย่อให้สั้นลง
    switch (_selectedSpan) {
      case HistorySpan.day1:
        final hh = dt.hour.toString().padLeft(2, '0');
        final mn = dt.minute.toString().padLeft(2, '0');
        final ss = dt.second.toString().padLeft(2, '0');
        return '$hh:%02d:%02d'
            .replaceFirst('%02d', mn)
            .replaceFirst('%02d', ss);
      case HistorySpan.day7:
      case HistorySpan.day15:
      case HistorySpan.day30:
        final dd = dt.day.toString().padLeft(2, '0');
        final mm = dt.month.toString().padLeft(2, '0');
        final hh = dt.hour.toString().padLeft(2, '0');
        final mn = dt.minute.toString().padLeft(2, '0');
        return '$dd/$mm $hh:$mn';
    }
  }

  // ===== สร้างจุดกราฟจาก history จริง + กรองตามช่วงเวลา + limit จำนวนจุด =====
  List<_Pt> _buildPoints(
    List<Json> history,
    MetricKey metric,
    HistorySpan span,
  ) {
    if (history.isEmpty) return const [];

    // 1) แปลงเป็นคู่ (ts, value) และ sort ตามเวลา
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

    if (filtered.length <= 2) {
      return filtered;
    }

    // 3) ถ้าจุดเยอะเกินไป ให้ down-sample
    const int maxPoints = 360; // ปรับได้ตามต้องการ
    if (filtered.length <= maxPoints) {
      return filtered;
    }

    final step = (filtered.length / maxPoints).ceil();
    final reduced = <_Pt>[];
    for (int i = 0; i < filtered.length; i += step) {
      reduced.add(filtered[i]);
    }
    return reduced;
  }

  /// ตัดช่วงข้อมูลตามระดับซูม + ตำแหน่ง pan
  ///
  /// - x1 = ทั้งหมดในช่วงเวลา (ไม่ตัด, pan = 1.0)
  /// - x2 = แสดง ~1/2 ของช่วงเวลา
  /// - x4 = แสดง ~1/4 ของช่วงเวลา
  /// - x6 = แสดง ~1/6 ของช่วงเวลา
  /// - x8 = แสดง ~1/8 ของช่วงเวลา
  ///
  /// _pan = 0.0 → ซ้ายสุด, 1.0 → ขวาสุด
  List<_Pt> _applyZoom(List<_Pt> pts) {
    // กรณีจุดน้อย หรือยังไม่ซูม → แสดงทั้งหมด
    if (pts.length <= 2 || _zoomFactor <= 1.0) {
      _visibleStartIndex = 0;
      return pts;
    }

    final total = pts.length;

    // ==== ช่วงเวลาเต็มทั้งหมด ====
    final minT = pts.first.t;
    final maxT = pts.last.t;
    int totalMs = maxT.difference(minT).inMilliseconds;
    if (totalMs <= 0) {
      _visibleStartIndex = 0;
      return pts;
    }

    // ==== ช่วงเวลาที่อยากเห็นตามระดับซูม ====
    int visibleMs = (totalMs / _zoomFactor).round();
    if (visibleMs <= 0) visibleMs = totalMs;

    final panClamped = _pan.clamp(0.0, 1.0);

    // center ตาม pan (0 = ซ้าย, 1 = ขวา)
    int centerOffsetMs = (totalMs * panClamped).round();
    var centerT = minT.add(Duration(milliseconds: centerOffsetMs));

    var startT = centerT.subtract(Duration(milliseconds: visibleMs ~/ 2));
    var endT = startT.add(Duration(milliseconds: visibleMs));

    // clamp ไม่ให้หลุดช่วงเวลา
    if (startT.isBefore(minT)) {
      startT = minT;
      endT = startT.add(Duration(milliseconds: visibleMs));
    }
    if (endT.isAfter(maxT)) {
      endT = maxT;
      startT = endT.subtract(Duration(milliseconds: visibleMs));
      if (startT.isBefore(minT)) startT = minT;
    }

    // ==== เลือกจุดที่อยู่ในช่วงเวลา [startT, endT] ====
    int firstIdx = -1;
    int lastIdx = -1;
    for (int i = 0; i < total; i++) {
      final t = pts[i].t;
      if (!t.isBefore(startT) && !t.isAfter(endT)) {
        if (firstIdx == -1) firstIdx = i;
        lastIdx = i;
      }
    }

    // ถ้ามีจุดในช่วงเวลา → ใช้ช่วงนี้
    if (firstIdx != -1 && lastIdx >= firstIdx) {
      _visibleStartIndex = firstIdx;
      return pts.sublist(firstIdx, lastIdx + 1);
    }

    // ==== Fallback: หากช่วงเวลานั้นไม่มีจุดเลย ====
    // ใช้ index window ให้มีอย่างน้อย 2 จุดเสมอ
    int visibleCount = (total / _zoomFactor).round();
    if (visibleCount < 2) visibleCount = 2;
    if (visibleCount > total) visibleCount = total;

    // center ประมาณจาก pan
    int approxCenterIndex = (panClamped * (total - 1)).round();
    int half = visibleCount ~/ 2;

    int startIndex = approxCenterIndex - half;
    int endIndex = startIndex + visibleCount;

    if (startIndex < 0) {
      endIndex -= startIndex;
      startIndex = 0;
    }
    if (endIndex > total) {
      startIndex -= (endIndex - total);
      endIndex = total;
      if (startIndex < 0) startIndex = 0;
    }

    _visibleStartIndex = startIndex;
    return pts.sublist(startIndex, endIndex);
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
        // ไม่ใช้ oat ทำกราฟแล้ว → คืน null
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
  final HistorySpan span;

  // ✅ ใหม่
  final int totalPoints;
  final int visibleStartIndex;

  const _ChartCanvas({
    required this.points,
    required this.unit,
    this.hitIndex,
    required this.mainColor,
    required this.span,
    required this.totalPoints,
    required this.visibleStartIndex,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ChartPainter(
        points: points,
        unit: unit,
        hitIndex: hitIndex,
        mainColor: mainColor,
        span: span,
        totalPoints: totalPoints,
        visibleStartIndex: visibleStartIndex,
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<_Pt> points;
  final String unit;
  final int? hitIndex;
  final Color mainColor;
  final HistorySpan span;

  // ✅ ใหม่
  final int totalPoints;
  final int visibleStartIndex;

  _ChartPainter({
    required this.points,
    required this.unit,
    required this.hitIndex,
    required this.mainColor,
    required this.span,
    required this.totalPoints,
    required this.visibleStartIndex,
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
          color:
              isMin || isMax ? Colors.black87 : Colors.grey[600],
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
      final label = _fmtTimeAxis(dt);
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
          chart.height * ((p.y - minY) / (maxY - minY));

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
    final shadowPath = Path.from(path)..shift(const Offset(0, 2));
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
          chart.height * ((p.y - minY) / (maxY - minY));

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

      // ✅ คำนวณ index global ของจุดนี้ (0-based)
      final safeTotal =
          totalPoints > 0 ? totalPoints : points.length;
      int globalIndex = visibleStartIndex + hitIndex!;
      if (globalIndex < 0) globalIndex = 0;
      if (globalIndex > safeTotal - 1) {
        globalIndex = safeTotal - 1;
      }

      // tooltip: เพิ่มบรรทัด "จุดที่ X/Y"
      final tooltip =
          'จุดที่ ${globalIndex + 1}/$safeTotal\n'
          '${p.y.toStringAsFixed(2)} $unit\n'
          '${_fmtTimeTooltip(p.t)}';

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

  // ==== formatting เวลา ====

  /// label ที่แกน X
  ///  - 1D  : HH:mm
  ///  - 7D+ : dd/MM
  String _fmtTimeAxis(DateTime dt) {
    switch (span) {
      case HistorySpan.day1:
        final hh = dt.hour.toString().padLeft(2, '0');
        final mn = dt.minute.toString().padLeft(2, '0');
        return '$hh:$mn';
      case HistorySpan.day7:
      case HistorySpan.day15:
      case HistorySpan.day30:
        final dd = dt.day.toString().padLeft(2, '0');
        final mm = dt.month.toString().padLeft(2, '0');
        return '$dd/$mm';
    }
  }

  /// เวลาใน tooltip
  ///  - 1D  : HH:mm:ss
  ///  - 7D+ : dd/MM/yy HH:mm:ss
  String _fmtTimeTooltip(DateTime dt) {
    switch (span) {
      case HistorySpan.day1:
        final hh = dt.hour.toString().padLeft(2, '0');
        final mn = dt.minute.toString().padLeft(2, '0');
        final ss = dt.second.toString().padLeft(2, '0');
        return '$hh:$mn:$ss';
      case HistorySpan.day7:
      case HistorySpan.day15:
      case HistorySpan.day30:
        final dd = dt.day.toString().padLeft(2, '0');
        final mm = dt.month.toString().padLeft(2, '0');
        final yy = dt.year.toString().substring(2);
        final hh = dt.hour.toString().padLeft(2, '0');
        final mn = dt.minute.toString().padLeft(2, '0');
        final ss = dt.second.toString().padLeft(2, '0');
        return '$dd/$mm/$yy $hh:$mn:$ss';
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.points != points ||
      old.unit != unit ||
      old.hitIndex != hitIndex ||
      old.mainColor != mainColor ||
      old.span != span ||
      old.totalPoints != totalPoints || // ✅ เช็ค field ใหม่
      old.visibleStartIndex != visibleStartIndex; // ✅
}
