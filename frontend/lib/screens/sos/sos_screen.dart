// lib/screens/sos/sos_screen.dart
//
// หน้าจอ Softphone สำหรับ SOS / Call Center

import 'dart:ui';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:sip_ua/sip_ua.dart';

import 'manage_contacts.dart';

typedef Json = Map<String, dynamic>;

// 🔤 สไตล์กลางสำหรับ Logs / Contacts
const TextStyle kListTitleStyle = TextStyle(
  fontSize: 16,
  color: Colors.black,
  fontWeight: FontWeight.w500,
);

const TextStyle kListSubtitleStyle = TextStyle(
  fontSize: 13,
  color: Colors.black87,
  fontWeight: FontWeight.normal,
);

enum CallState {
  idle,
  dialing,
  ringing,
  inCall,
  ended,
}

class CallLogItem {
  final String number;
  final DateTime time;
  final Duration duration;
  final bool incoming;
  final bool missed;

  CallLogItem({
    required this.number,
    required this.time,
    this.duration = Duration.zero,
    this.incoming = false,
    this.missed = false,
  });
}

class ContactItem {
  final String name;
  final String number;

  ContactItem({required this.name, required this.number});
}

/// หน้าจอหลัก SOS Softphone
class SosScreen extends StatefulWidget {
  final SIPUAHelper helper;

  const SosScreen({
    Key? key,
    required this.helper,
  }) : super(key: key);

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _numberController = TextEditingController();
  final FocusNode _numberFocus = FocusNode();

  // 🔍 Search logs
  final TextEditingController _logSearchController = TextEditingController();
  String _logSearchQuery = '';

  // 🔍 Search contacts (ยังไม่ filter แค่ช่องไว้ก่อน)
  final TextEditingController _contactSearchController =
      TextEditingController();

  // ⚙️ Settings
  final TextEditingController _sipServerController = TextEditingController();
  final FocusNode _sipFocus = FocusNode();

  // ✅ ไม่ใช้ late — สร้างตอนประกาศเลย
  final TextEditingController _recordFolderController =
      TextEditingController();
  final FocusNode _recordFocus = FocusNode();

  String _currentExtension = '2000';
  String _currentServer = '192.168.1.1';
  String _currentName = 'SOS Operator';

  CallState _callState = CallState.idle;
  String _statusText = 'พร้อมใช้งาน';
  bool _isOnline = true;
  bool _isMuted = false;
  bool _isSpeakerOn = true;

  double _speakerVolume = 0.7;
  double _micGain = 0.6;

  bool _speakerDragging = false;
  bool _micDragging = false;

  String _selectedTab = 'Phone';
  String _networkStatus = 'Online';
  String _requestStatus = 'Idle';

  final List<String> _recentDialList = [
    '1002',
    '2000',
    '3001',
    '9999',
  ];

  bool _isDropdownOpen = false;
  String? _activeAction; // 'video'

  final List<CallLogItem> _callLogs = [
    CallLogItem(
      number: '1002',
      time: DateTime.now().subtract(const Duration(minutes: 3)),
      duration: const Duration(minutes: 2, seconds: 30),
      incoming: true,
      missed: false,
    ),
    CallLogItem(
      number: '2000',
      time: DateTime.now().subtract(const Duration(hours: 1, minutes: 10)),
      duration: const Duration(minutes: 5, seconds: 2),
      incoming: false,
      missed: false,
    ),
    CallLogItem(
      number: '3001',
      time: DateTime.now().subtract(const Duration(hours: 5, minutes: 40)),
      duration: Duration.zero,
      incoming: true,
      missed: true,
    ),
  ];

  final List<ContactItem> _contacts = [
    ContactItem(name: 'Control Room', number: '1002'),
    ContactItem(name: 'Control Room', number: '2000'),
    ContactItem(name: 'Guard 1', number: '3001'),
    ContactItem(name: 'Guard 2', number: '3002'),
    ContactItem(name: 'Technician', number: '4001'),
  ];

  final List<String> _accounts = const [
    '1000',
    '200',
    '1010',
    '1001',
    '1000 FW',
    '2001',
    '1072',
  ];

  bool _hasIncoming = false;
  String? _incomingNumber;
  String? _incomingName;
  bool _incomingIsVideo = false;
  bool _isInVideoCall = false;

  String _recordFolderPath = '';

  final AudioPlayer _keyPlayer = AudioPlayer();
  final AudioPlayer _ringPlayer = AudioPlayer();

  bool _showIncomingToast = false;
  String? _toastNumber;
  Timer? _toastTimer;

