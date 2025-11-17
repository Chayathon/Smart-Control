import 'package:flutter/material.dart';

/// Reusable Primary Button with consistent styling
class Button extends StatelessWidget {
  const Button({
    Key? key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.isLoading = false,
    this.isFullWidth = true,
    this.padding,
    this.borderRadius = 12,
    this.fontSize = 16,
    this.height = 48,
  }) : super(key: key);

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isLoading;
  final bool isFullWidth;
  final EdgeInsets? padding;
  final double borderRadius;
  final double fontSize;
  final double height;

  @override
  Widget build(BuildContext context) {
    final buttonChild = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              color: foregroundColor ?? Colors.white,
              strokeWidth: 2,
            ),
          )
        : Row(
            mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: fontSize + 4),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          );

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? Colors.blue,
          foregroundColor: foregroundColor ?? Colors.white,
          disabledBackgroundColor: Colors.grey[300],
          disabledForegroundColor: Colors.grey[600],
          padding:
              padding ?? EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          elevation: 0,
        ),
        child: buttonChild,
      ),
    );
  }
}

/// Secondary Button with outlined style
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    Key? key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.borderColor,
    this.foregroundColor,
    this.isFullWidth = true,
    this.padding,
    this.borderRadius = 12,
    this.fontSize = 16,
    this.height = 48,
  }) : super(key: key);

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final Color? borderColor;
  final Color? foregroundColor;
  final bool isFullWidth;
  final EdgeInsets? padding;
  final double borderRadius;
  final double fontSize;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: foregroundColor ?? Colors.blue,
          side: BorderSide(color: borderColor ?? Colors.blue, width: 2),
          padding:
              padding ?? EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        child: Row(
          mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: fontSize + 4),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

/// Text Button with minimal styling
class TextButton2 extends StatelessWidget {
  const TextButton2({
    Key? key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.foregroundColor,
    this.fontSize = 14,
  }) : super(key: key);

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final Color? foregroundColor;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: foregroundColor ?? Colors.blue,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 4),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
