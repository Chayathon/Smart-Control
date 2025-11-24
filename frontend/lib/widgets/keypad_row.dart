import 'package:flutter/material.dart';
import 'keycap_3d.dart';

class KeypadRow extends StatelessWidget {
  final List<String> keys;
  final void Function(String key) onKey;

  const KeypadRow({super.key, required this.keys, required this.onKey});

  @override
  Widget build(BuildContext context) {
    final Map<String, IconData> iconMap = {
      'volume': Icons.volume_up_outlined,
      'add': Icons.add,
      'remove': Icons.remove,
      'power': Icons.power_settings_new,
      'enter': Icons.keyboard_return,
      'clear': Icons.backspace_outlined,
    };

    Color bgForKey(String key) {
      if (key == 'enter') return Colors.blue[600]!;
      if (key == 'clear') return Colors.red[500]!;
      return Colors.white;
    }

    Color fgForKey(String key) {
      if (key == 'enter' || key == 'clear') return Colors.white;
      return Colors.grey[800]!;
    }

    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: keys.map((key) {
          final isIcon = iconMap.containsKey(key);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Keycap3D(
                label: isIcon ? null : key,
                icon: isIcon ? iconMap[key] : null,
                bgColor: bgForKey(key),
                fgColor: fgForKey(key),
                onTap: () => onKey(key),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
