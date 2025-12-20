import 'package:flutter/material.dart';

class SosDialSection extends StatelessWidget {
  final TextEditingController numberController;
  final FocusNode numberFocus;

  final List<String> recentDialList;
  final ValueChanged<String> onRecentSelected;

  final void Function(String key) onDialKeyTap;

  // call state (ส่งมาเป็น index กัน cycle กับ enum)
  final int callStateIndex; // 0 idle,1 dialing,2 ringing,3 inCall,4 ended
  final bool hasIncoming;
  final bool hasNumber;

  final VoidCallback onCallOrHangup;

  // volume
  final bool isSpeakerOn;
  final bool isMuted;
  final double speakerVolume;
  final double micGain;
  final bool speakerDragging;
  final bool micDragging;

  final VoidCallback onToggleSpeaker;
  final VoidCallback onToggleMute;
  final ValueChanged<double> onSpeakerChanged;
  final ValueChanged<double> onMicChanged;
  final ValueChanged<double> onSpeakerDragStart;
  final ValueChanged<double> onSpeakerDragEnd;
  final ValueChanged<double> onMicDragStart;
  final ValueChanged<double> onMicDragEnd;

  const SosDialSection({
    super.key,
    required this.numberController,
    required this.numberFocus,
    required this.recentDialList,
    required this.onRecentSelected,
    required this.onDialKeyTap,
    required this.callStateIndex,
    required this.hasIncoming,
    required this.hasNumber,
    required this.onCallOrHangup,
    required this.isSpeakerOn,
    required this.isMuted,
    required this.speakerVolume,
    required this.micGain,
    required this.speakerDragging,
    required this.micDragging,
    required this.onToggleSpeaker,
    required this.onToggleMute,
    required this.onSpeakerChanged,
    required this.onMicChanged,
    required this.onSpeakerDragStart,
    required this.onSpeakerDragEnd,
    required this.onMicDragStart,
    required this.onMicDragEnd,
  });

  bool get _isDialingOrRinging =>
      callStateIndex == 1 || callStateIndex == 2;
  bool get _isInCall => callStateIndex == 3;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DialInputRow(
          numberController: numberController,
          numberFocus: numberFocus,
          recentDialList: recentDialList,
          onRecentSelected: onRecentSelected,
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: _DialPad(
                  onKeyTap: onDialKeyTap,
                ),
              ),
              _CallControlRow(
                hasNumber: hasNumber,
                hasIncoming: hasIncoming,
                isDialingOrRinging: _isDialingOrRinging,
                isInCall: _isInCall,
                onCallOrHangup: onCallOrHangup,
              ),
              const SizedBox(height: 4),
              _VolumeControls(
                isSpeakerOn: isSpeakerOn,
                isMuted: isMuted,
                speakerVolume: speakerVolume,
                micGain: micGain,
                speakerDragging: speakerDragging,
                micDragging: micDragging,
                onToggleSpeaker: onToggleSpeaker,
                onToggleMute: onToggleMute,
                onSpeakerChanged: onSpeakerChanged,
                onMicChanged: onMicChanged,
                onSpeakerDragStart: onSpeakerDragStart,
                onSpeakerDragEnd: onSpeakerDragEnd,
                onMicDragStart: onMicDragStart,
                onMicDragEnd: onMicDragEnd,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DialInputRow extends StatelessWidget {
  final TextEditingController numberController;
  final FocusNode numberFocus;
  final List<String> recentDialList;
  final ValueChanged<String> onRecentSelected;

  const _DialInputRow({
    required this.numberController,
    required this.numberFocus,
    required this.recentDialList,
    required this.onRecentSelected,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasFocus = numberFocus.hasFocus;
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
                  controller: numberController,
                  focusNode: numberFocus,
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
                  onSelected: onRecentSelected,
                  itemBuilder: (context) {
                    return recentDialList.map((e) {
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
}

class _DialPad extends StatelessWidget {
  final void Function(String key) onKeyTap;

  const _DialPad({
    required this.onKeyTap,
  });

  @override
  Widget build(BuildContext context) {
    const dialButtons = [
      '1', '2', '3',
      '4', '5', '6',
      '7', '8', '9',
      '<', '0', 'C',
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
              return _DialButton(
                label: label,
                onTap: () => onKeyTap(label),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DialButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DialButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
      onTap: onTap,
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
              ? Icon(icon, size: 22, color: Colors.black87)
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
}

class _CallControlRow extends StatelessWidget {
  final bool hasNumber;
  final bool hasIncoming;
  final bool isDialingOrRinging;
  final bool isInCall;
  final VoidCallback onCallOrHangup;

  const _CallControlRow({
    required this.hasNumber,
    required this.hasIncoming,
    required this.isDialingOrRinging,
    required this.isInCall,
    required this.onCallOrHangup,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(8);

    final bool isIncomingRinging = hasIncoming && isDialingOrRinging;
    final bool isHangupPhase = (isDialingOrRinging && !hasIncoming) || isInCall;

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
    } else if (hasNumber && !isIncomingRinging) {
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

    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: enabled ? onCallOrHangup : null,
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
            ),
          ),
        ],
      ),
    );
  }
}

class _VolumeControls extends StatelessWidget {
  final bool isSpeakerOn;
  final bool isMuted;
  final double speakerVolume;
  final double micGain;
  final bool speakerDragging;
  final bool micDragging;

  final VoidCallback onToggleSpeaker;
  final VoidCallback onToggleMute;

  final ValueChanged<double> onSpeakerChanged;
  final ValueChanged<double> onMicChanged;

  final ValueChanged<double> onSpeakerDragStart;
  final ValueChanged<double> onSpeakerDragEnd;
  final ValueChanged<double> onMicDragStart;
  final ValueChanged<double> onMicDragEnd;

  const _VolumeControls({
    required this.isSpeakerOn,
    required this.isMuted,
    required this.speakerVolume,
    required this.micGain,
    required this.speakerDragging,
    required this.micDragging,
    required this.onToggleSpeaker,
    required this.onToggleMute,
    required this.onSpeakerChanged,
    required this.onMicChanged,
    required this.onSpeakerDragStart,
    required this.onSpeakerDragEnd,
    required this.onMicDragStart,
    required this.onMicDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 34,
          child: Row(
            children: [
              IconButton(
                onPressed: onToggleSpeaker,
                icon: Icon(
                  isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                  size: 24,
                  color: isSpeakerOn ? Colors.black87 : Colors.red,
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 2),
              const Text('0', style: TextStyle(fontSize: 13)),
              Expanded(
                child: _WindowsSlider(
                  value: speakerVolume,
                  isDragging: speakerDragging,
                  onChanged: onSpeakerChanged,
                  onChangeStart: onSpeakerDragStart,
                  onChangeEnd: onSpeakerDragEnd,
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
                onPressed: onToggleMute,
                icon: Icon(
                  isMuted ? Icons.mic_off : Icons.mic,
                  size: 24,
                  color: isMuted ? Colors.red : Colors.black87,
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 2),
              const Text('0', style: TextStyle(fontSize: 13)),
              Expanded(
                child: _WindowsSlider(
                  value: micGain,
                  isDragging: micDragging,
                  onChanged: onMicChanged,
                  onChangeStart: onMicDragStart,
                  onChangeEnd: onMicDragEnd,
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
}

class _WindowsSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final bool isDragging;
  final ValueChanged<double> onChangeStart;
  final ValueChanged<double> onChangeEnd;

  const _WindowsSlider({
    required this.value,
    required this.onChanged,
    required this.isDragging,
    required this.onChangeStart,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
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
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
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
}
