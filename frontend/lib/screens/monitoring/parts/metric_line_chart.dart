// lib/screens/monitoring/parts/metric_line_chart.dart
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
  /// index ของจุดที่เลือก (นับจากข้อมูลทั้งหมดหลังกรองช่วงเวลาแล้ว)
  int? _hitIndexGlobal;

  /// เริ่มต้นที่ 1D
  HistorySpan _selectedSpan = HistorySpan.day1;

  /// ระดับซูม (1–6) แสดงเป็น x1, x2, ... x6
  int _zoomStep = 1;
  static const int _zoomStepMin = 1;
  static const int _zoomStepMax = 6;

  /// ตำแหน่ง center ของ window ซูม (0–1) อิงจากช่วงเวลา minT→maxT
  /// ค่าเริ่มต้น 1.0 = ช่วงท้ายสุด
  double _viewCenter = 1.0;

  @override
  Widget build(BuildContext context) {
    // ===== เตรียมข้อมูลสำหรับกราฟ (ทั้งหมดก่อนซูม) =====
    final allPoints = _buildPoints(
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

    // sync ค่า index ให้ไม่เกินจำนวนจุด
    if (allPoints.isEmpty) {
      _hitIndexGlobal = null;
    } else if (_hitIndexGlobal != null &&
        (_hitIndexGlobal! < 0 || _hitIndexGlobal! >= allPoints.length)) {
      _hitIndexGlobal = allPoints.length - 1;
    }

    // สร้าง window ซูม + mapping index global <-> บนจอ
    final zoomWindow = _makeZoomWindow(
      allPoints: allPoints,
      hitIndexGlobal: _hitIndexGlobal,
      zoomStep: _zoomStep,
      viewCenter: _viewCenter,
    );

    final visiblePoints = zoomWindow.viewPoints;
    final hitIndexVisible = zoomWindow.viewHitIndex;

    final totalCount = allPoints.length;

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
            // ===== Header: Title + ปุ่มช่วงเวลา + ปุ่มซูม =====
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
                  const SizedBox(width: 10),
                  _buildZoomControls(mainColor),
                ],
              ),
            ),
            const Divider(height: 1),

            // ===== ตัวกราฟ =====
            Expanded(
              child: visiblePoints.isEmpty
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
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (d) {
                            if (visiblePoints.isEmpty) return;
                            final hitLocal = _nearestIndex(
                              visiblePoints,
                              d.localPosition,
                              context,
                            );
                            if (hitLocal < 0 ||
                                hitLocal >=
                                    zoomWindow.globalIndices.length) {
                              return;
                            }
                            final global =
                                zoomWindow.globalIndices[hitLocal];
                            setState(() {
                              _hitIndexGlobal = global;
                              _viewCenter =
                                  _positionOfIndex(allPoints, global);
                            });
                          },
                          onHorizontalDragUpdate: (d) {
                            if (visiblePoints.isEmpty) return;
                            final render =
                                context.findRenderObject() as RenderBox?;
                            if (render == null) return;
                            final local =
                                render.globalToLocal(d.globalPosition);
                            final hitLocal = _nearestIndex(
                              visiblePoints,
                              local,
                              context,
                            );
                            if (hitLocal < 0 ||
                                hitLocal >=
                                    zoomWindow.globalIndices.length) {
                              return;
                            }
                            final global =
                                zoomWindow.globalIndices[hitLocal];
                            setState(() {
                              _hitIndexGlobal = global;
                              _viewCenter =
                                  _positionOfIndex(allPoints, global);
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                                12, 10, 16, 6),
                            child: _ChartCanvas(
                              points: visiblePoints,
                              unit: unit,
                              hitIndex: hitIndexVisible,
                              mainColor: mainColor,
                              span: _selectedSpan,
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // ===== แถบข้อมูลจุดด้านล่าง =====
            _buildBottomInfo(
              allPoints: allPoints,
              unit: unit,
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
                    _hitIndexGlobal = null;
                    _zoomStep = 1;
                    _viewCenter = 1.0;
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

  /// ปุ่มซูม x1..x6
  Widget _buildZoomControls(Color mainColor) {
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
          children: [
            _zoomIconButton(
              icon: Icons.remove_rounded,
              onTap: () {
                if (_zoomStep <= _zoomStepMin) return;
                setState(() {
                  _zoomStep--;
                });
              },
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Text(
                'x$_zoomStep',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: mainColor,
                ),
              ),
            ),
            _zoomIconButton(
              icon: Icons.add_rounded,
              onTap: () {
                if (_zoomStep >= _zoomStepMax) return;
                setState(() {
                  _zoomStep++;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _zoomIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Icon(
          icon,
          size: 16,
          color: Colors.grey[800],
        ),
      ),
    );
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

  /// แปลง index → ตำแหน่ง 0–1 ตามเวลา (ใช้ไว้กำหนด center ตอนแพนกราฟ)
  double _positionOfIndex(List<_Pt> pts, int index) {
    if (pts.isEmpty) return 1.0;
    final clamped = index.clamp(0, pts.length - 1);
    final minT = pts.first.t;
    final maxT = pts.last.t;
    int totalMs = maxT.difference(minT).inMilliseconds;
    if (totalMs <= 0) return 1.0;
    final t = pts[clamped].t;
    final pos =
        t.difference(minT).inMilliseconds / totalMs;
    return pos.clamp(0.0, 1.0);
  }

  /// UI แถบด้านล่าง: จำนวนจุด + จุดที่เลือก + ปุ่มเลื่อน
  Widget _buildBottomInfo({
    required List<_Pt> allPoints,
    required String unit,
  }) {
    final total = allPoints.length;
    final hasSelection = _hitIndexGlobal != null &&
        _hitIndexGlobal! >= 0 &&
        _hitIndexGlobal! < total;

    final _Pt? selectedPt =
        hasSelection ? allPoints[_hitIndexGlobal!] : null;

    String subtitle;
    if (hasSelection && selectedPt != null) {
      final idx = _hitIndexGlobal! + 1;
      subtitle = 'จุดที่เลือก: $idx / $total';
    } else {
      subtitle = 'ยังไม่ได้เลือกจุด';
    }

    String timeLabel;
    if (hasSelection && selectedPt != null) {
      timeLabel = _fmtTimeTooltip(selectedPt.t);
    } else if (total > 0) {
      timeLabel = 'แตะจุดบนกราฟ หรือใช้ปุ่มเลื่อนด้านขวา';
    } else {
      timeLabel = 'ยังไม่มีข้อมูลในช่วงเวลานี้';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F9FC),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          // pill แสดงจำนวนจุด
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
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
                  'จุดบนกราฟ $total',
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
          // ข้อมูลจุดที่เลือก
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // ปุ่มเลื่อนจุดก่อนหน้า / ถัดไป
          Row(
            children: [
              _navButton(
                icon: Icons.chevron_left_rounded,
                onTap: () {
                  if (allPoints.isEmpty) return;
                  setState(() {
                    if (!hasSelection) {
                      _hitIndexGlobal = allPoints.length - 1;
                    } else if (_hitIndexGlobal! > 0) {
                      _hitIndexGlobal = _hitIndexGlobal! - 1;
                    }
                    if (_hitIndexGlobal != null) {
                      _viewCenter = _positionOfIndex(
                        allPoints,
                        _hitIndexGlobal!,
                      );
                    }
                  });
                },
              ),
              const SizedBox(width: 4),
              _navButton(
                icon: Icons.chevron_right_rounded,
                onTap: () {
                  if (allPoints.isEmpty) return;
                  setState(() {
                    if (!hasSelection) {
                      _hitIndexGlobal = 0;
                    } else if (_hitIndexGlobal! <
                        allPoints.length - 1) {
                      _hitIndexGlobal = _hitIndexGlobal! + 1;
                    }
                    if (_hitIndexGlobal != null) {
                      _viewCenter = _positionOfIndex(
                        allPoints,
                        _hitIndexGlobal!,
                      );
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

  Widget _navButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 18,
            color: const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  /// เวลาใน tooltip (ใช้ทั้ง tooltip และบรรทัดล่าง)
  String _fmtTimeTooltip(DateTime dt) {
    switch (_selectedSpan) {
      case HistorySpan.day1:
        final dd = dt.day.toString().padLeft(2, '0');
        final mm = dt.month.toString().padLeft(2, '0');
        final hh = dt.hour.toString().padLeft(2, '0');
        final mn = dt.minute.toString().padLeft(2, '0');
        final ss = dt.second.toString().padLeft(2, '0');
        return '$dd/$mm $hh:$mn:$ss';
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
}

/// โครงสร้างผลลัพธ์ window ซูม
class _ZoomWindow {
  final List<_Pt> viewPoints;
  final List<int> globalIndices;
  final int? viewHitIndex;

  const _ZoomWindow({
    required this.viewPoints,
    required this.globalIndices,
    required this.viewHitIndex,
  });
}

/// คำนวณ window ซูมจาก allPoints + zoomStep + center
_ZoomWindow _makeZoomWindow({
  required List<_Pt> allPoints,
  required int? hitIndexGlobal,
  required int zoomStep,
  required double viewCenter,
}) {
  if (allPoints.isEmpty) {
    return const _ZoomWindow(
      viewPoints: [],
      globalIndices: [],
      viewHitIndex: null,
    );
  }

  // ไม่ซูม → แสดงทั้งหมด
  if (zoomStep <= 1) {
    final indices = List<int>.generate(allPoints.length, (i) => i);
    int? hit = hitIndexGlobal;
    if (hit != null &&
        (hit < 0 || hit >= allPoints.length)) {
      hit = null;
    }
    return _ZoomWindow(
      viewPoints: allPoints,
      globalIndices: indices,
      viewHitIndex: hit,
    );
  }

  final minT = allPoints.first.t;
  final maxT = allPoints.last.t;
  int totalMs = maxT.difference(minT).inMilliseconds;
  if (totalMs <= 0) {
    final indices = List<int>.generate(allPoints.length, (i) => i);
    return _ZoomWindow(
      viewPoints: allPoints,
      globalIndices: indices,
      viewHitIndex: hitIndexGlobal,
    );
  }

  // ถ้ามีจุดที่เลือก ให้ center ที่เวลาของจุดนั้น
  double center;
  if (hitIndexGlobal != null &&
      hitIndexGlobal >= 0 &&
      hitIndexGlobal < allPoints.length) {
    final t = allPoints[hitIndexGlobal].t;
    center =
        t.difference(minT).inMilliseconds / totalMs;
  } else {
    center = viewCenter;
  }
  center = center.clamp(0.0, 1.0);

  final windowFraction = 1.0 / zoomStep;
  final windowMs = (totalMs * windowFraction).toInt();
  final halfMs = (windowMs / 2).round();

  int centerMs = (totalMs * center).round();
  int startMs = centerMs - halfMs;
  int endMs = centerMs + halfMs;

  if (startMs < 0) {
    endMs -= startMs;
    startMs = 0;
  }
  if (endMs > totalMs) {
    startMs -= (endMs - totalMs);
    endMs = totalMs;
    if (startMs < 0) startMs = 0;
  }

  final startT = minT.add(Duration(milliseconds: startMs));
  final endT = minT.add(Duration(milliseconds: endMs));

  final vp = <_Pt>[];
  final gi = <int>[];
  int? viewHit;

  for (int i = 0; i < allPoints.length; i++) {
    final p = allPoints[i];
    if (p.t.isBefore(startT) || p.t.isAfter(endT)) continue;
    gi.add(i);
    vp.add(p);
    if (hitIndexGlobal != null && i == hitIndexGlobal) {
      viewHit = gi.length - 1;
    }
  }

  if (vp.isEmpty) {
    final indices = List<int>.generate(allPoints.length, (i) => i);
    return _ZoomWindow(
      viewPoints: allPoints,
      globalIndices: indices,
      viewHitIndex: hitIndexGlobal,
    );
  }

  return _ZoomWindow(
    viewPoints: vp,
    globalIndices: gi,
    viewHitIndex: viewHit,
  );
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

  const _ChartCanvas({
    required this.points,
    required this.unit,
    this.hitIndex,
    required this.mainColor,
    required this.span,
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

  _ChartPainter({
    required this.points,
    required this.unit,
    required this.hitIndex,
    required this.mainColor,
    required this.span,
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
          '${p.y.toStringAsFixed(2)} $unit\n${_fmtTimeTooltip(p.t)}';
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

  /// เวลาใน tooltip (ใช้ version day1 / 7D+)
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
      old.span != span;
}
