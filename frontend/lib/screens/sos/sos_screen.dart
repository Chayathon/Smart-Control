import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sip_ua/sip_ua.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class SOSPage extends StatefulWidget {
  final SIPUAHelper helper;

  const SOSPage({super.key, required this.helper});

  @override
  State<SOSPage> createState() => _SOSPageState();
}

class _SOSPageState extends State<SOSPage> implements SipUaHelperListener {
  String _connectionStatus = 'Disconnected';
  Call? _currentCall;
  bool _isCallActive = false;

  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();

  // เก็บ stream เพื่อควบคุม mic/speaker/video
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  bool _micMuted = false;
  bool _speakerMuted = false;
  bool _videoEnabled = false; // ใช้บอกว่าตอนนี้เป็นสายวิดีโอไหม
  bool _videoMuted = false; // ปิด/เปิดกล้องระหว่างสาย

  // เบอร์ board ที่จะโทรหา (ปรับตามจริงได้)
  final String _boardTarget = 'sip:301@192.168.1.83';

  @override
  void initState() {
    super.initState();
    _initRenderers();
    widget.helper.addSipUaHelperListener(this);
    _checkPermissions();
  }

  Future<void> _initRenderers() async {
    await _remoteRenderer.initialize();
    await _localRenderer.initialize();
  }

