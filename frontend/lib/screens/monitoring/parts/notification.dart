// lib/screens/monitoring/parts/notification.dart

import 'package:flutter/material.dart';
import 'notification_mock.dart'; 

// Enum สำหรับกำหนดสถานะของ Tab
enum NotificationFilter { today, thisWeek, earlier }

class NotificationCenter extends StatefulWidget {
  final VoidCallback onClose; 
  final VoidCallback onMarkAllAsRead; 
  
  const NotificationCenter({
    super.key, 
    required this.onClose,
    required this.onMarkAllAsRead,
  });

  @override
  State<NotificationCenter> createState() => _NotificationCenterState();
}

class _NotificationCenterState extends State<NotificationCenter> {
  
  NotificationFilter _selectedFilter = NotificationFilter.today;
  late ScrollController _scrollController; 

  // List ที่จะถูกแก้ไขสถานะ isRead (Mutable)
  List<Map<String, dynamic>> _notifications = List.of(NotificationMock.rawMockData.map((map) => Map.of(map)));

  bool _markAllAsRead = false; 

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(); 
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onMarkAllAsRead() {
    setState(() {
      _markAllAsRead = true;
    });
    widget.onMarkAllAsRead(); 
  }

  void _markAsRead(int originalIndex) {
    if (_notifications[originalIndex]['isRead'] == false && !_markAllAsRead) {
        setState(() {
            _notifications[originalIndex]['isRead'] = true;
        });
    }
  }

  // *** 🎯 HELPER: คำนวณรูปแบบการแสดงเวลาตามเงื่อนไข (แก้ไขหน่วย ว. -> วิ.) ***
  String _getDisplayTime(DateTime timestamp) {
    final now = DateTime.now().toLocal();
    final itemTime = timestamp.toLocal();
    final difference = now.difference(itemTime);
    
    const Duration oneHour = Duration(hours: 1); 

    if (difference < oneHour) {
      // น้อยกว่า 1 ชั่วโมง: ใช้หน่วย นาที หรือ วินาที แบบย่อ
      if (difference.inMinutes > 0) {
        // 1 นาทีขึ้นไป แต่ไม่ถึง 1 ชั่วโมง
        return '${difference.inMinutes} น.'; // นาที -> น.
      } else {
        // น้อยกว่า 1 นาที
        // clamp(1, 59) เพื่อไม่ให้แสดง 0 วิ.
        // *** แก้ไข: เปลี่ยน 'ว.' เป็น 'วิ.' ***
        return '${difference.inSeconds.clamp(1, 59)} วิ.'; // วินาที -> วิ.
      }
    } else {
      // 1 ชั่วโมงขึ้นไป: แสดงเป็นเวลาจริง (HH:mm น.) 
      final hour = itemTime.hour.toString().padLeft(2, '0');
      final minute = itemTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute น.';
    }
  }
  // ***************************************************************

  // *** HELPER: ตรวจสอบว่าวันที่เดียวกันหรือไม่ ***
  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // *** HELPER: สร้างข้อความวันที่ภาษาไทย ***
  String _getFormattedDate(DateTime timestamp) {
    final now = DateTime.now().toLocal();
    final date = timestamp.toLocal();
    
    // Normalize to start of day
    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(date.year, date.month, date.day);
    final difference = today.difference(itemDate).inDays;
    
    const List<String> thaiMonths = [
      '', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
    ];
    const List<String> thaiWeekdays = [
      'อาทิตย์', 'จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์'
    ];
    
    final int thaiYear = date.year + 543; 

    if (difference == 0) {
      return 'วันนี้';
    } else if (difference == 1) {
      return 'เมื่อวาน';
    } else {
      final weekdayIndex = date.weekday % 7; 
      final weekday = thaiWeekdays[weekdayIndex]; 
      final month = thaiMonths[date.month];
      
      return 'วัน$weekdayที่ ${date.day} $month $thaiYear';
    }
  }

