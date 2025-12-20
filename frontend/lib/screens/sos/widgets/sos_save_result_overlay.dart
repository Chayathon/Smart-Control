//
// หน้าจอ Softphone สำหรับ SOS / Call Center

import 'dart:ui';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:sip_ua/sip_ua.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'manage_contacts.dart';

// widgets (แยกไฟล์)
import 'widgets/sos_top_tabs.dart';
import 'widgets/sos_dial_section.dart';
import 'widgets/sos_logs_tab.dart';
import 'widgets/sos_contacts_tab.dart';
import 'widgets/sos_settings_panel.dart';
import 'widgets/sos_bottom_status_bar.dart';
import 'widgets/sos_call_status_header.dart';
import 'widgets/sos_incoming_area.dart';
import 'widgets/sos_incoming_toast.dart';
import 'widgets/sos_save_result_overlay.dart';

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

// 🔑 Keys สำหรับ SharedPreferences
const String _kPrefsKeyLogFolder = 'sos_log_folder_path';
const String _kPrefsKeyRecordFolder = 'sos_record_folder_path';
const String _kPrefsKeySipServer = 'sos_sip_server';

enum CallState {
  idle,
  dialing,
  ringing,
  inCall,
  ended,
}

class CallLogItem {
  final String number; // หมายเลขอีกฝั่ง (remote)
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

  // 🔍 Search contacts
  final TextEditingController _contactSearchController =
      TextEditingController();

  // ⚙️ Settings
  final TextEditingController _sipServerController = TextEditingController();
  final FocusNode _sipFocus = FocusNode();

  // Recording folder (เก็บวิดีโอ)
  final TextEditingController _recordFolderController =
      TextEditingController();
  final FocusNode _recordFolderFocus = FocusNode();

  // Log folder
  final TextEditingController _logFolderController = TextEditingController();
  final FocusNode _logFolderFocus = FocusNode();

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

  /// 🔔 ประวัติการโทร (อ่านจากไฟล์ + เพิ่มใหม่)
  final List<CallLogItem> _callLogs = [];

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

  // path สำหรับ Recording และ Log
  String _recordFolderPath = '';
  String _logFolderPath = '';

  // 🎧 เสียง
  final AudioPlayer _keyPlayer = AudioPlayer();
  final AudioPlayer _ringPlayer = AudioPlayer();

  // 🔔 Toast SOS
  bool _showIncomingToast = false;
  String? _toastNumber;
  Timer? _toastTimer;

  // 💾 Overlay แสดงผลบันทึก settings
  bool _showSaveOverlay = false;
  bool _saveSuccess = true;
  String _saveTitle = '';
  String _saveSubtitle = '';

  // 🎬 ปุ่มรับสายกระดิก
  late final AnimationController _answerBtnController;
  Animation<Offset>? _answerBtnAnimation;

  // 🕒 ข้อมูลสายปัจจุบัน (ใช้สำหรับ log ลงไฟล์)
  DateTime? _callStartTime;
  bool _currentCallIsIncoming = false;
  String? _currentRemoteNumber;

  bool get _hasNumber => _numberController.text.trim().isNotEmpty;

  int get _callStateIndex {
    switch (_callState) {
      case CallState.idle:
        return 0;
      case CallState.dialing:
        return 1;
      case CallState.ringing:
        return 2;
      case CallState.inCall:
        return 3;
      case CallState.ended:
        return 4;
    }
  }

  @override
  void initState() {
    super.initState();

    // log folder default = โฟลเดอร์ที่รันโปรแกรมอยู่
    _logFolderPath = Directory.current.path;
    _logFolderController.text = _logFolderPath;

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

    // Recording folder listeners
    _recordFolderController.addListener(() {
      setState(() {
        _recordFolderPath = _recordFolderController.text;
      });
    });
    _recordFolderFocus.addListener(() {
      setState(() {});
    });

    // Log folder listeners
    _logFolderController.addListener(() {
      setState(() {
        _logFolderPath = _logFolderController.text;
      });
    });
    _logFolderFocus.addListener(() {
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

    // โหลดค่าที่เคยบันทึก (SIP + โฟลเดอร์ วิดีโอ + log)
    _loadPersistedSettings();
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
    _recordFolderFocus.dispose();

    _logFolderController.dispose();
    _logFolderFocus.dispose();

    _keyPlayer.dispose();
    _ringPlayer.dispose();
    _toastTimer?.cancel();
    _answerBtnController.dispose();
    super.dispose();
  }

  // ================== SharedPreferences helpers ==================

  Future<void> _loadPersistedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLogDir = prefs.getString(_kPrefsKeyLogFolder);
      final savedRecDir = prefs.getString(_kPrefsKeyRecordFolder);
      final savedSip = prefs.getString(_kPrefsKeySipServer);

      if (!mounted) return;

      setState(() {
        if (savedSip != null && savedSip.isNotEmpty) {
          _currentServer = savedSip;
          _sipServerController.text = savedSip;
        }

        if (savedRecDir != null && savedRecDir.isNotEmpty) {
          _recordFolderPath = savedRecDir;
          _recordFolderController.text = savedRecDir;
        }

        if (savedLogDir != null && savedLogDir.isNotEmpty) {
          _logFolderPath = savedLogDir;
          _logFolderController.text = savedLogDir;
        }
      });

      // หลังจากมี path ล่าสุดแล้ว โหลด logs ตามโฟลเดอร์นั้น
      await _loadLogsFromFile();
    } catch (e) {
      debugPrint('load prefs error: $e');
      await _loadLogsFromFile();
    }
  }