  Future<void> _checkPermissions() async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      // ⭐ ขอสิทธิ์ใช้งานกล้อง/ไมค์ แม้จะไม่ได้ส่งวิดีโอ (จำเป็นสำหรับการรับ stream)
      await [Permission.microphone, Permission.camera].request();
    }
    _registerSIP();
  }

  void _registerSIP() {
    UaSettings settings = UaSettings();

    settings.transportType = TransportType.WS;
    settings.webSocketUrl = 'ws://192.168.1.83:8088/ws';
    settings.webSocketSettings.allowBadCertificate = true;

    settings.uri = 'sip:100@192.168.1.83';
    settings.realm = '192.168.1.83';
    settings.authorizationUser = '100';
    settings.password = '1234';

    settings.displayName = 'Control Room';
    settings.userAgent = 'Flutter SOS App';
    settings.dtmfMode = DtmfMode.RFC2833;

    settings.register = true;
    settings.register_expires = 600;

    widget.helper.start(settings);
  }

  // ================== CALL FUNCTION ==================

  /// โทรเสียงอย่างเดียวไปหา board
  Future<void> _callBoard() async {
    if (!widget.helper.connected ||
        widget.helper.registerState.state !=
            RegistrationStateEnum.REGISTERED) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ยังไม่ได้เชื่อมต่อ SIP (ยังไม่ Registered)'),
        ),
      );
      return;
    }

    setState(() {
      _videoEnabled = false;
      _videoMuted = false;
    });

    final ok = await widget.helper.call(
      _boardTarget,
      voiceOnly: true, // 🔹 สายเสียงอย่างเดียว
    );

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('โทรไปหา board ไม่สำเร็จ (ดู log Not connected)'),
        ),
      );
    }
  }

  /// โทรแบบ Video ไปหา board (ขอทั้งเสียง+ภาพ)
  Future<void> _callBoardVideo() async {
    if (!widget.helper.connected ||
        widget.helper.registerState.state !=
            RegistrationStateEnum.REGISTERED) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ยังไม่ได้เชื่อมต่อ SIP (ยังไม่ Registered)'),
        ),
      );
      return;
    }

    setState(() {
      _videoEnabled = true;
      _videoMuted = false;
    });

    final ok = await widget.helper.call(
      _boardTarget,
      voiceOnly: false, // 🔹 ขอทั้งเสียง+ภาพ
    );

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video call ไปหา board ไม่สำเร็จ')),
      );
    }
  }

  // ========= MUTE MIC / SPEAKER / VIDEO =========

  void _toggleMicMute() {
    if (_localStream == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ยังไม่มีสายที่ใช้งานอยู่')),
      );
      return;
    }

    setState(() => _micMuted = !_micMuted);
    for (var track in _localStream!.getAudioTracks()) {
      track.enabled = !_micMuted;
    }
  }

  void _toggleSpeakerMute() {
    if (_remoteRenderer.srcObject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ยังไม่มีสายที่ใช้งานอยู่')),
      );
      return;
    }

    setState(() => _speakerMuted = !_speakerMuted);
    // ✅ ใช้ Helper.setSpeakerphoneOn แทนไปปิด track ตรงๆ
    Helper.setSpeakerphoneOn(!_speakerMuted);
  }

  void _toggleVideoMute() {
    if (!_videoEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ตอนนี้เป็นสายเสียงอย่างเดียว')),
      );
      return;
    }
    if (_localStream == null || _currentCall == null || !_isCallActive) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ยังไม่มีสายที่ใช้งานอยู่')));
      return;
    }

    final newMuted = !_videoMuted;

    for (final track in _localStream!.getVideoTracks()) {
      track.enabled = !newMuted;
    }

    setState(() {
      _videoMuted = newMuted;
    });
  }

  @override
  void dispose() {
    _remoteRenderer.dispose();
    _localRenderer.dispose();
    widget.helper.removeSipUaHelperListener(this);
    super.dispose();
  }

  // ================== UI ==================

  Widget _buildCallUI() {
    return Column(
      children: [
        // ======= VIDEO AREA =======
        Expanded(
          child: Container(
            color: Colors.black,
            child: Stack(
              children: [
                RTCVideoView(
                  _remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                ),
                if (_isCallActive && _videoEnabled)
                  Positioned(
                    right: 20,
                    bottom: 20,
                    width: 120,
                    height: 160,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white),
                      ),
                      child: RTCVideoView(_localRenderer, mirror: true),
                    ),
                  ),
                if (!_isCallActive && _currentCall == null)
                  const Center(
                    child: Text(
                      "Ready to make a call...",
                      style: TextStyle(color: Colors.white54, fontSize: 18),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // ======= CONTROL PANEL =======
        Container(
          height: 190,
          color: Colors.grey[900],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // แถวปุ่มโทรหลัก (ตอนยังไม่มีสายใช้งาน)
              if (!_isCallActive && _currentCall == null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildBtn(
                      Icons.phone_forwarded,
                      Colors.blueGrey,
                      "CALL BOARD",
                      _callBoard,
                    ),
                    _buildBtn(
                      Icons.videocam,
                      Colors.purple,
                      "VIDEO CALL",
                      _callBoardVideo,
                    ),
                  ],
                ),

              // ถ้ามีสายเข้า (CALL_INITIATION ฝั่ง remote) ให้โชว์ปุ่ม ANSWER/HANGUP
              if (!_isCallActive && _currentCall != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildBtn(
                      Icons.call,
                      Colors.green,
                      "ANSWER",
                      () {
                        // รับสายแบบรองรับ video ด้วย
                        _currentCall!.answer(
                          widget.helper.buildCallOptions(false),
                        );
                      },
                    ),
                    _buildBtn(
                      Icons.call_end,
                      Colors.red,
                      "REJECT",
                      () {
                        _currentCall?.hangup();
                      },
                    ),
                  ],
                ),

              if (_isCallActive) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildBtn(Icons.call_end, Colors.red, "HANGUP", () {
                      _currentCall?.hangup();
                    }),
                    _buildBtn(Icons.lock_open, Colors.blue, "UNLOCK", () {
                      if (_currentCall != null && _isCallActive) {
                        _currentCall!.sendDTMF("1");
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Sending Unlock..."),
                          ),
                        );
                      }
                    }),
                    _buildBtn(
                      _micMuted ? Icons.mic_off : Icons.mic,
                      _micMuted ? Colors.grey : Colors.orange,
                      _micMuted ? "MIC MUTED" : "MIC ON",
                      _toggleMicMute,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildBtn(
                      _speakerMuted ? Icons.volume_off : Icons.volume_up,
                      _speakerMuted ? Colors.grey : Colors.orangeAccent,
                      _speakerMuted ? "SPEAKER MUTED" : "SPEAKER ON",
                      _toggleSpeakerMute,
                    ),
                    _buildBtn(
                      _videoMuted ? Icons.videocam_off : Icons.videocam,
                      !_videoEnabled
                          ? Colors.grey.shade700
                          : (_videoMuted ? Colors.grey : Colors.lightBlue),
                      !_videoEnabled
                          ? "VIDEO OFF"
                          : (_videoMuted ? "CAMERA OFF" : "CAMERA ON"),
                      _toggleVideoMute,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS Control Center'),
        backgroundColor: _connectionStatus == 'Registered'
            ? Colors.green[800]
            : Colors.red[900],
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _connectionStatus,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: _buildCallUI(),
    );
  }

  Widget _buildBtn(
    IconData icon,
    Color color,
    String label,
    VoidCallback onTap,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FloatingActionButton(
          heroTag: label,
          onPressed: onTap,
          backgroundColor: color,
          child: Icon(icon, color: Colors.white, size: 26),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  // ================== SIP Listener ==================

  @override
  void transportStateChanged(TransportState state) {
    if (kDebugMode) {
      print('Transport state: ${state.state}');
    }
  }

  @override
  void registrationStateChanged(RegistrationState state) {
    if (kDebugMode) {
      print('Registration state: ${state.state}');
    }
    setState(() {
      _connectionStatus = state.state == RegistrationStateEnum.REGISTERED
          ? 'Registered'
          : 'Connecting...';
    });
  }

  @override
  void callStateChanged(Call call, CallState state) {
    setState(() {
      _currentCall = call;
    });

    if (kDebugMode) {
      print('Call ${call.id} state => ${state.state}');
    }

    switch (state.state) {
      case CallStateEnum.CALL_INITIATION:
        // มีสายเข้า/เริ่มโทร แต่เราไม่เปลี่ยนหน้าแล้ว แค่เก็บ _currentCall ไว้
        break;

      case CallStateEnum.STREAM:
        if (state.stream != null) {
          final stream = state.stream!;
          if (state.originator == 'remote') {
            _remoteStream = stream;
            _remoteRenderer.srcObject = _remoteStream;

            for (final t in stream.getAudioTracks()) {
              if (kDebugMode) {
                print('REMOTE audio track: enabled=${t.enabled}');
              }
              t.enabled = true;
            }

            if (kDebugMode) {
              print(
                'REMOTE Stream received. Video Tracks: ${stream.getVideoTracks().length}',
              );
              print(' Audio Tracks: ${stream.getAudioTracks().length}');
            }
          } else {
            _localStream = stream;
            _localRenderer.srcObject = _localStream;

            for (final t in stream.getAudioTracks()) {
              if (kDebugMode) {
                print('LOCAL audio track: enabled=${t.enabled}');
              }
              t.enabled = true;
            }
          }

          setState(() {
            if (state.originator == 'local') {
              _videoEnabled = stream.getVideoTracks().isNotEmpty;
            }
          });
        }
        break;

      case CallStateEnum.CONFIRMED:
      case CallStateEnum.ACCEPTED:
        Helper.setSpeakerphoneOn(true); // ✅ บังคับ route ไป speaker
        setState(() {
          _isCallActive = true;
        });
        break;

      case CallStateEnum.ENDED:
      case CallStateEnum.FAILED:
        _remoteRenderer.srcObject = null;
        _localRenderer.srcObject = null;
        _remoteStream?.getTracks().forEach((track) => track.stop());
        _localStream?.getTracks().forEach((track) => track.stop());

        setState(() {
          _isCallActive = false;
          _currentCall = null;
          _localStream = null;
          _remoteStream = null;
          _micMuted = false;
          _speakerMuted = false;
          _videoMuted = false;
          _videoEnabled = false;
        });
        break;

      default:
        break;
    }
  }

  @override
  void onNewReinvite(ReInvite reInvite) {}

  @override
  void onNewMessage(SIPMessageRequest msg) {}

  @override
  void onNewNotify(Notify ntf) {}
}