  bool _showSaveOverlay = false;
  bool _saveSuccess = true;
  String _saveTitle = '';
  String _saveSubtitle = '';

  late final AnimationController _answerBtnController;
  Animation<Offset>? _answerBtnAnimation;

  bool get _hasNumber => _numberController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();

    _numberFocus.addListener(() {
      setState(() {});
    });

    _logSearchController.addListener(() {
      setState(() {
        _logSearchQuery = _logSearchController.text.trim().toLowerCase();
      });
    });

    _sipServerController.text = _currentServer;
    _sipServerController.addListener(() {
      setState(() {
        _currentServer = _sipServerController.text.trim();
      });
    });

    _sipFocus.addListener(() {
      setState(() {});
    });

    _recordFolderController.text = _recordFolderPath;
    _recordFolderController.addListener(() {
      setState(() {
        _recordFolderPath = _recordFolderController.text;
      });
    });
    _recordFocus.addListener(() {
      setState(() {});
    });

    _answerBtnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _answerBtnAnimation = Tween<Offset>(
      begin: const Offset(-0.04, 0),
      end: const Offset(0.04, 0),
    ).animate(
      CurvedAnimation(
        parent: _answerBtnController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _numberController.dispose();
    _numberFocus.dispose();
    _logSearchController.dispose();
    _contactSearchController.dispose();

    _sipServerController.dispose();
    _sipFocus.dispose();
    _recordFolderController.dispose();
    _recordFocus.dispose();

    _keyPlayer.dispose();
    _ringPlayer.dispose();
    _toastTimer?.cancel();
    _answerBtnController.dispose();
    super.dispose();
  }

  // ================== Sound helpers ==================

  String _soundFileForKey(String key) {
    switch (key) {
      case '0':
        return 'sounds/dtmf_click_0.mp3';
      case '1':
        return 'sounds/dtmf_click_1.mp3';
      case '2':
        return 'sounds/dtmf_click_2.mp3';
      case '3':
        return 'sounds/dtmf_click_3.mp3';
      case '4':
        return 'sounds/dtmf_click_4.mp3';
      case '5':
        return 'sounds/dtmf_click_5.mp3';
      case '6':
        return 'sounds/dtmf_click_6.mp3';
      case '7':
        return 'sounds/dtmf_click_7.mp3';
      case '8':
        return 'sounds/dtmf_click_8.mp3';
      case '9':
        return 'sounds/dtmf_click_9.mp3';
      case 'C':
        return 'sounds/dtmf_click_C.mp3';
      case '<':
        return 'sounds/dtmf_click_lessthan.mp3';
      default:
        return 'sounds/dtmf_click_0.mp3';
    }
  }

  Future<void> _playKeyClick(String key) async {
    try {
      final filePath = _soundFileForKey(key);
      await _keyPlayer.stop();
      await _keyPlayer.play(
        AssetSource(filePath),
        volume: 1.0,
      );
    } catch (e) {
      debugPrint('play key click error: $e');
    }
  }

  Future<void> _playIncomingRingtone() async {
    try {
      await _ringPlayer.stop();
      await _ringPlayer.setReleaseMode(ReleaseMode.loop);
      await _ringPlayer.play(
        AssetSource('sounds/incoming_call.mp3'),
        volume: 1.0,
      );
    } catch (e) {
      debugPrint('play incoming ringtone error: $e');
    }
  }

  Future<void> _stopIncomingRingtone() async {
    try {
      await _ringPlayer.stop();
    } catch (e) {
      debugPrint('stop incoming ringtone error: $e');
    }
  }

  void _startAnswerButtonAnimation() {
    if (!_answerBtnController.isAnimating) {
      _answerBtnController.repeat(reverse: true);
    }
  }

  void _stopAnswerButtonAnimation() {
    _answerBtnController.stop();
    _answerBtnController.reset();
  }

  // ================== Toast SOS ==================

  void _showIncomingSosToast(String number) {
    _toastTimer?.cancel();
    setState(() {
      _toastNumber = number;
      _showIncomingToast = true;
    });
  }

  /// 🔔 Toast แจ้งเตือน SOS
  /// - คลิกที่ตัว Toast = ปิด + เปิดหน้า SosScreen
  /// - กดปุ่ม X = ปิดอย่างเดียว
  Widget _buildIncomingToast(String number) {
    final contactName = _findContactName(number);
    final displayName = contactName ?? number;

    void closeToastOnly() {
      _toastTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _showIncomingToast = false;
      });
    }

