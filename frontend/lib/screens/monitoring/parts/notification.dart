// lib/screens/monitoring/parts/notification.dart
import 'package:flutter/material.dart';

/// สรุป alarm ระดับโหนด (ใช้ 1 การ์ดต่อ 1 โหนดใน NotificationCenter)
class NodeAlarmSummary {
  final String nodeId; // devEui
  final String name; // ชื่อโหนด เช่น NODE1
  DateTime lastUpdated;
  /// key = field เช่น 'af_power', 'voltage', value = 0/1/2
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
  /// รายการสรุป alarm ระดับโหนด (ข้อมูลล่าสุดของแต่ละโหนด)
  final List<NodeAlarmSummary> items;

  /// ปิดแผงแจ้งเตือน
  final VoidCallback onClose;

  /// Mark all as read (parent จะจัดการ state แล้วส่ง items ใหม่กลับมาเอง)
  final VoidCallback onMarkAllAsRead;

  /// Mark หนึ่ง "โหนด" เป็นอ่านแล้ว — อ้างอิงด้วย nodeId (devEui)
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
              height: maxHeight, // ล็อกความสูง panel ให้คงที่ 75% ของจอ
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
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      _buildHeader(),
                      const Divider(height: 1, color: Color(0xFFE5E5E5)),
                      Expanded(
                        // ส่วนนี้จะเลื่อนขึ้นลงได้เมื่อการ์ดเยอะ
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
          Row(
            children: const [
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
          // ปุ่ม "อ่านทั้งหมด"
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
              s.fields.entries.where((e) => e.value != 0).toList();
          if (abnormalEntries.isEmpty) {
            // ป้องกันการ์ดว่าง (ส่วนใหญ่จะถูกลบตั้งแต่ใน parent แล้ว)
            return const SizedBox.shrink();
          }

          // ✅ ตัดสินสีตามระดับรุนแรงรวมของโหนด (1 = แดง, 2 = เหลือง, ทั้งคู่ = ส้ม)
          final bool hasRed = abnormalEntries.any((e) => e.value == 1);
          final bool hasYellow = abnormalEntries.any((e) => e.value == 2);

          final Color baseColor;
          if (hasRed && hasYellow) {
            baseColor = Colors.orange; // ทั้ง 1 และ 2 → ส้ม
          } else if (hasRed) {
            baseColor = Colors.red;
          } else if (hasYellow) {
            baseColor = Colors.yellow[700] ?? Colors.yellow;
          } else {
            baseColor = _accentColor;
          }

          final bool isRead = !s.hasUnread;

          final Color cardBg = Colors.white;
          final Color borderColor = const Color(0xFFCBD5E1);
          final Color titleColor =
              isRead ? const Color(0xFF4B5563) : const Color(0xFF111827);
          final Color subtitleColor = const Color(0xFF6B7280);

          final int abnormalCount = abnormalEntries.length;
          final String title = '${s.name} มี $abnormalCount ค่าผิดปกติ';

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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          // บรรทัดหัวข้อ + เวลา
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
                                    fontWeight: isRead
                                        ? FontWeight.w500
                                        : FontWeight.w700,
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
                                    '${_fieldLabel(e.key)}${_severityLabel(e.value)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      height: 1.2,
                                      color: subtitleColor,
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 6),

                          // สถานะอ่าน/ยังไม่อ่าน
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

  /// แปลงชื่อ key ใน alarms ให้เป็น label ภาษาไทยที่อ่านรู้เรื่อง
  /// รองรับทั้งชื่อเก่า-ใหม่จากฐานข้อมูลปัจจุบัน
  String _fieldLabel(String key) {
    switch (key) {
      case 'af_power':
      case 'afPower':
        return 'กำลังไฟรวม';
      case 'voltage':
      case 'dcV':
        return 'แรงดันไฟ DC';
      case 'current':
      case 'dcA':
        return 'กระแสไฟ DC';
      case 'dcW':
        return 'กำลังไฟ DC';
      case 'battery':
      case 'battery_filtered':
        return 'แบตเตอรี่';
      case 'solar_v':
      case 'solarV':
        return 'แรงดันโซลาร์';
      case 'solar_i':
      case 'solarI':
        return 'กระแสโซลาร์';
      case 'oat':
        return 'อุณหภูมิภายนอก';
      case 'rssi':
        return 'สัญญาณ RSSI';
      case 'snr':
        return 'ค่า SNR';
      default:
        return key; // ถ้าไม่รู้จักแสดง key ตรง ๆ
    }
  }

  String _severityLabel(int v) {
    switch (v) {
      case 1:
        return ' สูงผิดปกติ';
      case 2:
        return ' ต่ำผิดปกติ';
      default:
        return ' ผิดปกติ';
    }
  }
}
