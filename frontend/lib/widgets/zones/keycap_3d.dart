import 'package:flutter/material.dart';

class Keycap3D extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final Color bgColor;
  final Color fgColor;
  final VoidCallback onTap;

  const Keycap3D({
    super.key,
    this.label,
    this.icon,
    required this.bgColor,
    required this.fgColor,
    required this.onTap,
  });

  @override
  State<Keycap3D> createState() => _Keycap3DState();
}

class _Keycap3DState extends State<Keycap3D> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDarkKey = widget.bgColor.computeLuminance() < 0.5;

    final topLeft = _pressed ? Colors.black12 : Colors.white.withOpacity(0.9);
    final bottomRight = _pressed
        ? Colors.white.withOpacity(0.9)
        : Colors.black26;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        transform: Matrix4.identity()..translate(0.0, _pressed ? 2.0 : 0.0),
        decoration: BoxDecoration(
          color: widget.bgColor,
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _pressed
                ? [
                    widget.bgColor.withOpacity(0.95),
                    widget.bgColor.withOpacity(0.85),
                  ]
                : [
                    widget.bgColor.withOpacity(0.98),
                    widget.bgColor.withOpacity(0.92),
                  ],
          ),
          boxShadow: [
            BoxShadow(
              color: topLeft,
              offset: const Offset(-3, -3),
              blurRadius: 6,
            ),
            BoxShadow(
              color: bottomRight,
              offset: const Offset(3, 3),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
          border: Border.all(
            color: isDarkKey ? Colors.black12 : Colors.grey[200]!,
            width: 1,
          ),
        ),
        child: Center(
          child: widget.icon != null
              ? Icon(widget.icon, size: 24, color: widget.fgColor)
              : Text(
                  widget.label ?? '',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: widget.fgColor,
                  ),
                ),
        ),
      ),
    );
  }
}
