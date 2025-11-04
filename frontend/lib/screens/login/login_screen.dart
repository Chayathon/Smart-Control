import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:smart_control/core/alert/app_snackbar.dart';
import 'package:smart_control/core/color/app_colors.dart';
import 'package:smart_control/core/network/api_service.dart';
import 'package:smart_control/core/storage/secure_storage_service.dart';
import 'package:smart_control/routes/app_routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _adminController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  void _login() async {
    setState(() {
      _isLoading = true;
    });
    if (_adminController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty) {
      try {
        ApiService.resetSessionGuard();
        final api = await ApiService.private();

        final result = await api.post(
          "/auth/login",
          data: {
            "username": _adminController.text,
            "password": _passwordController.text,
          },
        );

        setState(() {
          _isLoading = false;
        });

        if (result['result']?["message"] == "เข้าสู่ระบบสำเร็จ") {
          await SecureStorageService.saveToken(
            "data",
            result['result']['username'],
          );
          ApiService.resetSessionGuard();
          AppSnackbar.success("แจ้งเตือน", "เข้าสู่ระบบสำเร็จ");
          Get.offAllNamed(AppRoutes.home);
          return;
        }

        AppSnackbar.error("แจ้งเตือน", "เข้าสู่ระบบไม่สำเร็จ");
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        AppSnackbar.error("แจ้งเตือน", "เข้าสู่ระบบไม่สำเร็จ");
      }
    } else {
      setState(() {
        _isLoading = false;
      });
      AppSnackbar.error("แจ้งเตือน", "เข้าสู่ระบบไม่สำเร็จ");
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isLandscape ? size.width * 0.4 : 500,
                ),
                child: Card(
                  elevation: 50,
                  shadowColor: Colors.black26,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Lottie.asset(
                          'assets/lottie/login.json',
                          width: 200,
                          height: 200,
                          repeat: true,
                        ),
                        const SizedBox(height: 16),

                        Text(
                          "Smart Control",
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),

                        Text(
                          "ยินดีต้อนรับกลับมา",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),

                        const SizedBox(height: 32),

                        TextField(
                          controller: _adminController,
                          decoration: InputDecoration(
                            labelText: "ชื่อผู้ใช้",
                            prefixIcon: const Icon(Icons.person_2_outlined),
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: "รหัสผ่าน",
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(
                                  () => _obscurePassword = !_obscurePassword,
                                );
                              },
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : _login, // ปิดปุ่มตอนกำลังโหลด
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              backgroundColor: AppColors.primary,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : const Text(
                                    "เข้าสู่ระบบ",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
