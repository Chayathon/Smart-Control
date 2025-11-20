import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:smart_control/core/alert/app_snackbar.dart';
import 'package:smart_control/core/network/api_service.dart';
import 'package:smart_control/core/storage/secure_storage_service.dart';
import 'package:smart_control/routes/app_routes.dart';
import 'package:smart_control/widgets/inputs/text_field_box.dart';
import 'package:smart_control/widgets/buttons/action_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  void _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });
    if (_usernameController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty) {
      try {
        ApiService.resetSessionGuard();
        final api = await ApiService.private();

        final result = await api.post(
          "/auth/login",
          data: {
            "username": _usernameController.text,
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
          AppSnackbar.success("สำเร็จ", "เข้าสู่ระบบสำเร็จ");
          Get.offAllNamed(AppRoutes.home);
          return;
        }

        AppSnackbar.error("ล้มเหลว", "ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง");
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        AppSnackbar.error("ล้มเหลว", "เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง");
      }
    } else {
      setState(() {
        _isLoading = false;
      });
      AppSnackbar.error("ล้มเหลว", "กรุณากรอกชื่อผู้ใช้และรหัสผ่าน");
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
                  shadowColor: Colors.black45,
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
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
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

                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFieldBox(
                                controller: _usernameController,
                                hint: "ชื่อผู้ใช้",
                                prefixIcon: const Icon(
                                  Icons.person_outline_rounded,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'กรุณากรอกชื่อผู้ใช้';
                                  }
                                  return null;
                                },
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 8),

                              TextFieldBox(
                                controller: _passwordController,
                                hint: "รหัสผ่าน",
                                obscureText: _obscurePassword,
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: () {
                                    setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    );
                                  },
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'กรุณากรอกรหัสผ่าน';
                                  }
                                  return null;
                                },
                                textInputAction: TextInputAction.done,
                              ),

                              const SizedBox(height: 16),

                              Button(
                                onPressed: _isLoading ? null : _login,
                                label: 'เข้าสู่ระบบ',
                                icon: Icons.login,
                                isLoading: _isLoading,
                                backgroundColor: Colors.blue,
                              ),
                            ],
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
