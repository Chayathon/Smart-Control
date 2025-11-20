import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
// import 'package:smart_control/core/services/StreamStatusService.dart';
import 'package:smart_control/core/alert/app_snackbar.dart';
import 'package:smart_control/routes/app_routes.dart';
import 'package:smart_control/widgets/loading_overlay.dart';
import 'package:smart_control/services/zone_service.dart';
import 'package:smart_control/core/network/api_service.dart';
import '../widgets/zones/keypad_panel.dart';
import '../widgets/control_panel.dart';
import '../widgets/zones/zones_panel.dart';
import '../widgets/sidebar_panel.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final storage = const FlutterSecureStorage();
  // final _streamStatus = StreamStatusService();

  List<dynamic> zones = [];
  bool _isSidebarOpen = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      LoadingOverlay.show(context);
      Future.delayed(Duration(seconds: 3), () async {
        try {
          // load initial zones
          final result = await ZoneService.instance.fetchAllZones();
          if (mounted) setState(() => zones = result);

          // subscribe to realtime updates
          ZoneService.instance.subscribeToStatusUpdates((data) {
            if (data["zone"] != null) {
              final idx = zones.indexWhere((z) => z["no"] == data["zone"]);
              if (idx != -1) {
                if (mounted) {
                  setState(() {
                    zones[idx]["status"]["stream_enabled"] =
                        data["stream_enabled"];
                    zones[idx]["status"]["volume"] = data["volume"];
                    zones[idx]["status"]["is_playing"] = data["is_playing"];
                  });
                }
              }
            }
          });
        } catch (e) {
          print(e);
        }

        LoadingOverlay.hide();
      });
    });

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    ZoneService.instance.dispose();
    super.dispose();
  }

  void logout() async {
    LoadingOverlay.show(context);

    final api = await ApiService.private();

    await api.post("/auth/logout");

    Future.delayed(Duration(seconds: 1), () async {
      AppSnackbar.success("สำเร็จ", "ออกจากระบบสำเร็จแล้ว");
      await storage.delete(key: "data");
      Get.offAndToNamed(AppRoutes.login);
      LoadingOverlay.hide();
    });
  }

  @override
  Widget build(BuildContext context) {
    final whiteBg = Colors.grey[50]!;
    final cardBg = Colors.white;
    final accent = Colors.blue[700]!;
    final lampOn = Colors.green[500]!;
    final lampOff = Colors.grey[300]!;
    final textColor = Colors.grey[900]!;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: whiteBg,
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(80),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 24),
                        Text(
                          'Smart Control',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: IconButton(
                            iconSize: 32,
                            padding: const EdgeInsets.all(12),
                            icon: Icon(Icons.menu_rounded, color: accent),
                            onPressed: () =>
                                setState(() => _isSidebarOpen = true),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: KeypadPanel(
                        zones: zones,
                        cardBg: cardBg,
                        whiteBg: whiteBg,
                        textColor: textColor,
                        shadowColor: Colors.grey[300]!,
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          ControlPanel(),
                          const SizedBox(height: 16),

                          Expanded(
                            child: ZonesPanel(
                              zones: zones,
                              lampOnColor: lampOn,
                              lampOffColor: lampOff,
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
          SidebarPanel(
            isOpen: _isSidebarOpen,
            onClose: () => setState(() => _isSidebarOpen = false),
            onLogout: logout,
          ),
        ],
      ),
    );
  }
}
