// lib/screens/monitoring/parts/notification_mock.dart

import 'package:flutter/material.dart';

/// คลาสสำหรับรวม Mock Data ของ Notification
class NotificationMock {
  
  // =======================================================================
  // *** CONSTANTS: ชื่อโหนด (UPPER_SNAKE_CASE) ***
  // =======================================================================
  
  // ชื่ออุปกรณ์/โหนด (สำหรับใช้ใน Title และ Subtitle)
  static const String NODE_LIGHTING_1 = 'LIGHTING-1'; 
  static const String NODE_WIRELESS_WAVE_1 = 'WIRELESS-WAVE-1'; 
  static const String NODE_WIRELESS_SIM_1 = 'WIRELESS-SIM-1'; 
  
  // =======================================================================
  // *** CONSTANTS: รายละเอียดค่า AC ***
  // =======================================================================
  static const String METRIC_VOLTAGE = 'แรงดัน AC';
  static const String METRIC_CURRENT = 'กระแส AC';
  static const String METRIC_POWER = 'กำลังไฟ AC';
  static const String METRIC_FREQUENCY = 'ความถี่ AC';
  static const String METRIC_ENERGY = 'พลังงานสะสม AC';

  // =======================================================================
  // *** CONSTANTS: สถานะค่า ***
  // =======================================================================
  static const String STATUS_HIGH_EXCEEDED = 'สูงเกินกำหนด';
  static const String STATUS_LOW_EXCEEDED = 'ต่ำเกินกำหนด';
  static const String STATUS_LOW_UNUSUAL = 'ต่ำผิดปกติ';
  
  // =======================================================================
  // *** CONSTANTS: ICON ***
  // =======================================================================
  static const IconData ICON_CRITICAL_ALERT = Icons.warning_amber; 
  
