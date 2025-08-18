import 'package:flutter/material.dart';

class LampTile extends StatefulWidget {
  final bool isOn;
  final Color lampOnColor;
  final Color lampOffColor;
  final VoidCallback onTap;
  final String zone;

  const LampTile({
    super.key,
    required this.isOn,
    required this.lampOnColor,
    required this.lampOffColor,
    required this.onTap,
    required this.zone,
  });

  @override
  State<LampTile> createState() => _LampTileState();
}

class _LampTileState extends State<LampTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800), // Fast for twinkling effect
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOutSine, // Smooth twinkling curve
      ),
    );
    if (widget.isOn) {
      _pulseController.repeat(reverse: true); // Start pulsing when active
    }
  }

  @override
  void didUpdateWidget(LampTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOn) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.value = 1.0; // Reset scale
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80, // Adjusted height for vertical layout
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white, // Fixed background color
        boxShadow: [
          BoxShadow(
            color: Colors.grey[300]!.withOpacity(0.2),
            blurRadius: widget.isOn ? 8 : 5,
            spreadRadius: widget.isOn ? 1.5 : 0.5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: widget.isOn ? _pulseAnimation.value : 1.0,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.isOn
                              ? widget.lampOnColor
                              : widget.lampOffColor,
                          boxShadow: widget.isOn
                              ? [
                                  BoxShadow(
                                    color: widget.lampOnColor.withOpacity(0.5),
                                    blurRadius: 6,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : [],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: Text(
                    widget.zone,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700]!,
                      fontSize: 12, // Slightly larger for vertical layout
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
