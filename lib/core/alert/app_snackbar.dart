import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AppSnackbar {
  static void error(String title, String message, {VoidCallback? onClose}) {
    Get.snackbar(
      title,
      message,
      icon: const Icon(Icons.error_outline, color: Colors.white),
      backgroundColor: Colors.redAccent.withOpacity(0.9),
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(12),
      borderRadius: 12,
      duration: const Duration(seconds: 3),
      isDismissible: true,
      snackStyle: SnackStyle.FLOATING,
      mainButton: TextButton(
        onPressed: onClose ?? () => Get.back(),
        child: const Text(
          "X",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  static void success(String title, String message, {VoidCallback? onClose}) {
    Get.snackbar(
      title,
      message,
      icon: const Icon(Icons.check_circle_outline, color: Colors.white),
      backgroundColor: Colors.green.withOpacity(0.9),
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(12),
      borderRadius: 12,
      duration: const Duration(seconds: 3),
      isDismissible: true,
      snackStyle: SnackStyle.FLOATING,
      mainButton: TextButton(
        onPressed: onClose ?? () => Get.back(),
        child: const Text(
          "X",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  static void info(String title, String message, {VoidCallback? onClose}) {
    Get.snackbar(
      title,
      message,
      icon: const Icon(Icons.info_outline, color: Colors.white),
      backgroundColor: Colors.blueAccent.withOpacity(0.9),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
      borderRadius: 12,
      duration: const Duration(seconds: 3),
      isDismissible: true,
      snackStyle: SnackStyle.FLOATING,
      mainButton: TextButton(
        onPressed: onClose ?? () => Get.back(),
        child: const Text(
          "X",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
