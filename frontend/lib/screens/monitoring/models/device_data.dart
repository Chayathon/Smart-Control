import 'dart:convert';

// ฟังก์ชันแปลง JSON List เป็น List<DeviceData> (แม้ว่าตอนนี้เราจะใช้ decoder ใน ApiService แล้ว แต่เก็บไว้ก็ดี)
List<DeviceData> deviceDataListFromJson(String str) => 
    List<DeviceData>.from(json.decode(str).map((x) => DeviceData.fromJson(x)));

class DeviceData {
  final String? id; // _id
  final DateTime? timestamp;
  final String? name;
  final String? status;

  final double? lng;
  final double? lat;
  final int? rssi; 
  final double? snr;

  final double? acW;
  final double? acA;
  final double? acV;
  
  final int? battery;
  final int? lighting;
  final int? oat; 
  
  final Map<String, dynamic>? meta;

  DeviceData({
    this.id,
    this.timestamp,
    this.name,
    this.status,
    this.lng,
    this.lat,
    this.rssi,
    this.snr,
    this.acW,
    this.acA,
    this.acV,
    this.battery,
    this.lighting,
    this.oat,
    this.meta,
  });

  factory DeviceData.fromJson(Map<String, dynamic> json) {
    // Helper function สำหรับการดึงค่าจาก MongoDB format 
    String? extractMongoId(dynamic data) {
      if (data is Map && data.containsKey('\$oid')) {
        return data['\$oid'] as String?;
      }
      return null;
    }

    DateTime? extractMongoDate(dynamic data) {
      if (data is Map && data.containsKey('\$date')) {
        return DateTime.tryParse(data['\$date'] as String? ?? '');
      }
      if (data is String) {
        return DateTime.tryParse(data);
      }
      return null;
    }

    return DeviceData(
      id: extractMongoId(json['_id']) ?? json['_id'] as String?,
      timestamp: extractMongoDate(json['timestamp']),
      name: json['name'] as String?,
      status: json['status'] as String?,

      lng: (json['lng'] as num?)?.toDouble(),
      lat: (json['lat'] as num?)?.toDouble(),
      rssi: json['rssi'] as int?,
      snr: (json['snr'] as num?)?.toDouble(),
      
      acW: (json['acW'] as num?)?.toDouble(),
      acA: (json['acA'] as num?)?.toDouble(),
      acV: (json['acV'] as num?)?.toDouble(),

      battery: json['battery'] as int?,
      lighting: json['lighting'] as int?,
      oat: json['oat'] as int?,

      meta: json['meta'] as Map<String, dynamic>?,
    );
  }
}