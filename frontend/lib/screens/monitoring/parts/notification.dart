import 'package:flutter/material.dart';

/// สรุป alarm ระดับโหนด (ใช้ 1 การ์ดต่อ 1 โหนดใน NotificationCenter)
class NodeAlarmSummary {
  final String nodeId; // id ของโหนด (เช่น devEui หรือ "no1")
  final String name; // ชื่อโหนด เช่น NODE1
  DateTime lastUpdated;

  /// key = field เช่น
  /// - 'acVoltage' : 0 = ปกติ, 1 = over, 2 = under
  /// - 'acCurrent' : 0 = ปกติ, 1 = over
  /// - 'dcVoltage' : 0 = ปกติ, 1 = over, 2 = under
  /// - 'dcCurrent' : 0 = ปกติ, 1 = over
  /// - 'acSensor'  : 0 = ปกติ, 1 = sensor fault
  /// - 'dcSensor'  : 0 = ปกติ, 1 = sensor fault
  /// - 'oat'       : 0 = ไม่ได้ประกาศ, 1 = กำลังประกาศ
  ///
  /// value = int ตามสเปคด้านบน
  final Map<String, int> fields;

  bool hasUnread;

  NodeAlarmSummary({
    required this.nodeId,
    required this.name,
    required this.lastUpdated,
    Map<String, int>? fields,
    this.hasUnread = false,
  }) : fields = fields ?? {};
}

class NotificationCenter extends StatefulWidget {
  /// รายการสรุป alarm ระดับโหนด
  final List<NodeAlarmSummary> items;

  /// ปิดแผงแจ้งเตือน
  final VoidCallback onClose;

  /// Mark all as read (parent จะจัดการ state แล้วส่ง items ใหม่กลับมาเอง)
  final VoidCallback onMarkAllAsRead;

  /// Mark หนึ่ง "โหนด" เป็นอ่านแล้ว — อ้างอิงด้วย nodeId
  final void Function(String nodeId) onMarkOneAsRead;

  const NotificationCenter({
    super.key,
    required this.items,
    required this.onClose,
    required this.onMarkAllAsRead,
    required this.onMarkOneAsRead,
  });

  @override
  State<NotificationCenter> createState() => _NotificationCenterState();
}

class _NotificationCenterState extends State<NotificationCenter> {
  late final ScrollController _scroll;

  static const Color _accentColor = Color(0xFF48CAE4);
  static const Color _panelBg = Colors.white;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.75;

