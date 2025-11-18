import 'package:flutter/material.dart';

/// Dialog Action Model
class DialogAction {
  final String label;
  final VoidCallback? onPressed;
  final Color? textColor;
  final ButtonStyle? style;
  final bool dismissOnPressed;
  final bool isBold;
  final dynamic result;

  DialogAction({
    required this.label,
    this.onPressed,
    this.textColor,
    this.style,
    this.dismissOnPressed = true,
    this.isBold = false,
    this.result,
  });
}

/// Reusable Dialog with consistent styling
class CustomDialog {
  /// แสดง Alert Dialog แบบพื้นฐาน
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required String message,
    List<DialogAction>? actions,
    Widget? content,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: content ?? Text(message),
          backgroundColor: Colors.white,
          actions: actions?.map((action) {
            return TextButton(
              onPressed: () {
                if (action.onPressed != null) {
                  action.onPressed!();
                }
                if (action.dismissOnPressed) {
                  Navigator.of(context).pop(action.result);
                }
              },
              style: action.style,
              child: Text(
                action.label,
                style: TextStyle(
                  color: action.textColor,
                  fontWeight: action.isBold
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  /// แสดง Confirmation Dialog (ยืนยัน/ยกเลิก)
  static Future<bool?> showConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = "ยืนยัน",
    String cancelText = "ยกเลิก",
    Color? confirmColor,
    Color? cancelColor,
    Color? textColor,
    bool fontBold = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          backgroundColor: Colors.white,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(
                  cancelColor ?? Colors.grey[200],
                ),
              ),
              child: Text(
                cancelText,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(
                  confirmColor ?? Colors.blue[50],
                ),
              ),
              child: Text(
                confirmText,
                style: TextStyle(
                  color: textColor ?? Colors.blue,
                  fontWeight: fontBold ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// แสดง Input Dialog (รับข้อมูล)
  static Future<String?> showInput({
    required BuildContext context,
    required String title,
    String? message,
    String? initialValue,
    String? hint,
    String confirmText = "ยืนยัน",
    String cancelText = "ยกเลิก",
    TextInputType? keyboardType,
    int? maxLines,
    String? Function(String?)? validator,
  }) {
    final controller = TextEditingController(text: initialValue);
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message != null) ...[Text(message), SizedBox(height: 16)],
                TextFormField(
                  controller: controller,
                  keyboardType: keyboardType,
                  maxLines: maxLines ?? 1,
                  decoration: InputDecoration(
                    hintText: hint,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: validator,
                  autofocus: true,
                ),
              ],
            ),
          ),
          backgroundColor: Colors.white,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(Colors.grey[200]),
              ),
              child: Text(
                cancelText,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? true) {
                  Navigator.of(context).pop(controller.text);
                }
              },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(Colors.blue[50]),
              ),
              child: Text(
                confirmText,
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
