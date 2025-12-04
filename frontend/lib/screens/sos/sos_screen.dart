// lib/screens/sos/sos_screen.dart
//
// หน้าจอ Softphone สำหรับ SOS / Call Center

import 'package:flutter/material.dart';

typedef Json = Map<String, dynamic>;

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

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  final TextEditingController _numberController = TextEditingController();
  final FocusNode _numberFocus = FocusNode();

  String _currentExtension = '2000';
  String _currentServer = 'raspberrypi.local';
  String _currentName = 'SOS Operator';

  CallState _callState = CallState.idle;
  String _statusText = 'Ready';
  bool _isOnline = true;
  bool _isMuted = false;
  bool _isSpeakerOn = true;

  bool _isDnd = false;
  bool _isAc = false;
  bool _isAa = false;

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
  String? _selectedRecentDial;

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
    ContactItem(name: 'Control Room', number: '2000'),
    ContactItem(name: 'Guard 1', number: '3001'),
    ContactItem(name: 'Guard 2', number: '3002'),
    ContactItem(name: 'Technician', number: '4001'),
  ];

  /// รายการ Account สำหรับ context menu ตอนคลิกขวา
  final List<String> _accounts = const [
    '1000',
    '200',
    '1010',
    '1001',
    '1000 FW',
    '2001',
    '1072',
  ];

  /// สายเรียกเข้า / วิดีโอคอล
  bool _hasIncoming = false;
  String? _incomingNumber;
  String? _incomingName;
  bool _incomingIsVideo = false;
  bool _isInVideoCall = false;

  @override
  void initState() {
    super.initState();
    _numberFocus.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _numberController.dispose();
    _numberFocus.dispose();
    super.dispose();
  }

  bool get _hasNumber => _numberController.text.trim().isNotEmpty;

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

  void _simulateOutgoingCall() {
    if (!_hasNumber) {
      setState(() {
        _statusText = 'Please enter a number';
      });
      return;
    }

    setState(() {
      _hasIncoming = false;
      _incomingIsVideo = false;
      _isInVideoCall = false;
      _callState = CallState.dialing;
      _statusText = 'Dialing ${_numberController.text} ...';
      _requestStatus = 'Sending INVITE';
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _callState = CallState.ringing;
        _statusText = 'Ringing ${_numberController.text} ...';
        _requestStatus = '180 Ringing';
      });
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _callState = CallState.inCall;
        _statusText = 'Talking with ${_numberController.text}';
        _requestStatus = '200 OK';
      });
    });
  }

  void _simulateHangup() {
    if (_callState == CallState.idle) return;
    setState(() {
      _callState = CallState.ended;
      _statusText = 'Call ended';
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
        _statusText = 'Ready';
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

  void _toggleDnd() {
    setState(() {
      _isDnd = !_isDnd;
    });
  }

  void _toggleAc() {
    setState(() {
      _isAc = !_isAc;
    });
  }

  void _toggleAa() {
    setState(() {
      _isAa = !_isAa;
    });
  }

  /// ปุ่ม Test: จำลอง "สายเรียกเข้าแบบวิดีโอคอล"
  void _onTestCall() {
    const incomingNo = '3001';
    final contactName = _findContactName(incomingNo);

    setState(() {
      _hasIncoming = true;
      _incomingNumber = incomingNo;
      _incomingName = contactName ?? incomingNo;
      _incomingIsVideo = true;
      _isInVideoCall = false;

      _callState = CallState.ringing;
      _statusText = 'Incoming video call from $incomingNo';
      _requestStatus = 'Incoming INVITE (video)';
    });
  }

  void _acceptIncoming() {
    if (!_hasIncoming) return;
    setState(() {
      _callState = CallState.inCall;
      _statusText = 'Talking with $_incomingNumber';
      _requestStatus =
          _incomingIsVideo ? '200 OK (video)' : '200 OK (audio)';
      _isInVideoCall = _incomingIsVideo;
      _hasIncoming = false;

      if (_incomingNumber != null) {
        _numberController.text = _incomingNumber!;
      }
    });
  }

  void _rejectIncoming() {
    if (!_hasIncoming) return;
    setState(() {
      _callState = CallState.ended;
      _statusText = 'Incoming call rejected';
      _requestStatus = '486 Busy Here';
      _hasIncoming = false;
      _incomingIsVideo = false;
      _isInVideoCall = false;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _callState = CallState.idle;
        _statusText = 'Ready';
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
    try {
      return _contacts.firstWhere((c) => c.number == number).name;
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

  /// เมนูคลิกขวาเฉพาะส่วน Name + Number (ไม่รวมปุ่ม Online)
  void _showAccountContextMenu(TapDownDetails details) async {
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx,
        details.globalPosition.dy,
      ),
      items: [
        ..._accounts.map(
          (acc) => PopupMenuItem<String>(
            value: acc,
            child: Row(
              children: [
                if (acc == _currentExtension)
                  const Icon(Icons.check, size: 16)
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 6),
                Text(acc),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'edit',
          child: Text('Edit Account'),
        ),
        const PopupMenuItem<String>(
          value: 'add',
          child: Text('Add Account'),
        ),
        const PopupMenuItem<String>(
          value: 'settings',
          child: Text('Settings'),
        ),
      ],
    );

    if (selected == null) return;

    setState(() {
      if (_accounts.contains(selected)) {
        _currentExtension = selected;
      } else if (selected == 'edit') {
        _showSnack('Open Edit Account (mock)');
      } else if (selected == 'add') {
        _showSnack('Open Add Account (mock)');
      } else if (selected == 'settings') {
        _showSnack('Open Settings (mock)');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS'),
        centerTitle: true,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFE3E3E3),
      body: SafeArea(
        child: Container(
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
      ),
    );
  }

  // -------------------- Left Panel : Phone / Logs / Contacts --------------------
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
            child: () {
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
                          const SizedBox(height: 8),
                          _buildVolumeControls(),
                          const SizedBox(height: 4),
                          _buildBottomFeatureButtons(),
                        ],
                      ),
                    ),
                  ],
                );
              } else if (_selectedTab == 'Logs') {
                return _buildCallLogList();
              } else {
                return _buildContactsList();
              }
            }(),
          ),
          const SizedBox(height: 8),
          _buildBottomStatusBar(),
        ],
      ),
    );
  }

  Widget _buildTopTabs() {
    Widget buildTab(String label) {
      final bool active = _selectedTab == label;
      return GestureDetector(
        onTap: () => _setTab(label),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: active
              ? BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade400),
                )
              : null,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        buildTab('Phone'),
        const SizedBox(width: 8),
        buildTab('Logs'),
        const SizedBox(width: 8),
        buildTab('Contacts'),
      ],
    );
  }

  /// ช่องกรอกเบอร์ + ดรอปดาวน์ในกรอบเดียวแบบ ComboBox
  Widget _buildDialInputRow() {
    final bool hasFocus = _numberFocus.hasFocus;
    final bool isOpen = _isDropdownOpen;

    final Color borderColor =
        (hasFocus || isOpen) ? Colors.blue.shade700 : Colors.black;
    final Color dropBgColor =
        isOpen ? const Color(0xFFE6F0FF) : Colors.white;

    return SizedBox(
      height: 30,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: borderColor, width: 1),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _numberController,
                focusNode: _numberFocus,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                ),
              ),
            ),
            Container(
              width: 30,
              color: dropBgColor,
              child: Theme(
                data: Theme.of(context).copyWith(
                  canvasColor: Colors.white,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRecentDial,
                    isDense: true,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, size: 16),
                    items: _recentDialList
                        .map(
                          (e) => DropdownMenuItem<String>(
                            value: e,
                            child: Text(
                              e,
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onTap: () {
                      setState(() {
                        _isDropdownOpen = true;
                      });
                    },
                    onChanged: (value) {
                      setState(() {
                        _selectedRecentDial = value;
                        _isDropdownOpen = false;
                      });
                      if (value != null) {
                        _setDial(value);
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
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
      '*',
      '0',
      '#',
      'R',
      '+',
      'C',
    ];

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            itemCount: dialButtons.length,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 6,
              mainAxisSpacing: 3,
              childAspectRatio: 2.1,
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
    final bool isUtility = (label == 'R' || label == '+' || label == 'C');

    return GestureDetector(
      onTap: () {
        if (label == 'C') {
          _clearDial();
        } else if (label == 'R') {
          _backspaceDial();
        } else {
          _appendDial(label);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade400),
          color: isUtility ? const Color(0xFFF2F2F2) : const Color(0xFFF7F7F7),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCallControlRow() {
    final BorderRadius radius = BorderRadius.circular(3);

    Widget buildSideButton({
      required IconData icon,
      required bool enabled,
      required VoidCallback? onTap,
    }) {
      Color bg;
      Color iconColor;

      if (!enabled) {
        bg = const Color(0xFFF5F5F5);
        iconColor = Colors.grey;
      } else {
        bg = const Color(0xFFE0E0E0);
        iconColor = Colors.black87;
      }

      return GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: Center(
            child: Icon(icon, size: 18, color: iconColor),
          ),
        ),
      );
    }

    Widget buildCallButton() {
      final bool onPhase = _isOnCallPhase;
      final bool enabled = onPhase || _hasNumber;

      Color bg;
      Color textColor;
      String label;

      if (!enabled) {
        bg = const Color(0xFFF0F0F0);
        textColor = Colors.grey;
        label = 'Call';
      } else if (onPhase) {
        bg = Colors.red.shade600;
        textColor = Colors.white;
        label = 'Hang up';
      } else {
        bg = Colors.green.shade600;
        textColor = Colors.white;
        label = 'Call';
      }

      return GestureDetector(
        onTap: !enabled
            ? null
            : () {
                if (onPhase) {
                  _simulateHangup();
                } else {
                  _simulateOutgoingCall();
                }
              },
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: buildSideButton(
              icon: Icons.videocam,
              enabled: _hasNumber,
              onTap: () {
                if (!_hasNumber) return;
                setState(() {
                  _activeAction = 'video';
                });
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 2,
            child: buildCallButton(),
          ),
        ],
      ),
    );
  }

  // -------------------- Slider แบบ Windows + bubble --------------------
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
                        fontSize: 11,
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
          height: 40,
          child: Row(
            children: [
              IconButton(
                onPressed: _toggleSpeaker,
                icon: Icon(
                  _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                  size: 18,
                  color: _isSpeakerOn ? Colors.black87 : Colors.red,
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
              const Text('0', style: TextStyle(fontSize: 11)),
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
              const Text('100', style: TextStyle(fontSize: 11)),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: Row(
            children: [
              IconButton(
                onPressed: _toggleMute,
                icon: Icon(
                  _isMuted ? Icons.mic_off : Icons.mic,
                  size: 18,
                  color: _isMuted ? Colors.red : Colors.black87,
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
              const Text('0', style: TextStyle(fontSize: 11)),
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
              const Text('100', style: TextStyle(fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomFeatureButtons() {
    return SizedBox(
      height: 30,
      child: Row(
        children: [
          _buildBottomMiniButton('DND', toggled: _isDnd, onTap: _toggleDnd),
          const SizedBox(width: 4),
          _buildBottomMiniButton('AC', toggled: _isAc, onTap: _toggleAc),
          const SizedBox(width: 4),
          _buildBottomMiniButton('AA', toggled: _isAa, onTap: _toggleAa),
          const SizedBox(width: 4),
          _buildBottomMiniButton('Test', onTap: _onTestCall),
        ],
      ),
    );
  }

  Widget _buildBottomMiniButton(
    String label, {
    bool toggled = false,
    VoidCallback? onTap,
  }) {
    return SizedBox(
      width: 60,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: BorderSide(
            color: toggled ? Colors.red : Colors.grey.shade400,
          ),
          backgroundColor: toggled ? Colors.red.shade50 : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: toggled ? Colors.red.shade700 : Colors.black,
          ),
        ),
      ),
    );
  }

  // -------------------- Right Panel (Status + Incoming / Video) --------------------
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
    String label;
    switch (_callState) {
      case CallState.idle:
        label = 'Idle';
        color = Colors.grey;
        break;
      case CallState.dialing:
        label = 'Dialing...';
        color = Colors.blue;
        break;
      case CallState.ringing:
        label = 'Ringing...';
        color = Colors.orange;
        break;
      case CallState.inCall:
        label = 'In Call';
        color = Colors.green;
        break;
      case CallState.ended:
        label = 'Ended';
        color = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFF7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(Icons.circle, size: 10, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: color),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _statusText,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  /// พื้นที่ตรงกลาง: รอสาย / แสดงสายเรียกเข้า / แสดงจอวิดีโอคอล
  Widget _buildIncomingArea() {
    // ถ้ามีสายเรียกเข้า
    if (_hasIncoming) {
      final displayName = _incomingName ?? _incomingNumber ?? '-';
      final displayNumber = _incomingNumber ?? '-';

      final isVideo = _incomingIsVideo;

      return Center(
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: const [
              BoxShadow(
                blurRadius: 10,
                offset: Offset(0, 4),
                color: Colors.black26,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isVideo ? Icons.videocam : Icons.person,
                size: 48,
                color: Colors.grey,
              ),
              const SizedBox(height: 8),
              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                displayNumber,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isVideo ? 'Incoming video call' : 'Incoming call',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _acceptIncoming,
                    icon: const Icon(Icons.call),
                    label: const Text('Answer'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _rejectIncoming,
                    icon: const Icon(Icons.call_end),
                    label: const Text('Reject'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // ถ้าอยู่ในวิดีโอคอลแล้ว ให้แสดง "จอสีดำ"
    if (_isInVideoCall && _callState == CallState.inCall) {
      final displayNumber = _incomingNumber ?? _numberController.text;
      final displayName =
          _incomingName ?? _findContactName(displayNumber) ?? displayNumber;

      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade700),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.videocam, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Video call with $displayName',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // ไม่มีสาย / ไม่ได้อยู่ในวิดีโอคอล
    return Center(
      child: Text(
        'Waiting for incoming call...',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // -------------------- Logs & Contacts list (ใช้ในแท็บซ้าย) --------------------
  Widget _buildCallLogList() {
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
              itemCount: _callLogs.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: Colors.grey.shade200,
              ),
              itemBuilder: (context, index) {
                final item = _callLogs[index];
                return _buildCallLogTile(item);
              },
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
      color = Colors.red;
      directionTh = 'โทรเข้ามาไม่รับสาย';
    } else if (item.incoming && !item.missed) {
      icon = Icons.call_received;
      color = Colors.green;
      directionTh = 'โทรเข้ามารับสาย';
    } else {
      icon = Icons.call_made;
      color = Colors.blue;
      directionTh = 'โทรออก';
    }

    final contactName = _findContactName(item.number);
    final String titleText = (contactName != null && contactName.isNotEmpty)
        ? '$contactName(${item.number})'
        : item.number;

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
      onTap: () => _setDial(item.number),
      leading: Icon(
        icon,
        color: color,
        size: 22,
      ),
      title: Text(titleText),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$directionTh • $dateStr',
            style: const TextStyle(fontSize: 11),
          ),
          Text(
            'ระยะเวลาการโทร $durationStr',
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(
          Icons.call,
          size: 22,
        ),
        onPressed: () {
          _setDial(item.number);
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
                  title: Text(item.name),
                  subtitle: Text(item.number),
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
      ],
    );
  }

  // -------------------- Bottom Status Bar --------------------
  Widget _buildBottomStatusBar() {
    String statusLabel;
    Color statusColor;

    if (!_isOnline) {
      statusLabel = 'Offline';
      statusColor = Colors.red;
    } else if (_requestStatus.toLowerCase().contains('timeout')) {
      statusLabel = 'Request timeout';
      statusColor = Colors.orange;
    } else {
      statusLabel = 'Online';
      statusColor = Colors.green;
    }

    final String numberText = 'Number: $_currentExtension';

    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFFEDEDED),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade400),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // ส่วนสถานะ Online ห้ามคลิกขวา
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Icon(Icons.circle, size: 8, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 12),
          // ส่วน Name + Number คลิกขวาได้
          Expanded(
            child: GestureDetector(
              onSecondaryTapDown: _showAccountContextMenu,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Name: $_currentName',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Text(
                    numberText,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