    // ใช้ Align + ConstrainedBox ภายในตัวเอง เพื่อไม่พึ่ง Positioned จากภายนอก
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, right: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 420,
          ),
          child: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: 380,
              height: maxHeight, // 🔹 ล็อกความสูง panel ให้คงที่ 75% ของจอ
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    color: _panelBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFCBD5E1),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.max, // 🔹 ให้กินความสูงเต็ม
                    children: [
                      _buildHeader(),
                      const Divider(height: 1, color: Color(0xFFE5E5E5)),
                      Expanded(
                        // 🔹 ส่วนนี้จะเลื่อนขึ้นลงได้เมื่อการ์ดเยอะ
                        child: _buildList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        children: [
          const Row(
            children: [
              Icon(
                Icons.notifications_active_outlined,
                size: 22,
                color: Color(0xFF111827),
              ),
              SizedBox(width: 8),
              Text(
                'การแจ้งเตือน',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const Spacer(),
          // 🔄 ปุ่ม "อ่านทั้งหมด" แบบไม่มี icon
          TextButton(
            onPressed: widget.onMarkAllAsRead,
            style: TextButton.styleFrom(
              foregroundColor: _accentColor,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
            ),
            child: const Text(
              'อ่านทั้งหมด',
              style: TextStyle(fontSize: 13),
            ),
          ),
          IconButton(
            tooltip: 'ปิด',
            icon: const Icon(Icons.close, size: 20),
            splashRadius: 20,
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (widget.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(
                Icons.notifications_off_outlined,
                size: 40,
                color: Color(0xFF9CA3AF),
              ),
              SizedBox(height: 8),
              Text(
                'ไม่มีการแจ้งเตือน',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // แสดงทุกการแจ้งเตือน เรียงตามเวลาล่าสุด
    final display = List<NodeAlarmSummary>.from(widget.items)
      ..sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));

    return Scrollbar(
      controller: _scroll,
      thumbVisibility: true,
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        itemCount: display.length,
        itemBuilder: (_, i) {
          final s = display[i];

          final abnormalEntries =
              s.fields.entries.where((e) => e.value != 0 || e.key == 'oat' || e.key == 'online').toList();
          if (abnormalEntries.isEmpty) {
            // ป้องกันการ์ดว่าง (ส่วนใหญ่จะถูกลบตั้งแต่ใน parent แล้ว)
            return const SizedBox.shrink();
          }

          // ✅ ตัดสิน "สี" ของการ์ดจาก field ทางไฟฟ้าเท่านั้น (ac/dc voltage/current/power)
          final criticalForColor = abnormalEntries.where((e) {
            final k = e.key;
            // oat/online ไม่ใช้ตัดสินสีแดง/เหลือง
            if (k == 'oat' || k == 'online') return false;
            return true;
          }).toList();

          final bool hasRed = criticalForColor.any((e) => e.value == 1);
          final bool hasYellow = criticalForColor.any((e) => e.value == 2);

          final Color baseColor;
          if (hasRed && hasYellow) {
            baseColor = Colors.orange; // ทั้ง 1 และ 2 → ส้ม
          } else if (hasRed) {
            baseColor = Colors.red;
          } else if (hasYellow) {
            baseColor = Colors.yellow[700] ?? Colors.yellow;
          } else {
            // กรณีไม่มี critical field (มีแต่ oat/online หรือ field อื่นที่ไม่อันตราย)
            baseColor = _accentColor;
          }

          final bool isRead = !s.hasUnread;

          const Color cardBg = Colors.white;
          const Color borderColor = Color(0xFFCBD5E1);
          final Color titleColor =
              isRead ? const Color(0xFF4B5563) : const Color(0xFF111827);
          const Color subtitleColor = Color(0xFF6B7280);

          final int abnormalCount = abnormalEntries.length;
          final String title = '${s.name} มี $abnormalCount ค่าผิดปกติ/สถานะสำคัญ';

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => widget.onMarkOneAsRead(s.nodeId),
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor, width: 1),
                  boxShadow: [
                    if (!isRead)
                      BoxShadow(
                        color: baseColor.withOpacity(0.22),
                        blurRadius: 12,
                        spreadRadius: 1,
                        offset: const Offset(0, 5),
                      )
                    else
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // วงกลมไอคอนหลัก
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: baseColor.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: baseColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // ข้อความ
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight:
                                        isRead ? FontWeight.w500 : FontWeight.w700,
                                    color: titleColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    size: 13,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    _timeAgo(s.lastUpdated),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // รายละเอียดแต่ละ field แบบ chip
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              for (final e in abnormalEntries)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: baseColor.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '${_fieldLabel(e.key)}${_severityLabel(e.key, e.value)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      height: 1.2,
                                      color: subtitleColor,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (!isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: baseColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              if (!isRead) const SizedBox(width: 4),
                              if (!isRead)
                                const Text(
                                  'ยังไม่ได้อ่าน',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _timeAgo(DateTime ts) {
    final diff = DateTime.now().difference(ts);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  /// แปลงชื่อ key ใน alarms → prefix ภาษาไทย
  ///
  /// รองรับทั้ง key เก่า (voltage/current/dcV/dcA/dcW) และ key ใหม่จาก backend
  /// (acVoltage, acCurrent, dcVoltage, dcCurrent, acSensor, dcSensor, oat, online)
  String _fieldLabel(String key) {
    switch (key) {
      // เดิม
      case 'voltage':
      case 'dcV':
        return 'แรงดันไฟ ';
      case 'current':
      case 'dcA':
        return 'กระแสไฟ ';
      case 'watt':
      case 'power':
      case 'dcW':
        return 'กำลังไฟ ';
      case 'oat':
        return 'สถานะประกาศ ';
      // ใหม่จาก backend
      case 'acVoltage':
        return 'แรงดัน AC ';
      case 'acCurrent':
        return 'กระแส AC ';
      case 'dcVoltage':
        return 'แรงดัน DC ';
      case 'dcCurrent':
        return 'กระแส DC ';
      case 'acSensor':
        return 'เซนเซอร์ AC ';
      case 'dcSensor':
        return 'เซนเซอร์ DC ';
      case 'online':
        return 'สถานะเชื่อมต่อ ';
      default:
        return '$key ';
    }
  }

  /// แปลค่าระดับความผิดปกติ ตามชนิด field
  ///
  /// สเปคใหม่จาก backend:
  /// - acVoltage / dcVoltage:
  ///     0 = normal, 1 = over, 2 = under
  /// - acCurrent / dcCurrent:
  ///     0 = normal, 1 = over
  /// - acSensor / dcSensor:
  ///     0 = normal, 1 = sensor false
  /// - oat:
  ///     0 = ไม่ได้ประกาศ, 1 = กำลังประกาศ
  /// - online: (ถ้าเคยใช้)
  ///     0 = ออฟไลน์, 1 = ออนไลน์
  String _severityLabel(String key, int v) {
    // oat = สถานะประกาศเสียง
    if (key == 'oat') {
      switch (v) {
        case 1:
          return 'กำลังประกาศ';
        case 0:
          return 'ไม่ได้ประกาศ';
        default:
          return 'สถานะผิดปกติ';
      }
    }

    // สถานะ online/offline (ถ้ามีส่งมาใน alarms)
    if (key == 'online') {
      switch (v) {
        case 1:
          return 'ออนไลน์';
        case 0:
          return 'ออฟไลน์';
        default:
          return 'สถานะไม่ทราบ';
      }
    }

    // กระแสไฟ (เดิม + ใหม่)
    if (key == 'current' ||
        key == 'dcA' ||
        key == 'acCurrent' ||
        key == 'dcCurrent') {
      switch (v) {
        case 1:
          return 'กระแสเกิน (Over current)';
        case 0:
          return 'ปกติ';
        default:
          return 'ค่าผิดปกติ';
      }
    }

    // แรงดันไฟ (เดิม + ใหม่)
    if (key == 'acVoltage' ||
        key == 'dcVoltage' ||
        key == 'voltage' ||
        key == 'dcV') {
      switch (v) {
        case 1:
          return 'สูงผิดปกติ (Over voltage)';
        case 2:
          return 'ต่ำผิดปกติ (Under voltage)';
        case 0:
          return 'ปกติ';
        default:
          return 'ค่าผิดปกติ';
      }
    }

    // สถานะเซนเซอร์ AC/DC
    if (key == 'acSensor' || key == 'dcSensor') {
      switch (v) {
        case 0:
          return 'ปกติ';
        case 1:
          return 'เซนเซอร์ผิดปกติ';
        default:
          return 'สถานะผิดปกติ';
      }
    }

    // field ปกติอื่น ๆ: watt/power ฯลฯ
    switch (v) {
      case 1:
        return 'สูงผิดปกติ';
      case 2:
        return 'ต่ำผิดปกติ';
      case 0:
        return 'ปกติ';
      default:
        return 'ผิดปกติ';
    }
  }
}
