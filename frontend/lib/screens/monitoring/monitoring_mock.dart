// lib/screens/monitoring/monitoring_mock.dart
import 'package:flutter/material.dart';

/// ระบบหลักบน Monitoring
enum MonitoringKind { lighting, wirelessWave, wirelessSim }

/// AC Metrics (ไฟส่องสว่าง)
class LightingData {
  double acV;
  double acA;
  double acW;
  double acHz;
  double acKWh;
  bool online;           // สถานะ Online/Offline
  bool statusLighting;   // สั่งเปิด-ปิดไฟ

  LightingData({
    required this.acV,
    required this.acA,
    required this.acW,
    required this.acHz,
    required this.acKWh,
    required this.online,
    required this.statusLighting,
  });
}

/// DC Metrics (ไร้สาย)
class WirelessData {
  double dcV;
  double dcA;
  double dcW;         // หากไม่กำหนด จะคำนวนจาก V*A
  bool online;
  bool onAirTarget;

  WirelessData({
    required this.dcV,
    required this.dcA,
    double? dcW,
    required this.online,
    required this.onAirTarget,
  }) : dcW = dcW ?? (dcV * dcA);
}

/// อุปกรณ์ที่แสดงบน Monitoring
class MonitoringEntry {
  final MonitoringKind kind;
  final String id;
  final String name;
  final dynamic data;    // LightingData | WirelessData
  final double lat;
  final double lng;
  final DateTime updatedAt; // เวลาอัปเดตล่าสุด (mock)
  final int order;          // ลำดับ (จะคำนวนอีกครั้งในหน้าจอ)

  MonitoringEntry({
    required this.kind,
    required this.id,
    required this.name,
    required this.data,
    required this.lat,
    required this.lng,
    required this.updatedAt,
    required this.order,
  });

  MonitoringEntry copyWith({
    MonitoringKind? kind,
    String? id,
    String? name,
    dynamic data,
    double? lat,
    double? lng,
    DateTime? updatedAt,
    int? order,
  }) {
    return MonitoringEntry(
      kind: kind ?? this.kind,
      id: id ?? this.id,
      name: name ?? this.name,
      data: data ?? this.data,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      updatedAt: updatedAt ?? this.updatedAt,
      order: order ?? this.order,
    );
  }
}

/// --------------------------------------
/// Mock เริ่มต้น (จะมีการคำนวน order ในหน้าจออีกที)
/// --------------------------------------
final List<MonitoringEntry> monitoringMoukup = [
  // 1) ไฟส่องสว่าง
  MonitoringEntry(
    kind: MonitoringKind.lighting,
    id: 'LGT-001',
    name: 'ไฟส่องสว่าง เสา #1',
    data: LightingData(
      acV: 228.7,
      acA: 0.42,
      acW: 82.0,
      acHz: 50.0,
      acKWh: 12.6,
      online: true,
      statusLighting: true,
    ),
    lat: 13.658066189866496,
    lng: 100.66087462348625,
    updatedAt: DateTime.now().subtract(const Duration(minutes: 1, seconds: 12)),
    order: 0,
  ),

  // 2) ไร้สาย (คลื่น)
  MonitoringEntry(
    kind: MonitoringKind.wirelessWave,
    id: 'WAV-001',
    name: 'ไร้สาย (คลื่น) โหนด A',
    data: WirelessData(
      dcV: 12.1,
      dcA: 0.35,
      online: true,
      onAirTarget: false,
    ),
    lat: 13.657931824692616,
    lng: 100.66081497533779,
    updatedAt: DateTime.now().subtract(const Duration(minutes: 3, seconds: 20)),
    order: 0,
  ),

  // 3) ไร้สาย (ซิม)
  MonitoringEntry(
    kind: MonitoringKind.wirelessSim,
    id: 'SIM-001',
    name: 'ไร้สาย (ซิม) โหนด B',
    data: WirelessData(
      dcV: 11.8,
      dcA: 0.40,
      online: false,
      onAirTarget: true,
    ),
    lat: 13.657778529962464,
    lng: 100.6607566958419,
    updatedAt: DateTime.now().subtract(const Duration(minutes: 5, seconds: 5)),
    order: 0,
  ),
];
