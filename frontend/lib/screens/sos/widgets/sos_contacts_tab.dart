import 'package:flutter/material.dart';

class SosContactRowData {
  final String name;
  final String number;

  const SosContactRowData({
    required this.name,
    required this.number,
  });
}

class SosContactsTab extends StatelessWidget {
  final List<SosContactRowData> contacts;
  final TextEditingController searchController;
  final void Function(String number) onTapDial;
  final void Function(String number) onTapCall;

  final TextStyle titleStyle;
  final TextStyle subtitleStyle;

  const SosContactsTab({
    super.key,
    required this.contacts,
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
              itemCount: contacts.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (context, index) {
                final item = contacts[index];
                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  onTap: () => onTapDial(item.number),
                  leading: const Icon(Icons.person, size: 18),
                  title: Text(item.name, style: titleStyle),
                  subtitle: Text(item.number, style: subtitleStyle),
                  trailing: IconButton(
                    icon: const Icon(Icons.call, size: 18),
                    onPressed: () => onTapCall(item.number),
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
