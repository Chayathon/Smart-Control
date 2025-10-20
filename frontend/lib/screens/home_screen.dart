import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:smart_control/core/services/StreamStatusService.dart';
import 'package:smart_control/core/alert/app_snackbar.dart';
import 'package:smart_control/routes/app_routes.dart';
import 'package:smart_control/widgets/loading_overlay.dart';
import 'package:toastification/toastification.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:smart_control/core/network/api_service.dart';
import 'package:smart_control/core/mic/mic_stream_service.dart';
import '../widgets/keypad_row.dart';
import '../widgets/lamp_tile.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final storage = const FlutterSecureStorage();
  final _streamStatus = StreamStatusService();
  final _micService = MicStreamService();

  String _displayText = '0';
  List<dynamic> zones = [];
  double _micVolume = 0.5;
  String _zoneNumber = "";
  String _zoneType = "";
  bool _is_playing = false;
  bool _isPlaylistLoading = false;
  String _currentSongTitle = "";
  int _currentSongIndex = 0;
  int _totalSongs = 0;
  bool _micOn = false;
  bool _liveOn = false;
  bool _isSidebarOpen = false;
  bool isPaused = false;
  bool _isLoopEnabled = false; // เพิ่มตัวแปรสำหรับเก็บสถานะ loop
  bool _playlistActive =
      false; // โหมดเพลย์ลิสต์กำลังทำงาน (เล่นหรือหยุดชั่วคราว)

  // Cooldown สำหรับปุ่มควบคุมเพลง (หยุดชั่วคราว/ก่อนหน้า/ถัดไป)
  DateTime? _controlsCooldownUntil;
  Timer? _controlsCooldownTimer;
  bool get _isControlsCoolingDown =>
      _controlsCooldownUntil != null &&
      DateTime.now().isBefore(_controlsCooldownUntil!);

  DateTime? _lastButtonPress;

  late WebSocketChannel channel;

  // WebSocket URL for mic streaming
  static const String micServerUrl = "ws://192.168.1.83:8080/ws/mic";

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      LoadingOverlay.show(context);
      Future.delayed(Duration(seconds: 3), () {
        getAllZones();
        connectWebSocket();
        checkPlaylistStatus(); // เช็คสถานะ playlist
        LoadingOverlay.hide();
      });
    });

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _streamStatus.connect();

    // Setup stream status callback
    _streamStatus.onStatusUpdate = (data) {
      if (!mounted) return;

      final event = data['event'];
      final isPlaying = data['isPlaying'] ?? false;
      final mode = data['mode'] ?? 'single';
      final pausedState = data['isPaused'] ?? false;
      final loopState = data['loop'] ?? false;

      setState(() {
        if (mode == 'playlist') {
          _playlistActive = true;
          _is_playing = isPlaying;
          isPaused = pausedState;
          _isLoopEnabled = loopState;
          _currentSongIndex = (data['index'] ?? 0) + 1;
          _totalSongs = data['total'] ?? 0;

          // แก้ไขการอ่านชื่อเพลง - ตรวจสอบทั้ง extra และ title ใน data
          if (data['title'] != null) {
            _currentSongTitle = data['title'];
          } else if (data['extra'] != null && data['extra']['title'] != null) {
            _currentSongTitle = data['extra']['title'];
          }

          // Reset loading state
          if (event == 'started' ||
              event == 'stopped' ||
              event == 'playlist-stopped') {
            _isPlaylistLoading = false;
          }
        } else if (event == 'playlist-stopped') {
          _playlistActive = false;
          _is_playing = false;
          _isPlaylistLoading = false;
          isPaused = false;
          _isLoopEnabled = false;
          _currentSongTitle = "";
          _currentSongIndex = 0;
          _totalSongs = 0;
        }
      });

      print(
        "Playlist status: playing=$_is_playing, paused=$isPaused, song=$_currentSongIndex/$_totalSongs, title=$_currentSongTitle",
      );
    };

    // Setup mic service callbacks
    _micService.onStatusChanged = (isRecording) {
      if (mounted) {
        setState(() => _micOn = isRecording);
      }
    };

    _micService.onError = (error) {
      if (mounted) {
        AppSnackbar.error("ข้อผิดพลาด", error);
      }
    };
  }

  @override
  void dispose() {
    _controlsCooldownTimer?.cancel();
    _micService.dispose();
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
      final api = await ApiService.private();
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
      final api = await ApiService.private();
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
      final api = await ApiService.private();
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

  Future<void> setStartPlaylist() async {
    try {
      final api = await ApiService.private();

      await api.get('/playlist/start-playlist');
      AppSnackbar.success("แจ้งเตือน", "เริ่มเล่นเพลย์ลิสต์");
    } catch (error) {
      print(error);
      rethrow;
    }
  }

  Future<void> setStopPlaylist() async {
    try {
      final api = await ApiService.private();

      await api.get('/playlist/stop-playlist');
      AppSnackbar.success("แจ้งเตือน", "หยุดเล่นเพลย์ลิสต์");
    } catch (error) {
      print(error);
      rethrow;
    }
  }

  Future<void> checkPlaylistStatus() async {
    try {
      final api = await ApiService.private();
      final response = await api.get('/playlist/status');

      if (!mounted) return;

      print('📊 Playlist Status Response: $response');

      // ตรวจสอบว่ามี playlist กำลังเล่น/หยุดชั่วคราวอยู่หรือไม่
      final isPlaying = response['isPlaying'] ?? false;
      final playlistMode = response['playlistMode'] ?? false;
      final pausedState = response['isPaused'] ?? false;

      if (playlistMode && (isPlaying || pausedState)) {
        final currentSong = response['currentSong'];

        setState(() {
          _playlistActive = true;
          _is_playing = isPlaying; // playing จริงหรือไม่
          isPaused = pausedState;
          _isLoopEnabled = response['loop'] ?? false;
          _totalSongs = response['totalSongs'] ?? 0;

          if (currentSong != null) {
            _currentSongTitle = currentSong['title'] ?? '';
            _currentSongIndex = (currentSong['index'] ?? 0) + 1;
          }
        });

        print(
          '✅ พบ Playlist กำลังเล่น: เพลง $_currentSongIndex/$_totalSongs - $_currentSongTitle',
        );
      } else {
        print('ℹ️ ไม่มี Playlist กำลังเล่น');
        setState(() {
          _playlistActive = false;
        });
      }
    } catch (error) {
      print('❌ Error checking playlist status: $error');
      // ไม่แสดง error แค่ log ไว้
    }
  }

  Future<void> nextSong() async {
    if (!(_is_playing || isPaused)) return;
    if (_isControlsCoolingDown) return;

    // ป้องกันกดถัดไปถ้าเป็นเพลงสุดท้ายและไม่มีการวนลูป
    if (_currentSongIndex >= _totalSongs && !_isLoopEnabled) {
      AppSnackbar.success("แจ้งเตือน", "เป็นเพลงสุดท้ายแล้ว");
      return;
    }

    // Debounce - ป้องกันการกดซ้ำเร็วเกินไป
    final now = DateTime.now();
    if (_lastButtonPress != null &&
        now.difference(_lastButtonPress!).inMilliseconds < 500) {
      return;
    }
    _lastButtonPress = now;
    _startControlsCooldown(); // เริ่มคูลดาวน์ทันทีที่กด

    try {
      final api = await ApiService.private();
      final response = await api.get('/playlist/next-track');

      // ตรวจสอบ response จาก backend
      if (response['status'] == 'error') {
        AppSnackbar.success(
          "แจ้งเตือน",
          response['message'] ?? "ไม่สามารถเปลี่ยนเพลงได้",
        );
      }
    } catch (error) {
      print(error);
      AppSnackbar.error("ข้อผิดพลาด", "ไม่สามารถเปลี่ยนเพลงได้");
    }
  }

  Future<void> prevSong() async {
    if (!(_is_playing || isPaused)) return;
    if (_isControlsCoolingDown) return;

    // ป้องกันกดย้อนกลับถ้าเป็นเพลงแรกและไม่มีการวนลูป
    if (_currentSongIndex <= 1 && !_isLoopEnabled) {
      AppSnackbar.success("แจ้งเตือน", "เป็นเพลงแรกแล้ว");
      return;
    }

    // Debounce - ป้องกันการกดซ้ำเร็วเกินไป
    final now = DateTime.now();
    if (_lastButtonPress != null &&
        now.difference(_lastButtonPress!).inMilliseconds < 500) {
      return;
    }
    _lastButtonPress = now;
    _startControlsCooldown(); // เริ่มคูลดาวน์ทันทีที่กด

    try {
      final api = await ApiService.private();
      final response = await api.get('/playlist/prev-track');

      // ตรวจสอบ response จาก backend
      if (response['status'] == 'error') {
        AppSnackbar.success(
          "แจ้งเตือน",
          response['message'] ?? "ไม่สามารถเปลี่ยนเพลงได้",
        );
      }
    } catch (error) {
      print(error);
      AppSnackbar.error("ข้อผิดพลาด", "ไม่สามารถเปลี่ยนเพลงได้");
    }
  }

  void getAllStatusZone() async {
    try {
      final api = await ApiService.private();
      final result = await api.get('/mqtt/devices/status');

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
      final api = await ApiService.private();
      final result = await api.get('/device');
      setState(() => zones = result);
    } catch (error) {
      print(error);
    }
  }

  void connectWebSocket() {
    channel = WebSocketChannel.connect(
      Uri.parse('ws://192.168.1.83:8080/ws/status'),
    );
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

  Future<void> _toggleMic() async {
    if (_micService.isStopping) return;

    if (_micOn) {
      await _micService.stopStreaming();
      setState(() => _micOn = false);
      AppSnackbar.success("ไมโครโฟน", "ปิดไมโครโฟนแล้ว");
    } else {
      final success = await _micService.startStreaming(micServerUrl);
      if (success) {
        setState(() => _micOn = true);
        AppSnackbar.success("ไมโครโฟน", "เปิดไมโครโฟนแล้ว");
      } else {
        AppSnackbar.error("ข้อผิดพลาด", "ไม่สามารถเปิดไมโครโฟนได้");
      }
    }
  }

  void _toggleLive() => setState(() => _liveOn = !_liveOn);

  void _togglePlaying() async {
    if (_isPlaylistLoading) return;

    setState(() => _isPlaylistLoading = true);

    try {
      if (_is_playing) {
        await setStopPlaylist();
        setState(() {
          _is_playing = false;
          isPaused = false;
          _currentSongTitle = "";
          _currentSongIndex = 0;
          _totalSongs = 0;
        });
      } else {
        await setStartPlaylist();
        // Don't set _is_playing here, wait for SSE update
      }
    } catch (e) {
      setState(() => _isPlaylistLoading = false);
      AppSnackbar.error("ข้อผิดพลาด", "ไม่สามารถดำเนินการได้");
    }
  }

  Future<void> _togglePause() async {
    // อนุญาตให้ทำงานทั้งตอนกำลังเล่นและหยุดชั่วคราว
    if (!(_is_playing || isPaused)) return;
    if (_isControlsCoolingDown) return;

    try {
      _startControlsCooldown(); // เริ่มคูลดาวน์ทันทีที่กด
      final api = await ApiService.private();
      if (isPaused) {
        await api.get('/playlist/resume-playlist');
        setState(() => isPaused = false);
        AppSnackbar.success("แจ้งเตือน", "เล่นต่อ");
      } else {
        await api.get('/playlist/pause-playlist');
        setState(() => isPaused = true);
        AppSnackbar.success("แจ้งเตือน", "หยุดชั่วคราว");
      }
    } catch (error) {
      print(error);
      AppSnackbar.error("ข้อผิดพลาด", "ไม่สามารถหยุดชั่วคราวได้");
    }
  }

  void _startControlsCooldown() {
    // เริ่มคูลดาวน์ 8 วินาทีสำหรับปุ่มควบคุมเพลง
    _controlsCooldownTimer?.cancel();
    final until = DateTime.now().add(const Duration(seconds: 8));
    setState(() {
      _controlsCooldownUntil = until;
    });
    final delay = until.difference(DateTime.now());
    _controlsCooldownTimer = Timer(delay, () {
      if (!mounted) return;
      setState(() {
        _controlsCooldownUntil = null;
      });
    });
  }

  Widget _buildCircularToggleButton({
    required bool isActive,
    required IconData activeIcon,
    required IconData inactiveIcon,
    required String activeLabel,
    required String inactiveLabel,
    required Color activeColor,
    required Color inactiveColor,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
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
                            child: Column(
                              children: [
                                // แถวแรก: ไมค์, ถ่ายทอด, เล่น/หยุด, ปรับเสียง
                                Row(
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
                                      isActive: _is_playing,
                                      activeIcon: _isPlaylistLoading
                                          ? Icons.hourglass_empty
                                          : Icons.stop,
                                      inactiveIcon: _isPlaylistLoading
                                          ? Icons.hourglass_empty
                                          : Icons.play_arrow,
                                      activeLabel: _isPlaylistLoading
                                          ? "กำลังโหลด..."
                                          : "หยุดเล่น",
                                      inactiveLabel: _isPlaylistLoading
                                          ? "กำลังโหลด..."
                                          : "เล่นเพลง",
                                      activeColor: Colors.red[600]!,
                                      inactiveColor: Colors.green[600]!,
                                      onTap: _isPlaylistLoading
                                          ? () {}
                                          : _togglePlaying,
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
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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

                                // แถวสอง: ปุ่มควบคุมเพลง (แสดงเมื่อโหมดเพลย์ลิสต์กำลังทำงาน - เล่นหรือหยุดชั่วคราว)
                                if (_playlistActive && !_isPlaylistLoading) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.blue[100]!,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        // ปุ่มเพลงก่อน - ปิดใช้งานถ้าเป็นเพลงแรกและไม่มี loop
                                        Builder(
                                          builder: (context) {
                                            final prevDisabled =
                                                (_currentSongIndex <= 1 &&
                                                    !_isLoopEnabled) ||
                                                _isControlsCoolingDown;
                                            return Opacity(
                                              opacity: prevDisabled ? 0.3 : 1.0,
                                              child: _buildCircularToggleButton(
                                                isActive: false,
                                                activeIcon: Icons.skip_previous,
                                                inactiveIcon:
                                                    Icons.skip_previous,
                                                activeLabel: "เพลงก่อน",
                                                inactiveLabel: "เพลงก่อน",
                                                activeColor: Colors.blue[700]!,
                                                inactiveColor: prevDisabled
                                                    ? Colors.grey
                                                    : Colors.blue[700]!,
                                                onTap: prevSong,
                                                enabled: !prevDisabled,
                                              ),
                                            );
                                          },
                                        ),
                                        const SizedBox(width: 32),
                                        Opacity(
                                          opacity: _isControlsCoolingDown
                                              ? 0.3
                                              : 1.0,
                                          child: _buildCircularToggleButton(
                                            isActive: isPaused,
                                            activeIcon: Icons.play_circle,
                                            inactiveIcon: Icons.pause_circle,
                                            activeLabel: "เล่นต่อ",
                                            inactiveLabel: "หยุดชั่วคราว",
                                            activeColor: Colors.green[600]!,
                                            inactiveColor:
                                                _isControlsCoolingDown
                                                ? Colors.grey
                                                : Colors.orange[700]!,
                                            onTap: _togglePause,
                                            enabled: !_isControlsCoolingDown,
                                          ),
                                        ),
                                        const SizedBox(width: 32),
                                        // ปุ่มเพลงถัดไป - ปิดใช้งานถ้าเป็นเพลงสุดท้ายและไม่มี loop
                                        Builder(
                                          builder: (context) {
                                            final nextDisabled =
                                                (_currentSongIndex >=
                                                        _totalSongs &&
                                                    !_isLoopEnabled) ||
                                                _isControlsCoolingDown;
                                            return Opacity(
                                              opacity: nextDisabled ? 0.3 : 1.0,
                                              child: _buildCircularToggleButton(
                                                isActive: false,
                                                activeIcon: Icons.skip_next,
                                                inactiveIcon: Icons.skip_next,
                                                activeLabel: "เพลงถัดไป",
                                                inactiveLabel: "เพลงถัดไป",
                                                activeColor: Colors.blue[700]!,
                                                inactiveColor: nextDisabled
                                                    ? Colors.grey
                                                    : Colors.blue[700]!,
                                                onTap: nextSong,
                                                enabled: !nextDisabled,
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // แสดงข้อมูลเพลงปัจจุบัน (แสดงเมื่อโหมดเพลย์ลิสต์กำลังทำงาน)
                          if (_playlistActive && _totalSongs > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blue[700]!.withOpacity(0.1),
                                    Colors.blue[500]!.withOpacity(0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(color: Colors.blue[200]!),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[700],
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: const Icon(
                                      Icons.music_note,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(
                                          _currentSongTitle.isNotEmpty
                                              ? _currentSongTitle
                                              : "กำลังโหลดข้อมูลเพลง...",
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: textColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "เพลงที่ $_currentSongIndex จาก $_totalSongs",
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isPaused
                                          ? Colors.orange[100]
                                          : Colors.green[100],
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isPaused
                                              ? Icons.pause
                                              : Icons.graphic_eq,
                                          size: 14,
                                          color: isPaused
                                              ? Colors.orange[700]
                                              : Colors.green[700],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isPaused
                                              ? "หยุดชั่วคราว"
                                              : "กำลังเล่น",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isPaused
                                                ? Colors.orange[700]
                                                : Colors.green[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if ((_is_playing || isPaused) && _totalSongs > 0)
                            const SizedBox(height: 16),

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
                  _buildMenuItem(Icons.playlist_add, "รายการเพลง", () {
                    Get.toNamed(AppRoutes.playlist);
                  }),
                  Divider(),
                  _buildMenuItem(Icons.music_note, "อัปโหลดเพลง", () {
                    Get.toNamed(AppRoutes.song_upload);
                  }),
                  Divider(),
                  _buildMenuItem(Icons.mic, "ทดสอบไมค์", () {
                    Get.toNamed(AppRoutes.test);
                  }),
                  Divider(),
                  _buildMenuItem(Icons.logout, "ออกจากระบบ", () {
                    logout();
                  }),
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
            // Reserved for future all zone volume control
            // final vol = _extractVolume(_displayText);
            // final api = await ApiService.public();
            // api.post("/mqtt/publish", data: {
            //   "topic": "mass-radio/all/command",
            //   "payload": {"set_volume": vol},
            // });
            // _displayText = '0';
            // _zoneType = '';
            // _zoneNumber = '';
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
