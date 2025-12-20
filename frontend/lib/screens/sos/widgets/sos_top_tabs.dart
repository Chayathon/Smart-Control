import 'package:flutter/material.dart';

class SosTopTabs extends StatelessWidget {
  final List<String> tabs;
  final String selected;
  final ValueChanged<String> onSelect;

  const SosTopTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final selectedIndex = tabs.indexOf(selected).clamp(0, tabs.length - 1);

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
                      onTap: () => onSelect(label),
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
}
