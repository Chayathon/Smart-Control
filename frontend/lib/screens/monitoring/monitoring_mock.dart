// lib/screens/monitoring/monitoring_mock.dart
import 'package:flutter/foundation.dart';
import 'dart:math' as math; 
import 'package:flutter/material.dart';

enum MonitoringKind { lighting, wirelessWave, wirelessSim }

/// metric key ที่ฝั่ง MiniStats/กราฟใช้งาน
enum MetricKey { acV, acA, acW, acHz, acKWh, dcV, dcA, dcW }

// ******************************************************
// * ส่วนที่เพิ่ม: การกำหนดช่วงเวลาประวัติ
// ******************************************************
enum HistorySpan { day1, day7, day15, day30 }

Duration durationOfSpan(HistorySpan s) {
  switch (s) {
    case HistorySpan.day1: return const Duration(days: 1);
    case HistorySpan.day7: return const Duration(days: 7);
    case HistorySpan.day15: return const Duration(days: 15);
    case HistorySpan.day30: return const Duration(days: 30);
  }
}

// ******************************************************
// * ข้อมูลประวัติ
// ******************************************************

// จุดข้อมูลประวัติ
class HistoryPoint {
  final DateTime ts;
  final double? acV, acA, acW, acHz, acKWh;
  final double? dcV, dcA, dcW;
  HistoryPoint({
    required this.ts,
    this.acV, this.acA, this.acW, this.acHz, this.acKWh,
    this.dcV, this.dcA, this.dcW,
  });
}

// สร้าง mock series สมูธอิงค่าปัจจุบัน
List<HistoryPoint> historyFor(MonitoringEntry e, {HistorySpan? span, int points = 60}) {
  // หากไม่ได้กำหนด span จะใช้ค่าเริ่มต้น 1.5 ชั่วโมง (90 วินาทีต่อจุด * 60 จุด)
  final totalDuration = span == null 
    ?
    const Duration(seconds: 90 * (60 - 1))
    : durationOfSpan(span);
  
  if (points <= 1) return [];
  // คำนวณช่วงห่างของจุดข้อมูลใหม่ เพื่อให้ได้ 60 จุดครอบคลุมช่วงเวลาทั้งหมด
  final secondsPerPoint = totalDuration.inSeconds / (points - 1);
  
  final now = DateTime.now();
  final baseTs = now.subtract(totalDuration);

  // ฟังก์ชันสุ่มค่าที่ผันผวนเล็กน้อย
  double noise(double v, int i, double f) =>
      v + math.sin(i / f) * (v.abs() * 0.02) + math.cos(i / (f * 0.7)) * (v.abs() * 0.01);
  return List<HistoryPoint>.generate(points, (i) {
    // ใช้ secondsPerPoint ที่คำนวณใหม่
    final ts = baseTs.add(Duration(seconds: (secondsPerPoint * i).round())); 
    if (e.kind == MonitoringKind.lighting) {
      final d = e.data as LightingData;
      return HistoryPoint(
        ts: ts,
        acV:   noise(d.acV,   i, 5),
        acA:   noise(d.acA,   i, 6),
        acW:   noise(d.acW,   
            i, 7),
        acHz:  noise(d.acHz,  i, 9),
        acKWh: d.acKWh + i * 0.01 * (secondsPerPoint / 90), // ปรับ KWh ตามช่วงเวลา
      );
    } else {
      final d = e.data as WirelessData;
      return HistoryPoint(
        ts: ts,
        dcV: noise(d.dcV, i, 5),
        dcA: noise(d.dcA, i, 6),
    
        dcW: noise(d.dcW, i, 7),
      );
    }
  });
}

