import 'package:flutter/material.dart';

class SosLogRowData {
  final String number;
  final String? contactName;
  final DateTime time;
  final Duration duration;
  final bool incoming;
  final bool missed;

  const SosLogRowData({
    required this.number,
    required this.time,
    required this.duration,
    required this.incoming,
    required this.missed,
    this.contactName,
  });
}

class SosLogsTab extends StatelessWidget {
  final List<SosLogRowData> logs;
  final TextEditingController searchController;
  final void Function(String number) onTapDial;
  final void Function(String number) onTapCall;

  // styles (ส่งมาเพื่อให้เหมือนเดิม)
  final TextStyle titleStyle;
  final TextStyle subtitleStyle;

  const SosLogsTab({
    super.key,
    required this.logs,
    required this.searchController,
    required this.onTapDial,
    required this.onTapCall,
    required this.titleStyle,
    required this.subtitleStyle,
  });

  @override
  Widget build(BuildContext context) {
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
                return _LogTile(
                  item: item,
                  onTapDial: onTapDial,
                  onTapCall: onTapCall,
                  titleStyle: titleStyle,
                  subtitleStyle: subtitleStyle,
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 32,
          child: TextField(
            controller: searchController,
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

class _LogTile extends StatelessWidget {
  final SosLogRowData item;
  final void Function(String number) onTapDial;
  final void Function(String number) onTapCall;
  final TextStyle titleStyle;
  final TextStyle subtitleStyle;

  const _LogTile({
    required this.item,
    required this.onTapDial,
    required this.onTapCall,
    required this.titleStyle,
    required this.subtitleStyle,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    String directionTh;

    if (item.missed && item.incoming) {
      icon = Icons.call_missed;
      color = Colors.redAccent;
      directionTh = 'สายที่ไม่ได้รับ';
    } else if (item.missed && !item.incoming) {
      icon = Icons.call_missed_outgoing;
      color = Colors.redAccent;
      directionTh = 'โทรไม่สำเร็จ';
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
    final contactName = item.contactName;
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
      onTap: () => onTapDial(displayNumber),
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
                    style: titleStyle,
                  ),
                  TextSpan(
                    text: ' ($displayNumber)',
                    style: titleStyle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          : Text(
              displayNumber,
              style: titleStyle,
            ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$directionTh • $dateStr',
            style: subtitleStyle,
          ),
          Text(
            'ระยะเวลาการโทร $durationStr',
            style: subtitleStyle,
          ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.call, size: 22),
        onPressed: () => onTapCall(displayNumber),
      ),
    );
  }
}