    void handleToastTap() {
      _toastTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _showIncomingToast = false;
      });

      // 👉 เปิดหน้า SOS (ไฟล์นี้เอง) พร้อม helper เดิม
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SosScreen(helper: widget.helper),
        ),
      );
    }

    return GestureDetector(
      onTap: handleToastTap,
      child: Material(
        elevation: 10,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          bottomLeft: Radius.circular(12),
        ),
        child: Container(
          width: 310,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.red.shade800.withOpacity(0.95),
                Colors.red.shade600.withOpacity(0.9),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 5,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.red.shade200.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'SOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'สายเรียกเข้าจาก $displayName',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'คลิกเพื่อเปิด',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 18,
                ),
                onPressed: closeToastOnly,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================== Dial helpers ==================

  void _appendDial(String value) {
    setState(() {
      _numberController.text += value;
    });
  }

  void _backspaceDial() {
    if (_numberController.text.isEmpty) return;
    setState(() {
      _numberController.text =
          _numberController.text.substring(0, _numberController.text.length - 1);
      if (_numberController.text.isEmpty) {
        _activeAction = null;
      }
    });
  }

  void _clearDial() {
    setState(() {
      _numberController.clear();
      _activeAction = null;
    });
  }

  void _setDial(String value) {
    setState(() {
      _numberController.text = value;
      _activeAction = null;
    });
  }

  // ================== Simulate Call ==================

  void _simulateOutgoingCall() {
    if (!_hasNumber) {
      setState(() {
        _statusText = 'กรุณากรอกหมายเลขโทรศัพท์';
      });
      return;
    }

    _stopIncomingRingtone();
    _toastTimer?.cancel();
    _showIncomingToast = false;
    _stopAnswerButtonAnimation();

    setState(() {
      _hasIncoming = false;
      _incomingIsVideo = false;
      _isInVideoCall = false;
      _callState = CallState.dialing;
      _statusText = 'กำลังโทรออกไปยัง ${_numberController.text} ...';
      _requestStatus = 'Sending INVITE';
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _callState = CallState.ringing;
        _statusText = 'กำลังส่งเสียงเรียกไปยัง ${_numberController.text} ...';
        _requestStatus = '180 Ringing';
      });
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _callState = CallState.inCall;
        _statusText = 'กำลังสนทนากับ ${_numberController.text}';
        _requestStatus = '200 OK';
        _isInVideoCall = true;
      });
    });
  }

  void _simulateHangup() {
    if (_callState == CallState.idle) return;

    _stopIncomingRingtone();
    _toastTimer?.cancel();
    _showIncomingToast = false;
    _stopAnswerButtonAnimation();

    setState(() {
      _callState = CallState.ended;
      _statusText = 'สายสิ้นสุด';
      _requestStatus = 'BYE / 200 OK';
      _activeAction = null;
      _hasIncoming = false;
      _incomingIsVideo = false;
      _isInVideoCall = false;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _callState = CallState.idle;
        _statusText = 'พร้อมใช้งาน';
        _requestStatus = 'Idle';
      });
    });
  }

  bool get _isOnCallPhase =>
      _callState == CallState.dialing ||
      _callState == CallState.ringing ||
      _callState == CallState.inCall;

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
  }

  void _onTestCall() {
    const incomingNo = '3001';
    final contactName = _findContactName(incomingNo);

    _startAnswerButtonAnimation();

    setState(() {
      _hasIncoming = true;
      _incomingNumber = incomingNo;
      _incomingName = contactName ?? incomingNo;
      _incomingIsVideo = true;
      _isInVideoCall = false;

      _callState = CallState.ringing;
      _statusText = 'สายวิดีโอเรียกเข้าจาก $incomingNo';
      _requestStatus = 'Incoming INVITE (video)';
    });

    _playIncomingRingtone();
    _showIncomingSosToast(incomingNo);
  }

  void _acceptIncoming() {
    if (!_hasIncoming) return;

    _stopIncomingRingtone();
    _toastTimer?.cancel();
    _showIncomingToast = false;
    _stopAnswerButtonAnimation();

    setState(() {
      final num = (_incomingNumber ?? '').trim();
      if (num.isNotEmpty) {
        _numberController.text = num;
      }

      _callState = CallState.inCall;
      _statusText = 'กำลังสนทนากับ $_incomingNumber';
      _requestStatus =
          _incomingIsVideo ? '200 OK (video)' : '200 OK (audio)';
      _isInVideoCall = _incomingIsVideo;
      _hasIncoming = false;
    });
  }

  void _rejectIncoming() {
    if (!_hasIncoming) return;

    _stopIncomingRingtone();
    _toastTimer?.cancel();
    _showIncomingToast = false;
    _stopAnswerButtonAnimation();

    setState(() {
      _callState = CallState.ended;
      _statusText = 'ปฏิเสธสายเรียกเข้าแล้ว';
      _requestStatus = '486 Busy Here';
      _hasIncoming = false;
      _incomingIsVideo = false;
      _isInVideoCall = false;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _callState = CallState.idle;
        _statusText = 'พร้อมใช้งาน';
        _requestStatus = 'Idle';
      });
    });
  }

  void _setTab(String tab) {
    setState(() {
      _selectedTab = tab;
    });
  }

  String? _findContactName(String number) {
    final norm = number.trim();
    try {
      return _contacts.firstWhere((c) => c.number.trim() == norm).name;
    } catch (_) {
      return null;
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _browseRecordFolder() async {
    final String? dirPath = await getDirectoryPath();
    if (dirPath != null) {
      setState(() {
        _recordFolderPath = dirPath;
        _recordFolderController.text = dirPath;
      });
    }
  }

  void _clearRecordFolder() {
    setState(() {
      _recordFolderPath = '';
      _recordFolderController.clear();
    });
  }

  void _saveSettings() {
    final input = _sipServerController.text.trim();

    if (input.isEmpty) {
      setState(() {
        _saveSuccess = false;
        _saveTitle = 'บันทึกไม่สำเร็จ';
        _saveSubtitle = 'กรุณากรอก SIP server ก่อนบันทึก';
        _showSaveOverlay = true;
      });
    } else {
      setState(() {
        _currentServer = input;
        _saveSuccess = true;
        _saveTitle = 'บันทึกสำเร็จแล้ว';
        _saveSubtitle = 'การตั้งค่าถูกบันทึกเรียบร้อย';
        _showSaveOverlay = true;
      });
    }

    Future.delayed(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      setState(() {
        _showSaveOverlay = false;
      });
    });
  }

  Future<void> _openManageContacts() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: const ManageContactsDialog(),
        );
      },
    );
  }

  List<CallLogItem> get _filteredCallLogs {
    if (_logSearchQuery.isEmpty) return _callLogs;
    final q = _logSearchQuery.toLowerCase();

    return _callLogs.where((log) {
      final num = log.number.toLowerCase();
      final contactName = _findContactName(log.number)?.toLowerCase() ?? '';

      String direction;
      if (log.missed && log.incoming) {
        direction = 'missed incoming';
      } else if (log.incoming && !log.missed) {
        direction = 'incoming';
      } else {
        direction = 'outgoing';
      }

      return num.contains(q) ||
          contactName.contains(q) ||
          direction.contains(q);
    }).toList();
  }

  Widget _buildSaveResultOverlay() {
    final Color mainColor =
        _saveSuccess ? Colors.green.shade500 : Colors.red.shade500;
    final Color borderColor =
        _saveSuccess ? Colors.green.shade200 : Colors.red.shade200;
    final IconData iconData = _saveSuccess ? Icons.check : Icons.close;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(
              color: borderColor,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      mainColor.withOpacity(0.95),
                      mainColor.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(
                  iconData,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _saveTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _saveSubtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================== BUILD ==================

  @override
  Widget build(BuildContext context) {
    final bool showToast = _showIncomingToast && _toastNumber != null;

    return Scaffold(
      backgroundColor: const Color(0xFFE3E3E3),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        toolbarHeight: 54,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF141E30),
                Color(0xFF243B55),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.phone_in_talk_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'SOS',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.play_circle_outline,
              color: Colors.white,
            ),
            tooltip: 'Test incoming call',
            onPressed: _onTestCall,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: IconButton(
              icon: const Icon(
                Icons.people_alt_outlined,
                color: Colors.white,
              ),
              tooltip: 'Manage contacts',
              onPressed: _openManageContacts,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              height: double.infinity,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 10,
                      spreadRadius: 1,
                      offset: Offset(0, 3),
                      color: Colors.black26,
                    ),
                  ],
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildLeftPanel(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 7,
                      child: _buildRightInfoPanel(),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 0,
              child: AnimatedSlide(
                offset: showToast ? Offset.zero : const Offset(1.05, 0),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: showToast ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 260),
                  child: showToast && _toastNumber != null
                      ? _buildIncomingToast(_toastNumber!)
                      : const SizedBox.shrink(),
                ),
              ),
            ),
            if (_showSaveOverlay)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: true,
                  child: Container(
                    color: Colors.black.withOpacity(0.12),
                    child: _buildSaveResultOverlay(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // -------------------- Left Panel --------------------
  Widget _buildLeftPanel() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDFD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Column(
        children: [
          _buildTopTabs(),
          const SizedBox(height: 8),
          Expanded(
            child: _buildSelectedTabContent(),
          ),
          const SizedBox(height: 8),
          _buildBottomStatusBar(),
        ],
      ),
    );
  }

  Widget _buildTopTabs() {
    final tabs = ['Phone', 'Logs', 'Contacts', 'Settings'];
    final selectedIndex = tabs.indexOf(_selectedTab).clamp(0, tabs.length - 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double tabWidth = constraints.maxWidth / tabs.length;

        return Container(
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFE4E4E4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                left: tabWidth * selectedIndex + 3,
                top: 3,
                bottom: 3,
                width: tabWidth - 6,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF141E30),
                        Color(0xFF243B55),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.35),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: tabs.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final label = entry.value;
                  final bool active = idx == selectedIndex;

                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _setTab(label),
                      child: Center(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w400,
                            color:
                                active ? Colors.white : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSelectedTabContent() {
    if (_selectedTab == 'Phone') {
      return Column(
        children: [
          _buildDialInputRow(),
          const SizedBox(height: 10),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _buildDialPad()),
                _buildCallControlRow(),
                const SizedBox(height: 4),
                _buildVolumeControls(),
              ],
            ),
          ),
        ],
      );
    } else if (_selectedTab == 'Logs') {
      return _buildCallLogList();
    } else if (_selectedTab == 'Contacts') {
      return _buildContactsList();
    } else {
      return _buildSettingsPanel();
    }
  }

  Widget _buildSettingsPanel() {
    final bool sipFocused = _sipFocus.hasFocus;
    final Color sipBorderColor =
        sipFocused ? Colors.blue.shade700 : Colors.black;

    final bool recordFocused = _recordFocus.hasFocus;
    final Color recordBorderColor =
        recordFocused ? Colors.blue.shade700 : Colors.black;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ----- SIP server -----
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SIP server',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 32,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: sipBorderColor, width: 1),
                      color: Colors.white,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: TextField(
                        controller: _sipServerController,
                        focusNode: _sipFocus,
                        style: const TextStyle(
                          fontSize: 15,
                        ),
                        textAlignVertical: TextAlignVertical.center,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ----- Recording folder -----
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recording folder',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: recordBorderColor,
                              width: 1,
                            ),
                            color: Colors.white,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: TextField(
                              controller: _recordFolderController,
                              focusNode: _recordFocus,
                              style: const TextStyle(
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              textAlignVertical: TextAlignVertical.center,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 30,
                          minHeight: 30,
                        ),
                        icon: const Icon(
                          Icons.folder_open,
                          size: 22,
                          color: Colors.black87,
                        ),
                        onPressed: _browseRecordFolder,
                        tooltip: 'เลือกโฟลเดอร์',
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 30,
                          minHeight: 30,
                        ),
                        icon: const Icon(
                          Icons.close,
                          size: 22,
                          color: Colors.black87,
                        ),
                        onPressed: _clearRecordFolder,
                        tooltip: 'ล้างค่า',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Spacer(),

          // 🔘 ปุ่มบันทึก
          Center(
            child: SizedBox(
              width: 100,
              height: 38,
              child: ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF141E30),
                        Color(0xFF243B55),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.10),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.save_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'บันทึก',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialInputRow() {
    final bool hasFocus = _numberFocus.hasFocus;

    final Color borderColor =
        hasFocus ? Colors.blue.shade700 : Colors.black;

    return SizedBox(
      height: 44,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1),
          color: Colors.white,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _numberController,
                  focusNode: _numberFocus,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              Container(
                width: 54,
                color: Colors.white,
                child: PopupMenuButton<String>(
                  tooltip: '',
                  color: Colors.white,
                  elevation: 6,
                  offset: const Offset(-291, 46),
                  constraints: const BoxConstraints(
                    minWidth: 346,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  onSelected: (value) {
                    _setDial(value);
                  },
                  itemBuilder: (context) {
                    return _recentDialList.map((e) {
                      return PopupMenuItem<String>(
                        value: e,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.history,
                              size: 18,
                              color: Colors.black54,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                e,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList();
                  },
                  child: const Center(
                    child: Icon(
                      Icons.arrow_drop_down,
                      size: 20,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialPad() {
    const dialButtons = [
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      '<',
      '0',
      'C',
    ];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: GridView.builder(
            itemCount: dialButtons.length,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 6,
              mainAxisSpacing: 3,
              childAspectRatio: 1.56,
            ),
            itemBuilder: (context, index) {
              final label = dialButtons[index];
              return _buildDialButton(label);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDialButton(String label) {
    final bool isUtility = (label == '<' || label == 'C');

    IconData? icon;
    String? textLabel;

    if (label == '<') {
      icon = Icons.backspace_outlined;
    } else if (label == 'C') {
      icon = Icons.clear;
    } else {
      textLabel = label;
    }

    return GestureDetector(
      onTap: () {
        _playKeyClick(label);

        if (label == 'C') {
          _clearDial();
        } else if (label == '<') {
          _backspaceDial();
        } else {
          _appendDial(label);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        decoration: BoxDecoration(
          color: isUtility
              ? const Color(0xFFF0F0F3)
              : const Color(0xFFFCFCFF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              offset: const Offset(0, 2),
              blurRadius: 4,
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.9),
              offset: const Offset(0, -1),
              blurRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: icon != null
              ? Icon(
                  icon,
                  size: 22,
                  color: Colors.black87,
                )
              : Text(
                  textLabel ?? '',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildCallControlRow() {
    final BorderRadius radius = BorderRadius.circular(8);

    Widget buildCallButton() {
      final bool isOutgoingRinging =
          (_callState == CallState.dialing ||
                  _callState == CallState.ringing) &&
              !_hasIncoming;
      final bool isInCall = _callState == CallState.inCall;
      final bool isIncomingRinging =
          _hasIncoming && _callState == CallState.ringing;

      final bool isHangupPhase = isOutgoingRinging || isInCall;

      bool enabled;
      String label;
      Color bgColor;
      Color textColor = Colors.black87;
      IconData icon;

      if (isHangupPhase) {
        enabled = true;
        label = 'Hang up';
        bgColor = const Color(0xFFEF5350);
        icon = Icons.call_end;
        textColor = Colors.white;
      } else if (_hasNumber && !isIncomingRinging) {
        enabled = true;
        label = 'Call';
        bgColor = const Color(0xFF66BB6A);
        icon = Icons.call;
        textColor = Colors.white;
      } else {
        enabled = false;
        label = 'Call';
        bgColor = const Color(0xFFF0F0F3);
        icon = Icons.call;
        textColor = Colors.grey.shade600;
      }

      return GestureDetector(
        onTap: !enabled
            ? null
            : () {
                if (isHangupPhase) {
                  _simulateHangup();
                } else {
                  _simulateOutgoingCall();
                }
              },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          padding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 10,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: radius,
            border: Border.all(
              color: Colors.grey.shade300,
              width: 1,
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                    BoxShadow(
                      color: Colors.white.withOpacity(0.9),
                      offset: const Offset(0, -1),
                      blurRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: textColor),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: buildCallButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildWindowsSlider({
    required double value,
    required ValueChanged<double> onChanged,
    required bool isDragging,
    required ValueChanged<double>? onChangeStart,
    required ValueChanged<double>? onChangeEnd,
  }) {
    final int percent = (value * 100).round();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        const double bubbleWidth = 40;
        const double bubbleHeight = 26;
        final double clampedValue = value.clamp(0.0, 1.0);
        final double left = (width - bubbleWidth) * clampedValue;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 6,
                activeTrackColor: Colors.blue,
                inactiveTrackColor: Colors.grey.shade300,
                thumbColor: Colors.white,
                overlayColor: Colors.transparent,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 8),
                trackShape: const RoundedRectSliderTrackShape(),
                showValueIndicator: ShowValueIndicator.never,
              ),
              child: Slider(
                min: 0,
                max: 1,
                value: value,
                onChanged: onChanged,
                onChangeStart: onChangeStart,
                onChangeEnd: onChangeEnd,
              ),
            ),
            if (isDragging)
              Positioned(
                left: left,
                top: -bubbleHeight - 4,
                child: Material(
                  color: Colors.white,
                  elevation: 4,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: bubbleWidth,
                    height: bubbleHeight,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: Text(
                      '$percent',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildVolumeControls() {
    return Column(
      children: [
        SizedBox(
          height: 34,
          child: Row(
            children: [
              IconButton(
                onPressed: _toggleSpeaker,
                icon: Icon(
                  _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                  size: 24,
                  color: _isSpeakerOn ? Colors.black87 : Colors.red,
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 2),
              const Text('0', style: TextStyle(fontSize: 13)),
              Expanded(
                child: _buildWindowsSlider(
                  value: _speakerVolume,
                  isDragging: _speakerDragging,
                  onChanged: (v) {
                    setState(() => _speakerVolume = v);
                  },
                  onChangeStart: (_) {
                    setState(() => _speakerDragging = true);
                  },
                  onChangeEnd: (_) {
                    setState(() => _speakerDragging = false);
                  },
                ),
              ),
              const SizedBox(width: 4),
              const Text('100', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        SizedBox(
          height: 34,
          child: Row(
            children: [
              IconButton(
                onPressed: _toggleMute,
                icon: Icon(
                  _isMuted ? Icons.mic_off : Icons.mic,
                  size: 24,
                  color: _isMuted ? Colors.red : Colors.black87,
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 2),
              const Text('0', style: TextStyle(fontSize: 13)),
              Expanded(
                child: _buildWindowsSlider(
                  value: _micGain,
                  isDragging: _micDragging,
                  onChanged: (v) {
                    setState(() => _micGain = v);
                  },
                  onChangeStart: (_) {
                    setState(() => _micDragging = true);
                  },
                  onChangeEnd: (_) {
                    setState(() => _micDragging = false);
                  },
                ),
              ),
              const SizedBox(width: 4),
              const Text('100', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------- Bottom Status Bar --------------------
  Widget _buildBottomStatusBar() {
    String statusLabel;
    Color statusColor;

    if (!_isOnline) {
      statusLabel = 'Offline';
      statusColor = Colors.redAccent;
    } else if (_requestStatus.toLowerCase().contains('timeout')) {
      statusLabel = 'Request timeout';
      statusColor = Colors.orangeAccent;
    } else {
      statusLabel = 'Online';
      statusColor = Colors.greenAccent;
    }

    return Container(
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF141E30),
            Color(0xFF243B55),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          // 🔵 สถานะ
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withOpacity(0.9),
                      blurRadius: 8,
                      spreadRadius: 0.5,
                    ),
                    BoxShadow(
                      color: statusColor.withOpacity(0.5),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                statusLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),

          const SizedBox(width: 12),
          Container(
            width: 1,
            height: 22,
            color: Colors.white.withOpacity(0.14),
          ),
          const SizedBox(width: 12),

          // 🧑‍💻 ชื่อ account
          Expanded(
            child: Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 20,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Tooltip(
                    message: _currentName,
                    waitDuration: const Duration(milliseconds: 500),
                    child: Text(
                      _currentName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),
          Row(
            children: [
              const Icon(
                Icons.call_outlined,
                size: 15,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                _currentExtension,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------- Right Panel --------------------
  Widget _buildRightInfoPanel() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCallStatusHeader(),
          const SizedBox(height: 8),
          Expanded(child: _buildIncomingArea()),
        ],
      ),
    );
  }

  Widget _buildCallStatusHeader() {
    Color color;
    IconData stateIcon;

    switch (_callState) {
      case CallState.idle:
        color = Colors.grey;
        stateIcon = Icons.pause_circle_filled_rounded;
        break;
      case CallState.dialing:
        color = Colors.blue;
        stateIcon = Icons.phone_forwarded_rounded;
        break;
      case CallState.ringing:
        color = Colors.orange;
        stateIcon = Icons.ring_volume_rounded;
        break;
      case CallState.inCall:
        color = Colors.green;
        stateIcon = Icons.call_rounded;
        break;
      case CallState.ended:
        color = Colors.red;
        stateIcon = Icons.call_end_rounded;
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF141E30),
            Color(0xFF243B55),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text(
            'สถานะการโทร',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 260,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  colors: [
                    color.withOpacity(0.95),
                    color.darken(0.12),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.18),
                  width: 1,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(
                      stateIcon,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Text(
                      _statusText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildIncomingArea() {
    // 🟢 สายเรียกเข้า
    if (_hasIncoming) {
      final displayNumber = (_incomingNumber ?? '').trim();
      final displayName =
          _incomingName ?? _findContactName(displayNumber) ?? displayNumber;

      final isVideo = _incomingIsVideo;

      Widget answerButton = ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        onPressed: _acceptIncoming,
        icon: const Icon(Icons.call, size: 18),
        label: const Text(
          'รับสาย',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      );

      if (_callState == CallState.ringing && _answerBtnAnimation != null) {
        answerButton = SlideTransition(
          position: _answerBtnAnimation!,
          child: answerButton,
        );
      }

      return Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade700),
              ),
              child: Stack(
                children: [
                  _buildCenterVideoBlock(
                    icon: isVideo ? Icons.videocam : Icons.call,
                    line1: displayName,
                    line2: displayNumber,
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 120,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        answerButton,
                        const SizedBox(width: 18),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          onPressed: _rejectIncoming,
                          icon: const Icon(Icons.call_end, size: 18),
                          label: const Text(
                            'วางสาย',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // 🟣 กำลังคุย (Video call)
    if (_isInVideoCall && _callState == CallState.inCall) {
      final displayNumber = (_incomingNumber ?? _numberController.text).trim();
      final displayName =
          _incomingName ?? _findContactName(displayNumber) ?? displayNumber;

      return Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade700),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.videocam,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
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
        ],
      );
    }

    // ⚪️ Idle
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade700),
            ),
            child: _buildCenterVideoBlock(
              icon: Icons.videocam,
              line1: 'พื้นที่แสดงวิดีโอเมื่อมีสายเรียกเข้า',
              line2: 'เมื่อมีสาย SOS ระบบจะแสดงภาพที่นี่',
            ),
          ),
        ),
      ],
    );
  }

  /// ใช้สร้างบล็อกไอคอนตรงกลางให้เหมือนกันทั้งตอน idle และตอนมีสายเข้า
  Widget _buildCenterVideoBlock({
    required IconData icon,
    required String line1,
    String? line2,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.06),
              border: Border.all(
                color: Colors.white.withOpacity(0.35),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 42,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            line1,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          if (line2 != null && line2.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              line2,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  // -------------------- Logs & Contacts --------------------
  Widget _buildCallLogList() {
    final logs = _filteredCallLogs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ListView.separated(
              itemCount: logs.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: Colors.grey.shade200,
              ),
              itemBuilder: (context, index) {
                final item = logs[index];
                return _buildCallLogTile(item);
              },
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 32,
          child: TextField(
            controller: _logSearchController,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 16),
              hintText: 'ค้นหาจากชื่อหรือเบอร์',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCallLogTile(CallLogItem item) {
    IconData icon;
    Color color;
    String directionTh;

    if (item.missed && item.incoming) {
      icon = Icons.call_missed;
      color = Colors.redAccent;
      directionTh = 'สายที่ไม่ได้รับ';
    } else if (item.incoming) {
      icon = Icons.call_received;
      color = Colors.green;
      directionTh = 'สายเข้า';
    } else {
      icon = Icons.call_made;
      color = Colors.blue;
      directionTh = 'สายออก';
    }

    final displayNumber = item.number.trim();
    final contactName = _findContactName(displayNumber);
    final bool hasContact = contactName != null && contactName.isNotEmpty;

    final String dateStr =
        '${item.time.day.toString().padLeft(2, '0')}/${item.time.month.toString().padLeft(2, '0')}/${item.time.year} '
        '${item.time.hour.toString().padLeft(2, '0')}:${item.time.minute.toString().padLeft(2, '0')}';

    String durationStr;
    if (item.duration == Duration.zero) {
      durationStr = '-';
    } else {
      durationStr =
          '${item.duration.inMinutes.toString().padLeft(2, '0')}:${(item.duration.inSeconds % 60).toString().padLeft(2, '0')}';
    }

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      onTap: () => _setDial(displayNumber),
      leading: Icon(
        icon,
        color: color,
        size: 22,
      ),
      title: hasContact
          ? RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: contactName,
                    style: kListTitleStyle,
                  ),
                  TextSpan(
                    text: ' ($displayNumber)',
                    style: kListTitleStyle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          : Text(
              displayNumber,
              style: kListTitleStyle,
            ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$directionTh • $dateStr',
            style: kListSubtitleStyle,
          ),
          Text(
            'ระยะเวลาการโทร $durationStr',
            style: kListSubtitleStyle,
          ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(
          Icons.call,
          size: 22,
        ),
        onPressed: () {
          _setDial(displayNumber);
          _simulateOutgoingCall();
        },
      ),
    );
  }

  Widget _buildContactsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ListView.separated(
              itemCount: _contacts.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (context, index) {
                final item = _contacts[index];
                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  onTap: () => _setDial(item.number),
                  leading: const Icon(Icons.person, size: 18),
                  title: Text(
                    item.name,
                    style: kListTitleStyle,
                  ),
                  subtitle: Text(
                    item.number,
                    style: kListSubtitleStyle,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.call, size: 18),
                    onPressed: () {
                      _setDial(item.number);
                      _simulateOutgoingCall();
                    },
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 32,
          child: TextField(
            controller: _contactSearchController,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 16),
              hintText: 'ค้นหาจากชื่อหรือเบอร์',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
          ),
        ),
      ],
    );
  }
}

/// extension สำหรับ darken สีในแถบสถานะการโทร
extension _ColorX on Color {
  Color darken([double amount = 0.18]) {
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}