// ฟังก์ชันดึงค่า double จาก HistoryPoint สำหรับ MetricKey ที่กำหนด
double? valueForMetric(HistoryPoint p, MetricKey m) {
  switch (m) {
    case MetricKey.acV:   return p.acV;
    case MetricKey.acA:   return p.acA;
    case MetricKey.acW:   return p.acW;
    case MetricKey.acHz:  return p.acHz;
    case MetricKey.acKWh: return p.acKWh;
    case MetricKey.dcV:   return p.dcV;
    case MetricKey.dcA:   return p.dcA;
    case MetricKey.dcW:   return p.dcW;
  }
}

// ******************************************************
// * คลาสข้อมูลหลัก
// ******************************************************

class MonitoringEntry {
  final String id;
  final int order;
  final MonitoringKind kind;
  final double lat;
  final double lng;
  final DateTime updatedAt;
  final Object data;
  MonitoringEntry({
    required this.id,
    required this.order,
    required this.kind,
    required this.lat,
    required this.lng,
    required this.updatedAt,
    required this.data,
  });
  MonitoringEntry copyWith({
    String? id,
    int? order,
    MonitoringKind? kind,
    double? lat,
    double? lng,
    DateTime? updatedAt,
    Object? data,
  }) {
    return MonitoringEntry(
      id: id ?? this.id,
      order: order ?? this.order,
      kind: kind ?? this.kind,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      updatedAt: updatedAt ?? this.updatedAt,
  
      data: data ?? this.data,
    );
  }
}

class LightingData {
  bool online;
  double acV;
  double acA;
  double acW;
  double acHz;
  double acKWh;
  bool statusLighting;
  LightingData({
    required this.online,
    required this.acV,
    required this.acA,
    required this.acW,
    required this.acHz,
    required this.acKWh,
    required this.statusLighting,
  });
}

class WirelessData {
  bool online;
  double dcV;
  double dcA;
  double dcW;
  bool onAirTarget;
  WirelessData({
    required this.online,
    required this.dcV,
    required this.dcA,
    required this.dcW,
    required this.onAirTarget,
  });
}

class MonitoringMock {
  static final List<MonitoringEntry> items = <MonitoringEntry>[
    MonitoringEntry(
      id: 'lighting-1',
      order: 1,
      kind: MonitoringKind.lighting,
      lat: 13.658066189866496,
      lng: 100.66087462348625,
      updatedAt: DateTime.now(),
      data: LightingData(
        online: true,
        acV: 220.6,
        acA: 0.81,
        acW: 173.0,
        acHz: 50.0,
        acKWh: 12.4,
        statusLighting: true,
      ),
    ),
    MonitoringEntry(
      id: 'wireless-wave-1',
      order: 2,
      kind: MonitoringKind.wirelessWave,
      lat: 13.657931824692616,
      lng: 100.66081497533779,
      updatedAt: DateTime.now(),
      data: WirelessData(
        online: true,
        dcV: 12.4,
        dcA: 0.34,
        dcW: 4.2,
        onAirTarget: true,
      ),
    ),
    MonitoringEntry(
      id: 'wireless-sim-1',
      order: 3,
      kind: MonitoringKind.wirelessSim,
      lat: 13.657778529962464,
      lng: 100.6607566958419,
      updatedAt: DateTime.now(),
      data: WirelessData(
        online: false,
        dcV: 11.8,
        dcA: 0.21,
        dcW: 2.5,
        onAirTarget: false,
      ),
    ),
  ];
  static final ValueNotifier<List<MonitoringEntry>> itemsNotifier =
      ValueNotifier<List<MonitoringEntry>>(List<MonitoringEntry>.from(items));

  static MonitoringEntry?
  findById(Object? id) {
    if (id == null) return null;
    final target = id.toString();
    try {
      return items.firstWhere((e) => e.id == target);
    } catch (_) {
      return null;
    }
  }

