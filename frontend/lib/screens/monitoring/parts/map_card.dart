// lib/screens/monitoring/parts/map_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;

typedef Json = Map<String, dynamic>;

class MapCard extends StatelessWidget {
  final MapController mapController;
  final List<Json> items;
  final latlng.LatLng center;
  final Color border;
  final bool Function(Json) isOnline;
  final String? selectedId;
  final void Function(Json, List<Json>)? onMarkerTap;

  const MapCard({
    super.key,
    required this.mapController,
    required this.items,
    required this.center,
    required this.border,
    required this.isOnline,
    this.selectedId,
    this.onMarkerTap,
  });

  String? _idOf(Json row) {
    final meta = row['meta'];
    if (meta is Map &&
        meta['devEui'] is String &&
        (meta['devEui'] as String).isNotEmpty) {
      return meta['devEui'] as String;
    }
    if (row['devEui'] is String && (row['devEui'] as String).isNotEmpty) {
      return row['devEui'] as String;
    }
    return null;
  }

  /// เลือกสี marker ตาม flag ก่อน ถ้าไม่มี alarm ค่อย fallback ตาม online/offline
  Color _markerColor(Json row) {
    final rawFlag = (row['flags'] ?? row['flag'] ?? '').toString();

    if (rawFlag.isNotEmpty) {
      bool hasRed = false;    // digit == 1
      bool hasYellow = false; // digit == 2

      for (final ch in rawFlag.characters) {
        if (ch == '1') hasRed = true;
        if (ch == '2') hasYellow = true;
      }

      if (hasRed && hasYellow) {
        // ทั้ง 1 และ 2 → ส้ม
        return Colors.orange[700] ?? Colors.orange;
      } else if (hasRed) {
        // มี 1 อย่างเดียว → แดง
        return Colors.red[600]!;
      } else if (hasYellow) {
        // มี 2 อย่างเดียว → เหลือง
        return Colors.yellow[700] ?? Colors.yellow;
      }
      // ถ้าทุก digit เป็น 0 → ไม่มี alarm → ไปใช้สี online/offline ด้านล่าง
    }

    // ไม่มี flag หรือไม่มี alarm → ใช้สีตาม online/offline
    return isOnline(row) ? Colors.green[600]! : Colors.red[600]!;
  }

  @override
  Widget build(BuildContext context) {
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
        child: FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 18,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.mass.smart_city.smart_control',
            ),
            MarkerLayer(
              markers: items
                  .where((e) => e['lat'] is num && e['lng'] is num)
                  .map((e) {
                final color = _markerColor(e);
                final id = _idOf(e);
                final isSel = selectedId != null && id == selectedId;

                final double dotSize = isSel ? 24 : 20;
                final double boxSize = isSel ? 56 : 36;

                return Marker(
                  point: latlng.LatLng(
                    (e['lat'] as num).toDouble(),
                    (e['lng'] as num).toDouble(),
                  ),
                  width: boxSize,
                  height: boxSize,
                  alignment: Alignment.center,
                  child: _RippleMarker(
                    color: color,
                    enabled: isSel,
                    boxSize: boxSize,
                    dotSize: dotSize,
                    rippleMin: 20,
                    rippleMax: 48,
                    onTap: onMarkerTap == null
                        ? null
                        : () => onMarkerTap!(e, items),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _RippleMarker extends StatefulWidget {
  final Color color;
  final bool enabled;
  final double boxSize;
  final double dotSize;
  final double rippleMin;
  final double rippleMax;
  final VoidCallback? onTap;

  const _RippleMarker({
    required this.color,
    required this.enabled,
    required this.boxSize,
    required this.dotSize,
    required this.rippleMin,
    required this.rippleMax,
    this.onTap,
  });

  @override
  State<_RippleMarker> createState() => _RippleMarkerState();
}

class _RippleMarkerState extends State<_RippleMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.enabled) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant _RippleMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.enabled && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: widget.boxSize,
        height: widget.boxSize,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            return Stack(
              alignment: Alignment.center,
              children: [
                if (widget.enabled)
                  ...List.generate(3, (i) {
                    final t = ((_c.value + i / 3) % 1.0);
                    final size = widget.rippleMin +
                        t * (widget.rippleMax - widget.rippleMin);
                    final opacity = (1.0 - t).clamp(0.0, 1.0);
                    return Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.color.withOpacity(0.12 * opacity),
                        border: Border.all(
                          color: widget.color.withOpacity(0.30 * opacity),
                          width: 1.2,
                        ),
                      ),
                    );
                  }),
                Container(
                  width: widget.dotSize,
                  height: widget.dotSize,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withOpacity(0.35),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.16),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
