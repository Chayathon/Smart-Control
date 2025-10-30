import 'package:flutter/material.dart';
import 'package:smart_control/widgets/lamp_tile.dart';

class ZonesPanel extends StatelessWidget {
  final List<dynamic> zones;
  final Color lampOnColor;
  final Color lampOffColor;

  const ZonesPanel({
    Key? key,
    required this.zones,
    required this.lampOnColor,
    required this.lampOffColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: zones.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.6,
      ),
      itemBuilder: (context, index) {
        final zone = zones[index];
        final isOn = (zone is Map && zone['status'] != null)
            ? zone['status']['stream_enabled'] ?? false
            : false;
        return LampTile(
          isOn: isOn,
          lampOnColor: lampOnColor,
          lampOffColor: lampOffColor,
          zone: 'โซน ${index + 1}',
          onTap: () {},
        );
      },
    );
  }
}
