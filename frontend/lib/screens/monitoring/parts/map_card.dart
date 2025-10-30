import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;

import '../monitoring_mock.dart';

class MapCard extends StatelessWidget {
  final MapController mapController;
  final List<MonitoringEntry> items;
  final latlng.LatLng center;
  final Color border;
  final void Function(MonitoringEntry, List<MonitoringEntry>)? onMarkerTap;
  final bool Function(MonitoringEntry) isOnline;
  final String? selectedId;

  const MapCard({
    super.key,
    required this.mapController,
    required this.items,
    required this.center,
    required this.border,
    required this.isOnline,
    this.onMarkerTap,
    this.selectedId,
  });

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
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', // ไม่ใช้ a/b/c subdomains
              userAgentPackageName: 'com.mass.smart_city.smart_control',      // <-- ใส่ package จริงของแอป
              // หากไม่ได้ตั้ง package name ใน pubspec ให้ใช้ headers แทน:
              // additionalOptions: const {'User-Agent': 'SmartControl/1.0 (contact: you@example.com)'},
            ),
            MarkerLayer(
              markers: items.map((e) {
                final color = isOnline(e) ? Colors.green[600]! : Colors.red[600]!;
                final isSel = selectedId != null && e.id == selectedId;

                // ขยายจุดให้ใหญ่ขึ้น (ปกติ 20, เลือก 24)
                final double dotSize = isSel ? 24 : 20;
                // พื้นที่ ripple (ปกติ 36, เลือก 56)
                final double boxSize = isSel ? 56 : 36;

                return Marker(
                  point: latlng.LatLng(e.lat, e.lng),
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
                    onTap: onMarkerTap == null ? null : () => onMarkerTap!(e, items),
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

/// วงคลื่นกระจายรอบๆ จุด (รองรับปรับขนาด)
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
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
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
                if (widget.enabled) ...List.generate(3, (i) {
                  final t = ((_c.value + i / 3) % 1.0);
                  final size = widget.rippleMin + t * (widget.rippleMax - widget.rippleMin);
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
                // จุดกลาง
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
