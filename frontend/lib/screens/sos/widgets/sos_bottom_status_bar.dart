import 'package:flutter/material.dart';

class SosBottomStatusBar extends StatelessWidget {
  final bool isOnline;
  final String requestStatus;

  final String currentName;
  final String currentExtension;

  const SosBottomStatusBar({
    super.key,
    required this.isOnline,
    required this.requestStatus,
    required this.currentName,
    required this.currentExtension,
  });

  @override
  Widget build(BuildContext context) {
    String statusLabel;
    Color statusColor;

    if (!isOnline) {
      statusLabel = 'Offline';
      statusColor = Colors.redAccent;
    } else if (requestStatus.toLowerCase().contains('timeout')) {
      statusLabel = 'Request timeout';
      statusColor = Colors.orangeAccent;
    } else {
      statusLabel = 'Online';
      statusColor = Colors.greenAccent;
    }

    return Container(
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF141E30),
            Color(0xFF243B55),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withOpacity(0.9),
                      blurRadius: 8,
                      spreadRadius: 0.5,
                    ),
                    BoxShadow(
                      color: statusColor.withOpacity(0.5),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                statusLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Container(
            width: 1,
            height: 22,
            color: Colors.white.withOpacity(0.14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 20,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Tooltip(
                    message: currentName,
                    waitDuration: const Duration(milliseconds: 500),
                    child: Text(
                      currentName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            children: [
              const Icon(
                Icons.call_outlined,
                size: 15,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                currentExtension,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