  // *** WIDGET: ตัวคั่นวันที่ ***
  Widget _buildDateSeparator(String dateText) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              height: 1,
              color: const Color(0xFFBBBBBB), 
            ),
          ),
          Text(
            dateText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(left: 8),
              height: 1,
              color: const Color(0xFFBBBBBB), 
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = 380.0; 

    return Material(
      color: Colors.transparent, 
      child: Container(
        width: width,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75), 
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, 
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
            _buildTabs(),
            Expanded(
              child: _buildNotificationList(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8), 
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text( 
            'แจ้งเตือน',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFF333333),
            ),
          ),
          Row(
            children: [
              // ปุ่ม 'อ่านทั้งหมด'
              TextButton(
                onPressed: _onMarkAllAsRead, 
                child: const Text('อ่านทั้งหมด', style: TextStyle(color: Colors.blue, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Padding( 
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildTabButton('วันนี้', NotificationFilter.today),
          const SizedBox(width: 8),
          _buildTabButton('สัปดาห์นี้', NotificationFilter.thisWeek),
          const SizedBox(width: 8),
          _buildTabButton('ก่อนหน้า', NotificationFilter.earlier),
        ],
      ),
    );
  }

  Widget _buildTabButton(String text, NotificationFilter filter) {
    final isSelected = _selectedFilter == filter;
    
    const baseColor = Color(0xFFF0F0F0); 
    const activeColor = Colors.blue; 
    
    const pressedShadows = [
      BoxShadow(
        color: Color(0xFF757575), 
        offset: Offset(1.5, 1.5),
        blurRadius: 3,
        spreadRadius: 0,
      ),
      BoxShadow(
        color: Color.fromRGBO(255, 255, 255, 0.4), 
        offset: Offset(-1.5, -1.5),
        blurRadius: 3,
        spreadRadius: 0,
      ),
    ];

    const elevatedShadows = [
      BoxShadow(
        color: Color.fromRGBO(200, 200, 200, 0.5), 
        offset: Offset(4, 4),
        blurRadius: 8,
      ),
      BoxShadow(
        color: Color.fromRGBO(255, 255, 255, 0.8), 
        offset: Offset(-4, -4),
        blurRadius: 8,
      ),
    ];

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : baseColor, 
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected ? pressedShadows : elevatedShadows,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.grey[500], 
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationList() {
    
    final List<Map<String, dynamic>> notificationsToDisplay = [];
    final List<int> originalIndices = []; 
    
    final now = DateTime.now();
    const Duration oneDay = Duration(days: 1);
    const Duration oneWeek = Duration(days: 7);
    
    // กรองรายการตาม Tab ที่เลือก
    for (int i = 0; i < _notifications.length; i++) {
        final notif = _notifications[i];
        
        final timestamp = notif['timestamp']! as DateTime;
        final difference = now.toLocal().difference(timestamp.toLocal());
        
        bool passesFilter = false;

        switch (_selectedFilter) {
            case NotificationFilter.today:
                // วันนี้: แจ้งเตือนที่มีอายุไม่เกิน 1 วัน
                passesFilter = difference < oneDay;
                break;
            case NotificationFilter.thisWeek:
                // สัปดาห์นี้: แจ้งเตือนที่มีอายุไม่เกิน 7 วัน
                passesFilter = difference < oneWeek;
                break;
            case NotificationFilter.earlier:
                // ก่อนหน้า: แสดงทุกอย่าง
                passesFilter = true; 
                break;
        }

        if (passesFilter) {
            notificationsToDisplay.add(notif);
            originalIndices.add(i);
        }
    }
    
    if (notificationsToDisplay.isEmpty) {
        return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
                child: Text('ไม่มีการแจ้งเตือนสำหรับช่วงเวลานี้', 
                  style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
            ),
        );
    }
    
    final List<Widget> widgetsToDisplay = [];
    DateTime? lastDateDisplayed; 
    
    // *** LOGIC: ไม่แสดงตัวคั่นวันที่ใน Tab 'วันนี้' ***
    final bool showDateSeparator = _selectedFilter != NotificationFilter.today; 

    for (int index = 0; index < notificationsToDisplay.length; index++) {
      final notif = notificationsToDisplay[index];
      final originalIndex = originalIndices[index]; 
      final timestamp = notif['timestamp']! as DateTime;
      final itemDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
      
      // 1. ตรวจสอบและเพิ่มตัวคั่นวันที่ (เฉพาะใน Tab 'สัปดาห์นี้' และ 'ก่อนหน้า')
      if (showDateSeparator) { 
        final bool isNewDay = lastDateDisplayed == null || !isSameDay(lastDateDisplayed, itemDate);

        if (isNewDay) {
          final dateText = _getFormattedDate(timestamp);
          widgetsToDisplay.add(_buildDateSeparator(dateText));
          lastDateDisplayed = itemDate; 
        }
      }

      final bool currentIsRead = notif['isRead'] as bool || _markAllAsRead;

      // 2. สร้าง Widget สำหรับรายการแจ้งเตือน
      final itemWidget = _buildNotificationItem(
        notif['title'] as String,
        notif['subtitle'] as String,
        notif['icon'] as IconData,
        timestamp, 
        notif['color'] as Color,
        currentIsRead,
        originalIndex, 
      );
      
      // 3. เพิ่มรายการแจ้งเตือน
      widgetsToDisplay.add(itemWidget);

      // 4. เพิ่มเส้นแบ่งรายการ (หากไม่ใช่รายการสุดท้าย)
      if (index < notificationsToDisplay.length - 1) {
        final nextTimestamp = notificationsToDisplay[index + 1]['timestamp']! as DateTime;
        final nextItemDate = DateTime(nextTimestamp.year, nextTimestamp.month, nextTimestamp.day);
        
        // เพิ่มเส้นแบ่งแนวนอน: 
        // - เสมอใน Tab 'วันนี้' (เพราะไม่มีตัวคั่นวัน)
        // - ใน Tab อื่นๆ ถ้าวันเดียวกัน (ไม่ให้มีเส้นแบ่งระหว่างวัน)
        if (!showDateSeparator || isSameDay(itemDate, nextItemDate)) {
          widgetsToDisplay.add(
            const Divider(height: 1, thickness: 1, color: Color(0xFFBBBBBB), indent: 16, endIndent: 16)
          );
        }
      }
    }
    
    return Scrollbar(
      controller: _scrollController, 
      thumbVisibility: true,
      child: ListView.builder(
        controller: _scrollController, 
        padding: EdgeInsets.zero, 
        itemCount: widgetsToDisplay.length,
        itemBuilder: (context, index) {
          return widgetsToDisplay[index];
        },
      ),
    );
  }

  Widget _buildNotificationItem(
    String title,
    String subtitle,
    IconData icon,
    DateTime timestamp, 
    Color color, 
    bool isRead,
    int originalIndex, 
  ) {
    // --- 1. การคำนวณสไตล์ Title (ชื่อเหตุการณ์) ---
    final Color titleColor = isRead 
      ? Colors.grey[500]! 
      : color;            
      
    final titleWeight = isRead ? FontWeight.normal : FontWeight.bold;
    
    // itemTextColor ใช้สำหรับ Subtitle และ Time 
    final itemTextColor = isRead ? Colors.grey[500] : const Color(0xFF333333); 
    final itemBackgroundColor = isRead ? Colors.white : const Color(0xFFE8F2FF); 

    // กำหนด FontWeight สำหรับ Time Str: ตัวหนาเมื่อยังไม่ได้อ่าน
    final timeWeight = isRead ? FontWeight.normal : FontWeight.bold;
    
    // *** คำนวณ String เวลาที่จะแสดงผล (ใช้ Logic เวลาใหม่) ***
    final String displayTimeStr = _getDisplayTime(timestamp);

    // --- 2. การสร้าง Subtitle Widget (ชื่อโหนดเป็นตัวหนา) ---
    Widget subtitleWidget;
    const String prefix = 'เหตุการณ์: โหนด ';

    final bool hasPrefix = subtitle.startsWith(prefix);
    
    if (hasPrefix) {
      String content = subtitle.substring(prefix.length); 
      List<String> contentParts = content.split(' ');
      String nodeNameInSubtitle = contentParts.first; 
      String eventDescription = contentParts.sublist(1).join(' '); 
      
      String prefixText = prefix; 

      subtitleWidget = RichText(
          text: TextSpan(
              style: TextStyle(
                  fontSize: 12,
                  color: itemTextColor, // ใช้สีตามสถานะอ่าน/ไม่อ่าน
              ),
              children: <TextSpan>[
                  // 1. Prefix: 'เหตุการณ์: โหนด ' (Normal weight)
                  TextSpan(text: prefixText),
                  
                  // 2. Node Name ใน Subtitle: LIGHTING-1 (Bold เสมอ)
                  TextSpan(
                      text: nodeNameInSubtitle,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                      ), 
                  ),
                  
                  // 3. Rest of description: ' แรงดัน 250.0V...' (Normal weight)
                  TextSpan(
                      text: eventDescription.isNotEmpty ? ' $eventDescription' : '', 
                  ),
              ],
          ),
      );

    } else {
        // Fallback: หากรูปแบบ Subtitle ไม่ตรง ก็แสดงเป็น Text ธรรมดา
        subtitleWidget = Text(
            subtitle,
            style: TextStyle(
                fontSize: 12,
                color: itemTextColor,
            ),
        );
    }

    // --- 3. Return ListTile ---
    return Container(
      color: itemBackgroundColor,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              // ใช้ Title Weight ที่คำนวณจาก isRead
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: titleWeight, 
                  fontSize: 14,
                  color: titleColor,
                ),
              ),
            ),
            Text(
              displayTimeStr, // *** ใช้ displayTimeStr ที่คำนวณจาก _getDisplayTime ***
              style: TextStyle(
                fontSize: 12,
                color: itemTextColor,
                fontWeight: timeWeight,
              ),
            ),
          ],
        ),
        subtitle: subtitleWidget, // <<< ใช้ Subtitle Widget ที่สร้างใหม่
        // เมื่อคลิก ให้เรียก _markAsRead
        onTap: () {
          _markAsRead(originalIndex);
        },
      ),
    );
  }
}