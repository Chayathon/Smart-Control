import 'package:flutter/material.dart';

class SosCallStatusHeader extends StatelessWidget {
  final int callStateIndex; // 0 idle,1 dialing,2 ringing,3 inCall,4 ended
  final String statusText;

  const SosCallStatusHeader({
    super.key,
    required this.callStateIndex,
    required this.statusText,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData stateIcon;

    switch (callStateIndex) {
      case 0:
        color = Colors.grey;
        stateIcon = Icons.pause_circle_filled_rounded;
        break;
      case 1:
        color = Colors.blue;
        stateIcon = Icons.phone_forwarded_rounded;
        break;
      case 2:
        color = Colors.orange;
        stateIcon = Icons.ring_volume_rounded;
        break;
      case 3:
        color = Colors.green;
        stateIcon = Icons.call_rounded;
        break;
      default:
        color = Colors.red;
        stateIcon = Icons.call_end_rounded;
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF141E30),
            Color(0xFF243B55),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text(
            'สถานะการโทร',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  colors: [
                    color.withOpacity(0.95),
                    _darken(color, 0.12),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.18),
                  width: 1,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(
                      stateIcon,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Text(
                      statusText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Color _darken(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    final hslDark =
        hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}
