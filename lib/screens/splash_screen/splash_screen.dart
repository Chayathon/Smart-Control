import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:smart_control/routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    // 🔹 Animation Controller จะวิ่งจาก 0 → 1 ภายใน 5 วิ
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..forward();

    // 🔹 ไปหน้า Home เมื่อ animation จบ
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Get.offAllNamed(AppRoutes.home);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🔹 Lottie Logo
            Lottie.asset(
              'assets/lottie/audio.json',
              width: 500,
              height: 500,
              repeat: true,
            ),

            const SizedBox(height: 20),

            // 🔹 App Name
            const Text(
              "Smart Control",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),

            const SizedBox(height: 10),

            // 🔹 Typewriter Effect
            AnimatedTextKit(
              animatedTexts: [
                TypewriterAnimatedText(
                  "เปลี่ยนบ้านธรรมดาให้กลายเป็น Smart Living",
                  textStyle: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                  speed: const Duration(milliseconds: 100),
                ),
                TypewriterAnimatedText(
                  "ควบคุมทุกสิ่งได้ง่ายดาย แค่ปลายนิ้วสัมผัส",
                  textStyle: const TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                  speed: const Duration(milliseconds: 100),
                ),
              ],
              totalRepeatCount: 1,
              pause: const Duration(milliseconds: 500),
              displayFullTextOnTap: true,
              stopPauseOnTap: true,
            ),

            const SizedBox(height: 30),

            // 🔹 Smooth Progress Bar + Percent
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final percent = (_controller.value * 100).toInt();
                  return Column(
                    children: [
                      LinearProgressIndicator(
                        value: _controller.value,
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(8),
                        backgroundColor: Colors.grey[200],
                        color: Colors.blueAccent,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "$percent%",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
