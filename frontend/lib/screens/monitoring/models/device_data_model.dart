class DeviceData {
  final String id;
  final DateTime timestamp;
  final String name;
  final double? acW;
  final double? acV;
  final double? acA;
  final double? lighting;
  final double? oat;
  final int? battery;
  final double? snr;
  final double? rssi;
  final String? status;
  final double? lat;
  final double? lng;
  final String? appId;
  final String? devEui;
  final String? event;

  DeviceData({
    required this.id,
    required this.timestamp,
    required this.name,
    this.acW,
    this.acV,
    this.acA,
    this.lighting,
    this.oat,
    this.battery,
    this.snr,
    this.rssi,
    this.status,
    this.lat,
    this.lng,
    this.appId,
    this.devEui,
    this.event,
  });

  factory DeviceData.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] ?? {};
    return DeviceData(
      id: json['_id'] ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      name: json['name'] ?? '',
      acW: (json['acW'] as num?)?.toDouble(),
      acV: (json['acV'] as num?)?.toDouble(),
      acA: (json['acA'] as num?)?.toDouble(),
      lighting: (json['lighting'] as num?)?.toDouble(),
      oat: (json['oat'] as num?)?.toDouble(),
      battery: json['battery'],
      snr: (json['snr'] as num?)?.toDouble(),
      rssi: (json['rssi'] as num?)?.toDouble(),
      status: json['status'],
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      appId: meta['appId'],
      devEui: meta['devEui'],
      event: meta['event'],
    );
  }
}