  Future<void> _persistSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefsKeySipServer, _currentServer);
      await prefs.setString(_kPrefsKeyRecordFolder, _recordFolderPath);
      await prefs.setString(_kPrefsKeyLogFolder, _logFolderPath);
    } catch (e) {
      debugPrint('save prefs error: $e');
    }
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

  void _closeToastOnly() {
    _toastTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _showIncomingToast = false;
    });
  }

  void _handleToastTapOpen() {
    _toastTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _showIncomingToast = false;
    });

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SosScreen(helper: widget.helper),
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

  void _handleDialKeyTap(String label) {
    _playKeyClick(label);

    if (label == 'C') {
      _clearDial();
    } else if (label == '<') {
      _backspaceDial();
    } else {
      _appendDial(label);
    }
  }

  // ================== Log helpers (ไฟล์ text) ==================

  String _buildLogFilePath() {
    final baseDir =
        _logFolderPath.isNotEmpty ? _logFolderPath : Directory.current.path;
    final sep = Platform.pathSeparator;
    if (baseDir.endsWith(sep)) {
      return '${baseDir}call_logs.txt';
    }
    return '$baseDir$sep'
        'call_logs.txt';
  }

  Future<void> _appendLogLine(CallLogItem item) async {
    try {
      final file = File(_buildLogFilePath());
      final t = item.time;
      final timeStr =
          '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

      final fromNumber = item.incoming ? item.number : _currentExtension;
      final toNumber = item.incoming ? _currentExtension : item.number;

      String event;
      if (item.missed && item.incoming) {
        event = 'สายที่ไม่ได้รับ';
      } else if (item.missed && !item.incoming) {
        event = 'โทรไม่สำเร็จ';
      } else if (item.incoming) {
        event = 'สายเข้า';
      } else {
        event = 'สายออก';
      }

      final minutes = item.duration.inSeconds / 60.0;
      final durationStr = minutes.toStringAsFixed(2);

      final line = '$timeStr|$fromNumber|$toNumber|$event|$durationStr\n';
      await file.writeAsString(line, mode: FileMode.append, flush: true);
    } catch (e) {
      debugPrint('append log error: $e');
    }
  }

  Future<void> _loadLogsFromFile() async {
    try {
      final file = File(_buildLogFilePath());
      if (!await file.exists()) {
        if (mounted) {
          setState(() {
            _callLogs.clear();
          });
        }
        return;
      }

      final lines = await file.readAsLines();
      final List<CallLogItem> items = [];

      for (final raw in lines) {
        final line = raw.trim();
        if (line.isEmpty) continue;

        final parts = line.split('|');
        if (parts.length < 5) continue;

        final timeStr = parts[0].trim();
        final fromNumber = parts[1].trim();
        final toNumber = parts[2].trim();
        final eventStr = parts[3].trim();
        final durationStr = parts[4].trim();

        DateTime time;
        try {
          time = DateTime.parse(timeStr);
        } catch (_) {
          time = DateTime.now();
        }

        bool incoming;
        bool missed;

        if (eventStr == 'สายเข้า') {
          incoming = true;
          missed = false;
        } else if (eventStr == 'สายออก') {
          incoming = false;
          missed = false;
        } else if (eventStr == 'สายที่ไม่ได้รับ') {
          incoming = true;
          missed = true;
        } else if (eventStr == 'โทรไม่สำเร็จ' || eventStr == 'วางก่อนรับ') {
          incoming = false;
          missed = true;
        } else {
          incoming = false;
          missed = false;
        }

        final minutes = double.tryParse(durationStr) ?? 0.0;
        final duration =
            Duration(milliseconds: (minutes * 60 * 1000).round());

        final remoteNumber = incoming ? fromNumber : toNumber;

        items.add(
          CallLogItem(
            number: remoteNumber,
            time: time,
            duration: duration,
            incoming: incoming,
            missed: missed,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _callLogs
          ..clear()
          ..addAll(items.reversed);
      });
    } catch (e) {
      debugPrint('load logs error: $e');
    }
  }

  void _finalizeAndLogCall() {
    if (_currentRemoteNumber == null || _currentRemoteNumber!.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final start = _callStartTime ?? now;
    final duration =
        _callStartTime == null ? Duration.zero : now.difference(start);

    final incoming = _currentCallIsIncoming;
    final missed = duration == Duration.zero;

    final item = CallLogItem(
      number: _currentRemoteNumber!,
      time: now,
      duration: duration,
      incoming: incoming,
      missed: missed,
    );

    setState(() {
      _callLogs.insert(0, item);
    });

    _appendLogLine(item);

    _callStartTime = null;
    _currentRemoteNumber = null;
    _currentCallIsIncoming = false;
  }

  // ================== Simulate Call ==================

  void _simulateOutgoingCall() {
    if (!_hasNumber) {
      setState(() {
        _statusText = 'กรุณากรอกหมายเลขโทรศัพท์';
      });
      return;
    }

    final targetNumber = _numberController.text.trim();

    _stopIncomingRingtone();
    _toastTimer?.cancel();
    _showIncomingToast = false;
    _stopAnswerButtonAnimation();

    setState(() {
      _currentCallIsIncoming = false;
      _currentRemoteNumber = targetNumber;
      _callStartTime = null;

      _hasIncoming = false;
      _incomingIsVideo = false;
      _isInVideoCall = false;
      _callState = CallState.dialing;
      _statusText = 'กำลังโทรออกไปยัง $targetNumber ...';
      _requestStatus = 'Sending INVITE';
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _callState = CallState.ringing;
        _statusText = 'กำลังส่งเสียงเรียกไปยัง $targetNumber ...';
        _requestStatus = '180 Ringing';
      });
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _callState = CallState.inCall;
        _statusText = 'กำลังสนทนากับ $targetNumber';
        _requestStatus = '200 OK';
        _isInVideoCall = true;
        _callStartTime = DateTime.now();
      });
    });
  }

  void _simulateHangup() {
    if (_callState == CallState.idle) return;

    _stopIncomingRingtone();
    _toastTimer?.cancel();
    _showIncomingToast = false;
    _stopAnswerButtonAnimation();

    _finalizeAndLogCall();

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

      _currentCallIsIncoming = true;
      _currentRemoteNumber = incomingNo;
      _callStartTime = null;

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

      _currentCallIsIncoming = true;
      _currentRemoteNumber ??= _incomingNumber;
      _callStartTime = DateTime.now();
    });
  }

  void _rejectIncoming() {
    if (!_hasIncoming) return;

    _stopIncomingRingtone();
    _toastTimer?.cancel();
    _showIncomingToast = false;
    _stopAnswerButtonAnimation();

    _finalizeAndLogCall();

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

  // เลือกโฟลเดอร์ Recording (วิดีโอ)
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

  // เลือกโฟลเดอร์ Log
  Future<void> _browseLogFolder() async {
    final String? dirPath = await getDirectoryPath();
    if (dirPath != null) {
      setState(() {
        _logFolderPath = dirPath;
        _logFolderController.text = dirPath;
      });
    }
  }

  void _clearLogFolder() {
    setState(() {
      _logFolderPath = '';
      _logFolderController.clear();
    });
  }

  Future<void> _saveSettings() async {
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

      await _persistSettings();
      await _loadLogsFromFile();
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
      } else if (log.missed && !log.incoming) {
        direction = 'missed outgoing';
      } else if (log.incoming) {
        direction = 'incoming';
      } else {
        direction = 'outgoing';
      }

      return num.contains(q) ||
          contactName.contains(q) ||
          direction.contains(q);
    }).toList();
  }

  // ================== BUILD ==================

  @override
  Widget build(BuildContext context) {
    final bool showToast = _showIncomingToast && _toastNumber != null;

    final toastDisplayName = () {
      final number = _toastNumber ?? '';
      final contactName = _findContactName(number);
      return contactName ?? number;
    }();

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
                  child: showToast
                      ? SosIncomingToast(
                          displayName: toastDisplayName,
                          onTapOpen: _handleToastTapOpen,
                          onClose: _closeToastOnly,
                        )
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
                    child: SosSaveResultOverlay(
                      success: _saveSuccess,
                      title: _saveTitle,
                      subtitle: _saveSubtitle,
                    ),
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
    final tabs = ['Phone', 'Logs', 'Contacts', 'Settings'];

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDFD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Column(
        children: [
          SosTopTabs(
            tabs: tabs,
            selected: _selectedTab,
            onSelect: _setTab,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _buildSelectedTabContent(),
          ),
          const SizedBox(height: 8),
          SosBottomStatusBar(
            isOnline: _isOnline,
            requestStatus: _requestStatus,
            currentName: _currentName,
            currentExtension: _currentExtension,
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedTabContent() {
    if (_selectedTab == 'Phone') {
      return SosDialSection(
        numberController: _numberController,
        numberFocus: _numberFocus,
        recentDialList: _recentDialList,
        onRecentSelected: _setDial,
        onDialKeyTap: _handleDialKeyTap,
        callStateIndex: _callStateIndex,
        hasIncoming: _hasIncoming,
        hasNumber: _hasNumber,
        onCallOrHangup: () {
          final bool isHangupPhase =
              ((_callState == CallState.dialing || _callState == CallState.ringing) &&
                  !_hasIncoming) ||
              _callState == CallState.inCall;

          if (isHangupPhase) {
            _simulateHangup();
          } else {
            _simulateOutgoingCall();
          }
        },
        isSpeakerOn: _isSpeakerOn,
        isMuted: _isMuted,
        speakerVolume: _speakerVolume,
        micGain: _micGain,
        speakerDragging: _speakerDragging,
        micDragging: _micDragging,
        onToggleSpeaker: _toggleSpeaker,
        onToggleMute: _toggleMute,
        onSpeakerChanged: (v) => setState(() => _speakerVolume = v),
        onMicChanged: (v) => setState(() => _micGain = v),
        onSpeakerDragStart: (_) => setState(() => _speakerDragging = true),
        onSpeakerDragEnd: (_) => setState(() => _speakerDragging = false),
        onMicDragStart: (_) => setState(() => _micDragging = true),
        onMicDragEnd: (_) => setState(() => _micDragging = false),
      );
    } else if (_selectedTab == 'Logs') {
      final rows = _filteredCallLogs.map((e) {
        return SosLogRowData(
          number: e.number,
          time: e.time,
          duration: e.duration,
          incoming: e.incoming,
          missed: e.missed,
          contactName: _findContactName(e.number),
        );
      }).toList();

      return SosLogsTab(
        logs: rows,
        searchController: _logSearchController,
        onTapDial: _setDial,
        onTapCall: (num) {
          _setDial(num);
          _simulateOutgoingCall();
        },
        titleStyle: kListTitleStyle,
        subtitleStyle: kListSubtitleStyle,
      );
    } else if (_selectedTab == 'Contacts') {
      final rows = _contacts
          .map((c) => SosContactRowData(name: c.name, number: c.number))
          .toList();

      return SosContactsTab(
        contacts: rows,
        searchController: _contactSearchController,
        onTapDial: _setDial,
        onTapCall: (num) {
          _setDial(num);
          _simulateOutgoingCall();
        },
        titleStyle: kListTitleStyle,
        subtitleStyle: kListSubtitleStyle,
      );
    } else {
      return SosSettingsPanel(
        sipServerController: _sipServerController,
        sipFocus: _sipFocus,
        recordFolderController: _recordFolderController,
        recordFolderFocus: _recordFolderFocus,
        logFolderController: _logFolderController,
        logFolderFocus: _logFolderFocus,
        onBrowseRecordFolder: _browseRecordFolder,
        onClearRecordFolder: _clearRecordFolder,
        onBrowseLogFolder: _browseLogFolder,
        onClearLogFolder: _clearLogFolder,
        onSave: _saveSettings,
      );
    }
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
          SosCallStatusHeader(
            callStateIndex: _callStateIndex,
            statusText: _statusText,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SosIncomingArea(
              hasIncoming: _hasIncoming,
              incomingNumber: _incomingNumber,
              incomingName: _incomingName ??
                  _findContactName((_incomingNumber ?? '').trim()) ??
                  (_incomingNumber ?? ''),
              incomingIsVideo: _incomingIsVideo,
              isInVideoCall: _isInVideoCall,
              callStateIndex: _callStateIndex,
              answerBtnAnimation: _answerBtnAnimation,
              onAccept: _acceptIncoming,
              onReject: _rejectIncoming,
            ),
          ),
        ],
      ),
    );
  }
}
