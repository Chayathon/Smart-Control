import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:smart_control/core/alert/app_snackbar.dart';
import 'package:smart_control/routes/app_routes.dart';
import 'package:toastification/toastification.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:smart_control/core/network/api_service.dart';
import '../widgets/keypad_row.dart';
import '../widgets/lamp_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _displayText = '0';
  String _username = "Admin";
  List<dynamic> zones = [];
  double _micVolume = 0.5;
  String _zoneNumber = "";
  String _zoneType = "";
  bool _is_playing = false;
  bool _micOn = false;
  bool _liveOn = false;
  bool _isSidebarOpen = false;

  late WebSocketChannel channel;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    getAllZones();
    connectWebSocket();
  }

  int _extractVolume(String text) {
    if (text.trim().toUpperCase() == "ALL ZONE VOLUME 0") {
      return 0;
    }
    final match = RegExp(r'(\d+)$').firstMatch(text);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
  }

  Future<void> getStatusZone() async {
    try {
      final api = ApiService.public();
      final result = await api.post(
        "/mqtt/publishAndWait",
        data: {"zone": "$_displayText"},
      );
      setState(() {
        _is_playing = result['is_playing'];

        if (_zoneType == "volume") {
          final vol = result["volume"] ?? 0;
          _displayText = "ZONE $_zoneNumber VOLUME $vol";
        }

        if (_zoneType == "power") {
          setStream();
        }
      });
    } catch (error) {
      print(error);
    }
  }

  Future<void> setStream() async {
    try {
      final api = ApiService.public();
      await api.post(
        "/mqtt/publish",
        data: {
          "topic": "mass-radio/zone$_zoneNumber/command",
          "payload": {"set_stream": !_is_playing},
        },
      );

      _displayText = _is_playing ? "OFF AIR" : "ON AIR";

      AppSnackbar.success(
        "แจ้งเตือน",
        !_is_playing
            ? 'เปิดการใช้งานโซน $_zoneNumber'
            : 'ปิดการใช้งานโซน $_zoneNumber',
      );

      setState(() => _zoneType = "");
    } catch (error) {
      print(error);
    }
  }

  void setVolume() async {
    try {
      final volumeValue = _extractVolume(_displayText);
      final api = ApiService.public();
      await api.post(
        "/mqtt/publish",
        data: {
          "topic": "mass-radio/zone$_zoneNumber/command",
          "payload": {"set_volume": volumeValue},
        },
      );

      AppSnackbar.success("แจ้งเตือน", "ปรับเสียงสำเร็จ");
    } catch (error) {
      print(error);
    }
  }

  void getAllStatusZone() async {
    try {
      final api = ApiService.public();
      final result = await api.get('/devices/status');

      List<dynamic> zones = result;

      for (var zone in zones) {
        if (zone['data']['is_playing'] == true) {
          api.post(
            "/mqtt/publish",
            data: {
              "topic": "mass-radio/all/command",
              "payload": {"set_stream": false},
            },
          );

          _displayText = '0';
          _zoneType = '';
          _zoneNumber = '';
          return;
        } else {
          api.post(
            "/mqtt/publish",
            data: {
              "topic": "mass-radio/all/command",
              "payload": {"set_stream": true},
            },
          );

          _displayText = '0';
          _zoneType = '';
          _zoneNumber = '';
          return;
        }
      }
    } catch (error) {
      print('Error: $error');
    }
  }

  void getAllZones() async {
    try {
      final api = ApiService.public();
      final result = await api.get('/device');
      setState(() => zones = result);
    } catch (error) {
      print(error);
    }
  }

  void connectWebSocket() {
    channel = WebSocketChannel.connect(Uri.parse('ws://192.168.1.83:8080'));
    channel.stream.listen((message) {
      final data = jsonDecode(message);
      if (data["zone"] != null) {
        final idx = zones.indexWhere((z) => z["no"] == data["zone"]);
        if (idx != -1) {
          setState(() {
            zones[idx]["status"]["stream_enabled"] = data["stream_enabled"];
            zones[idx]["status"]["volume"] = data["volume"];
            zones[idx]["status"]["is_playing"] = data["is_playing"];
          });
        }
      }
    });
  }

  void _toggleMic() => setState(() => _micOn = !_micOn);
  void _toggleLive() => setState(() => _liveOn = !_liveOn);

  Widget _buildCircularToggleButton({
    required bool isActive,
    required IconData activeIcon,
    required IconData inactiveIcon,
    required String activeLabel,
    required String inactiveLabel,
    required Color activeColor,
    required Color inactiveColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(25),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (isActive ? activeColor : inactiveColor).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isActive ? activeIcon : inactiveIcon,
              color: isActive ? activeColor : inactiveColor,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isActive ? activeLabel : inactiveLabel,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        onTap();
        setState(() => _isSidebarOpen = false);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
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
      body: Stack(
        children: [
          Scaffold(
            backgroundColor: whiteBg,
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(80),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
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
                            color: accent.withOpacity(0.1),
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
                      child: _buildKeypad(
                        cardBg,
                        whiteBg,
                        textColor,
                        Colors.grey[300]!,
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
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                _buildCircularToggleButton(
                                  isActive: _micOn,
                                  activeIcon: Icons.mic,
                                  inactiveIcon: Icons.mic_off,
                                  activeLabel: "ปิดไมค์",
                                  inactiveLabel: "เปิดไมค์",
                                  activeColor: Colors.green[600]!,
                                  inactiveColor: Colors.grey[700]!,
                                  onTap: _toggleMic,
                                ),
                                const SizedBox(width: 24),
                                _buildCircularToggleButton(
                                  isActive: _liveOn,
                                  activeIcon: Icons.live_tv,
                                  inactiveIcon: Icons.live_tv_outlined,
                                  activeLabel: "หยุดถ่ายทอด",
                                  inactiveLabel: "เริ่มถ่ายทอด",
                                  activeColor: Colors.red[600]!,
                                  inactiveColor: Colors.grey[700]!,
                                  onTap: _toggleLive,
                                ),
                                const SizedBox(width: 24),
                                _buildCircularToggleButton(
                                  isActive: true,
                                  activeIcon: Icons.pause,
                                  inactiveIcon: Icons.play_arrow,
                                  activeLabel: "หยุดเล่น",
                                  inactiveLabel: "เล่นต่อ",
                                  activeColor: Colors.red[600]!,
                                  inactiveColor: Colors.green[600]!,
                                  onTap: _toggleLive,
                                ),

                                const SizedBox(width: 24),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey[200]!,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.volume_down,
                                          size: 28,
                                          color: Colors.grey[600],
                                        ),
                                        Expanded(
                                          child: Slider(
                                            value: _micVolume,
                                            onChanged: (value) => setState(
                                              () => _micVolume = value,
                                            ),
                                            activeColor: accent,
                                          ),
                                        ),
                                        Icon(
                                          Icons.volume_up,
                                          size: 28,
                                          color: accent,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Expanded(
                            child: GridView.builder(
                              itemCount: zones.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 5,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: 1.6,
                                  ),
                              itemBuilder: (context, index) {
                                return LampTile(
                                  isOn:
                                      zones[index]["status"]["stream_enabled"],
                                  lampOnColor: lampOn,
                                  lampOffColor: lampOff,
                                  zone: "โซน ${index + 1}",
                                  onTap: () {},
                                );
                              },
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
          if (_isSidebarOpen)
            GestureDetector(
              onTap: () => setState(() => _isSidebarOpen = false),
              child: AnimatedOpacity(
                opacity: _isSidebarOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 300),
                child: Container(color: Colors.black),
              ),
            ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            top: 0,
            bottom: 0,
            right: _isSidebarOpen ? 0 : -270,
            child: Container(
              width: 270,
              color: Colors.blue[900],
              padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Spacer(),
                  const Text(
                    "เมนูหลัก",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 30),
                  _buildMenuItem(Icons.dashboard, "หน้าหลัก", () {}),
                  Divider(),
                  _buildMenuItem(Icons.music_note, "จัดการเพลง", () {
                    Get.toNamed(AppRoutes.song_upload);
                  }),
                  Divider(),
                  _buildMenuItem(Icons.logout, "ออกจากระบบ", () {}),
                  Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeypad(
    Color cardBg,
    Color whiteBg,
    Color textColor,
    Color shadowColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: shadowColor, blurRadius: 8, spreadRadius: 2),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: whiteBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            width: double.infinity,
            child: Text(
              _displayText,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: textColor,
                fontSize: 28,
                fontFamily: 'Courier',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                KeypadRow(
                  keys: const ['1', '2', '3', 'volume'],
                  onKey: _onKeyPressed,
                ),
                const SizedBox(height: 8),
                KeypadRow(
                  keys: const ['4', '5', '6', 'add'],
                  onKey: _onKeyPressed,
                ),
                const SizedBox(height: 8),
                KeypadRow(
                  keys: const ['7', '8', '9', 'remove'],
                  onKey: _onKeyPressed,
                ),
                const SizedBox(height: 8),
                KeypadRow(
                  keys: const ['clear', '0', 'power', 'enter'],
                  onKey: _onKeyPressed,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onKeyPressed(String value) async {
    setState(() {
      if (value == 'clear') {
        _displayText = '0';
        _zoneType = '';
        _zoneNumber = '';
        return;
      }

      if (_zoneType == 'volume') {
        final isAllZone = _displayText.toUpperCase().startsWith("ALL ZONE");

        if (value == 'add') {
          final current = _extractVolume(_displayText);
          if (current < 21) {
            if (isAllZone) {
              _displayText = "ALL ZONE VOLUME ${current + 1}";
            } else {
              _displayText = "ZONE $_zoneNumber VOLUME ${current + 1}";
            }
          }
          return;
        }

        if (value == 'remove') {
          final current = _extractVolume(_displayText);
          if (current > 0) {
            if (isAllZone) {
              _displayText = "ALL ZONE VOLUME ${current - 1}";
            } else {
              _displayText = "ZONE $_zoneNumber VOLUME ${current - 1}";
            }
          }
          return;
        }

        if (int.tryParse(value) != null) {
          final numValue = int.parse(value);
          if (numValue <= 21) {
            if (isAllZone) {
              _displayText = "ALL ZONE VOLUME $numValue";
            } else {
              _displayText = "ZONE $_zoneNumber VOLUME $numValue";
            }
          }
          return;
        }
      }

      if (_zoneType != "volume" && (value == "add" || value == "remove")) {
        return;
      }

      if (value == 'volume') {
        if (_displayText == "ALL ZONE") {
          _zoneType = "volume";
          _displayText = "ALL ZONE VOLUME 0";
          return;
        }
        final zoneValue = int.tryParse(_displayText);
        if (zoneValue == null || zoneValue <= 0 || zoneValue > zones.length) {
          toastification.show(
            context: context,
            type: ToastificationType.warning,
            style: ToastificationStyle.minimal,
            title: const Text('คำเตือน'),
            description: Text('กรุณาเลือกโซนที่ถูกต้อง (1-${zones.length})'),
            autoCloseDuration: const Duration(seconds: 3),
            alignment: Alignment.topRight,
            showProgressBar: true,
          );
          return;
        }
        _zoneNumber = _displayText;
        _zoneType = 'volume';
        getStatusZone();
        return;
      }

      if (value == "power") {
        _zoneType = "power";

        final isAllZone = _displayText.toUpperCase().startsWith("ALL ZONE");
        if (isAllZone) {
          getAllStatusZone();

          return;
        }

        final zoneValue = int.tryParse(_displayText);
        if (zoneValue == null || zoneValue <= 0 || zoneValue > zones.length) {
          toastification.show(
            context: context,
            type: ToastificationType.warning,
            style: ToastificationStyle.minimal,
            title: const Text('คำเตือน'),
            description: Text('กรุณาเลือกโซนที่ถูกต้อง (1-${zones.length})'),
            autoCloseDuration: const Duration(seconds: 3),
            alignment: Alignment.topRight,
            showProgressBar: true,
          );
          return;
        }

        _zoneNumber = _displayText;
        getStatusZone();

        return;
      }

      if (value == "enter") {
        if (_zoneType == "volume") {
          final isAllZone = _displayText.toUpperCase().startsWith("ALL ZONE");
          if (isAllZone) {
            final vol = _extractVolume(_displayText);

            final api = ApiService.public();
            api.post(
              "/mqtt/publish",
              data: {
                "topic": "mass-radio/all/command",
                "payload": {"set_volume": vol},
              },
            );

            _displayText = '0';
            _zoneType = '';
            _zoneNumber = '';
            return;
          } else {
            setVolume();
          }
          _zoneType = "";
          _displayText = _is_playing ? "ON AIR" : "OFF AIR";
        }
        return;
      }

      if (_displayText == '0') {
        _displayText = value;
        if (_displayText == "0") {
          _displayText = "ALL ZONE";
        }
      } else if (_displayText == "ON AIR" || _displayText == "OFF AIR") {
        _displayText = value;
      } else {
        _displayText += value;
      }
    });
  }
}