  static void updateLightingStatus(Object? id, bool next) {
    final entry = findById(id);
    if (entry == null) return;
    if (entry.kind != MonitoringKind.lighting) return;

    final d = entry.data as LightingData;
    d.statusLighting = next;
    final idx = items.indexWhere((x) => x.id == entry.id);
    if (idx == -1) return;

    items[idx] = entry.copyWith(updatedAt: DateTime.now(), data: d);
    itemsNotifier.value = List<MonitoringEntry>.from(items);
  }

  static void toggleLighting(Object? id) {
    final entry = findById(id);
    if (entry == null || entry.kind != MonitoringKind.lighting) return;
    final d = entry.data as LightingData;
    updateLightingStatus(id, !d.statusLighting);
  }

  // ฟังก์ชันสำหรับดึงข้อมูล Sparkline (10 จุด)
  static List<double> getSparklineData(MetricKey metric, String id) {
    final entry = findById(id);
    if (entry == null) return const [];
    
    // ใช้ historyFor เดียวกันกับกราฟหลัก แต่กำหนดจำนวนจุดน้อยลง (10 จุด)
    // ไม่ต้องกำหนด span เพราะ Sparkline ควรแสดงช่วงเวลาสั้นๆ (ค่า default 1.5 ชม.)
    final history = historyFor(entry, points: 60);
    // ดึงเฉพาะค่า double ออกมา
    return history
        .map((p) => valueForMetric(p, metric))
        .whereType<double>()
        .toList();
  }
}

// ******************************************************
// * ฟังก์ชันช่วยเหลือ (ไม่เปลี่ยนแปลงและเป็นชุดเดียวในไฟล์)
// ******************************************************
String metricLabel(MetricKey k) {
  switch (k) {
    case MetricKey.acV:   return 'AC Voltage';
    case MetricKey.acA:   return 'AC Current';
    case MetricKey.acW:   return 'AC Power';
    case MetricKey.acHz:  return 'AC Frequency';
    case MetricKey.acKWh: return 'AC Energy';
    case MetricKey.dcV:   return 'DC Voltage';
    case MetricKey.dcA:   return 'DC Current';
    case MetricKey.dcW:   return 'DC Power';
  }
}

String unitOf(MetricKey k) {
  switch (k) {
    case MetricKey.acV: return 'V';
    case MetricKey.acA: return 'A';
    case MetricKey.acW: return 'W';
    case MetricKey.acHz:return 'Hz';
    case MetricKey.acKWh:return 'kWh';
    case MetricKey.dcV: return 'V';
    case MetricKey.dcA: return 'A';
    case MetricKey.dcW: return 'W';
  }
}

// ฟังก์ชันกำหนดสีตาม MetricKey 
Color metricColor(MetricKey k) {
  switch (k) {
    case MetricKey.acV:   return Colors.green.shade600; 
    case MetricKey.acA:   return Colors.blue.shade600;  
    case MetricKey.acW:   return Colors.deepOrange.shade600; 
    case MetricKey.acHz:  return Colors.purple.shade600; 
    case MetricKey.acKWh: return Colors.yellow.shade800; 
    case MetricKey.dcV:   return Colors.cyan.shade600;
    case MetricKey.dcA:   return Colors.teal.shade600;
    case MetricKey.dcW:   return Colors.red.shade600;
    default:              return Colors.grey;
  }
}

/// ป้ายชื่ออุปกรณ์ (✅ แก้ WirelessSim เป็น 'ระบบไร้สาย(ซิม)')
String entryLabel(MonitoringEntry e) {
  String kindText;
  switch (e.kind) {
    case MonitoringKind.lighting: kindText = 'ระบบแสงสว่าง'; break;
    case MonitoringKind.wirelessWave: kindText = 'ระบบไร้สาย(คลื่น)'; break;
    case MonitoringKind.wirelessSim:  kindText = 'ระบบไร้สาย(ซิม)'; break; // 🛑 แก้ไขเป็น (ซิม)
  }
  return '${e.order} $kindText'; // รูปแบบ: [เลขลำดับ] [ชื่ออุปกรณ์]
}