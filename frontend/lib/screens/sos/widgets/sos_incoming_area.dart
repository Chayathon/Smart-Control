import 'package:flutter/material.dart';

class SosIncomingArea extends StatelessWidget {
  final bool hasIncoming;

  final String? incomingNumber;
  final String? incomingName;
  final bool incomingIsVideo;

  final bool isInVideoCall;
  final int callStateIndex; // 0..4

  final Animation<Offset>? answerBtnAnimation;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const SosIncomingArea({
    super.key,
    required this.hasIncoming,
    required this.incomingNumber,
    required this.incomingName,
    required this.incomingIsVideo,
    required this.isInVideoCall,
    required this.callStateIndex,
    required this.answerBtnAnimation,
    required this.onAccept,
    required this.onReject,
  });

  bool get _isRinging => callStateIndex == 2;
  bool get _isInCall => callStateIndex == 3;

  @override
  Widget build(BuildContext context) {
    if (hasIncoming) {
      final displayNumber = (incomingNumber ?? '').trim();
      final displayName = (incomingName ?? displayNumber).trim();
      final isVideo = incomingIsVideo;

      Widget answerButton = ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        onPressed: onAccept,
        icon: const Icon(Icons.call, size: 18),
        label: const Text(
          'รับสาย',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      );

      if (_isRinging && answerBtnAnimation != null) {
        answerButton = SlideTransition(
          position: answerBtnAnimation!,
          child: answerButton,
        );
      }

      return Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade700),
              ),
              child: Stack(
                children: [
                  _CenterVideoBlock(
                    icon: isVideo ? Icons.videocam : Icons.call,
                    line1: displayName,
                    line2: displayNumber,
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 120,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        answerButton,
                        const SizedBox(width: 18),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          onPressed: onReject,
                          icon: const Icon(Icons.call_end, size: 18),
                          label: const Text(
                            'วางสาย',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (isInVideoCall && _isInCall) {
      final displayNumber = (incomingNumber ?? '').trim();
      final displayName = (incomingName ?? displayNumber).trim();

      return Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade700),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.videocam,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade700),
            ),
            child: const _CenterVideoBlock(
              icon: Icons.videocam,
              line1: 'พื้นที่แสดงวิดีโอเมื่อมีสายเรียกเข้า',
              line2: 'เมื่อมีสาย SOS ระบบจะแสดงภาพที่นี่',
            ),
          ),
        ),
      ],
    );
  }
}

class _CenterVideoBlock extends StatelessWidget {
  final IconData icon;
  final String line1;
  final String? line2;

  const _CenterVideoBlock({
    required this.icon,
    required this.line1,
    this.line2,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.06),
              border: Border.all(
                color: Colors.white.withOpacity(0.35),
                width: 1,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 42),
          ),
          const SizedBox(height: 14),
          Text(
            line1,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          if (line2 != null && line2!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              line2!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