  /// Mock Data สำหรับ Notification Center (AC Metrics ทั้งหมด และ Online/Offline)
  static List<Map<String, dynamic>> get rawMockData {
    final DateTime now = DateTime.now();
    DateTime ago(Duration duration) => now.subtract(duration);
    
    // ตั้งค่าตัวแปรสำหรับเวลาที่กำหนด
    final Duration oneDay = const Duration(days: 1);
    final Duration twoDays = const Duration(days: 2);
    final Duration eightDays = const Duration(days: 8);

    return [ 
      
      // =======================================================================
      // *** 1. CRITICAL ALERTS: วันนี้ (Today) - < 60 นาที (แสดงเป็น X ว./น.) ***
      // =======================================================================

      // AC Voltage (V) Alerts
      {
        'title': '${NODE_LIGHTING_1} ${METRIC_VOLTAGE} ${STATUS_HIGH_EXCEEDED}',
        'subtitle': 'เหตุการณ์: โหนด ${NODE_LIGHTING_1} แรงดัน 250.0V สูงกว่าค่าที่กำหนด',
        'icon': ICON_CRITICAL_ALERT, 
        'timestamp': ago(const Duration(seconds: 5)),
        'color': Colors.red, 
        'isRead': false, 
      },
      {
        'title': '${NODE_LIGHTING_1} ${METRIC_VOLTAGE} ${STATUS_LOW_EXCEEDED}',
        'subtitle': 'เหตุการณ์: โหนด ${NODE_LIGHTING_1} แรงดัน 180.0V ต่ำกว่าค่าที่กำหนด',
        'icon': ICON_CRITICAL_ALERT, 
        'timestamp': ago(const Duration(seconds: 10)),
        'color': Colors.grey, 
        'isRead': false, 
      },

      // AC Current (A) Alerts
      {
        'title': '${NODE_LIGHTING_1} ${METRIC_CURRENT} ${STATUS_HIGH_EXCEEDED}',
        'subtitle': 'เหตุการณ์: โหนด ${NODE_LIGHTING_1} กระแส 5.0A สูงกว่าค่าที่กำหนด',
        'icon': ICON_CRITICAL_ALERT, 
        'timestamp': ago(const Duration(minutes: 5)), // 5 น.
        'color': Colors.red, 
        'isRead': false, 
      },
      {
        'title': '${NODE_LIGHTING_1} ${METRIC_CURRENT} ${STATUS_LOW_EXCEEDED}',
        'subtitle': 'เหตุการณ์: โหนด ${NODE_LIGHTING_1} กระแส 0.0A ต่ำกว่าค่าที่กำหนด',
        'icon': ICON_CRITICAL_ALERT, 
        'timestamp': ago(const Duration(minutes: 10)), // 10 น.
        'color': Colors.grey, 
        'isRead': false, 
      },

      // AC Power (W) Alerts
      {
        'title': '${NODE_LIGHTING_1} ${METRIC_POWER} ${STATUS_HIGH_EXCEEDED}',
        'subtitle': 'เหตุการณ์: โหนด ${NODE_LIGHTING_1} กำลังไฟ 500.0W สูงกว่าค่าที่กำหนด',
        'icon': ICON_CRITICAL_ALERT, 
        'timestamp': ago(const Duration(minutes: 25)), // 25 น.
        'color': Colors.red, 
        'isRead': false, 
      },
      {
        'title': '${NODE_LIGHTING_1} ${METRIC_POWER} ${STATUS_LOW_EXCEEDED}',
        'subtitle': 'เหตุการณ์: โหนด ${NODE_LIGHTING_1} กำลังไฟ 0.0W ต่ำกว่าค่าที่กำหนด',
        'icon': ICON_CRITICAL_ALERT, 
        'timestamp': ago(const Duration(minutes: 50)), // 50 น.
        'color': Colors.grey, 
        'isRead': false, 
      },
      
      // ONLINE/OFFLINE ALERTS: 1 ชม. ถึง < 24 ชม. (แสดงเป็น X ชม.)
      {
        'title': '${NODE_LIGHTING_1} ออฟไลน์', 
        'subtitle': 'เหตุการณ์: โหนด ${NODE_LIGHTING_1} ขาดการเชื่อมต่อ',
        'icon': Icons.wifi_off_outlined,
        'timestamp': ago(const Duration(hours: 1)), // 1 ชม.
        'color': Colors.red, 
        'isRead': false, 
      },
      {
        'title': '${NODE_WIRELESS_WAVE_1} ออฟไลน์', 
        'subtitle': 'เหตุการณ์: โหนด ${NODE_WIRELESS_WAVE_1} ขาดการเชื่อมต่อ',
        'icon': Icons.wifi_off_outlined,
        'timestamp': ago(const Duration(hours: 2, minutes: 30)), // 2 ชม.
        'color': Colors.red, 
        'isRead': false, 
      },
      {
        'title': '${NODE_WIRELESS_SIM_1} ออฟไลน์', 
        'subtitle': 'เหตุการณ์: โหนด ${NODE_WIRELESS_SIM_1} ขาดการเชื่อมต่อ',
        'icon': Icons.wifi_off_outlined,
        'timestamp': ago(const Duration(hours: 4)), // 4 ชม.
        'color': Colors.red, 
        'isRead': false, 
      },
      
      // ONLINE RECOVERY (สีเขียว)
      {
        'title': '${NODE_LIGHTING_1} กลับมาออนไลน์', 
        'subtitle': 'เหตุการณ์: โหนด ${NODE_LIGHTING_1} กลับมาเชื่อมต่อสำเร็จ',
        'icon': Icons.wifi_outlined,
        'timestamp': ago(const Duration(hours: 8)), // 8 ชม.
        'color': Colors.green, 
        'isRead': false, 
      },
      {
        'title': '${NODE_WIRELESS_WAVE_1} กลับมาออนไลน์', 
        'subtitle': 'เหตุการณ์: โหนด ${NODE_WIRELESS_WAVE_1} กลับมาเชื่อมต่อสำเร็จ',
        'icon': Icons.wifi_outlined,
        'timestamp': ago(const Duration(hours: 12)), // 12 ชม.
        'color': Colors.green, 
        'isRead': false, 
      },
      {
        'title': '${NODE_WIRELESS_SIM_1} กลับมาออนไลน์', 
        'subtitle': 'เหตุการณ์: โหนด ${NODE_WIRELESS_SIM_1} กลับมาเชื่อมต่อสำเร็จ',
        'icon': Icons.wifi_outlined,
        'timestamp': ago(const Duration(hours: 23)), // 23 ชม.
        'color': Colors.green, 
        'isRead': false, 
      },
      
      // =======================================================================
      // *** 2. DATE SEPARATOR DEMO: สัปดาห์นี้และก่อนหน้า (แสดง HH:mm น.) ***
      // =======================================================================
      
      // AC Current (A) Alerts: HIGH (สีแดง) -> เมื่อวาน
      {
        'title': '${NODE_LIGHTING_1} ${METRIC_CURRENT} ${STATUS_HIGH_EXCEEDED}',
        'subtitle': 'เหตุการณ์: โหนด ${NODE_LIGHTING_1} กระแส 5.0A สูงกว่าค่าที่กำหนด',
        'icon': ICON_CRITICAL_ALERT, 
        'timestamp': ago(oneDay + const Duration(hours: 2)), // > 24 ชม. (แสดง HH:mm น.)
        'color': Colors.red, 
        'isRead': false, 
      },
      // AC Power (W) Alerts: HIGH (สีแดง) -> 2 วันก่อน
      {
        'title': '${NODE_LIGHTING_1} ${METRIC_POWER} ${STATUS_HIGH_EXCEEDED}',
        'subtitle': 'เหตุการณ์: โหนด ${NODE_LIGHTING_1} กำลังไฟ 500.0W สูงกว่าค่าที่กำหนด',
        'icon': ICON_CRITICAL_ALERT, 
        'timestamp': ago(twoDays + const Duration(hours: 1)), // > 2 วัน (แสดง HH:mm น.)
        'color': Colors.red, 
        'isRead': false, 
      },
      // AC Frequency (Hz) Alerts: HIGH (สีแดง) -> 8 วันก่อน (Earlier)
      {
        'title': '${NODE_LIGHTING_1} ${METRIC_FREQUENCY} ${STATUS_HIGH_EXCEEDED}',
        'subtitle': 'เหตุการณ์: โหนด ${NODE_LIGHTING_1} ความถี่ 51.5Hz สูงกว่าค่าที่กำหนด',
        'icon': ICON_CRITICAL_ALERT, 
        'timestamp': ago(eightDays + const Duration(hours: 1)), // > 8 วัน (แสดง HH:mm น.)
        'color': Colors.red, 
        'isRead': false, 
      },
    ];
  }
}