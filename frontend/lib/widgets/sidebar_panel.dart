import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smart_control/routes/app_routes.dart';

typedef LogoutCallback = void Function();

class SidebarPanel extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final LogoutCallback onLogout;

  const SidebarPanel({
    Key? key,
    required this.isOpen,
    required this.onClose,
    required this.onLogout,
  }) : super(key: key);

  @override
  State<SidebarPanel> createState() => _SidebarPanelState();
}

class _SidebarPanelState extends State<SidebarPanel> {
  bool _isSettingsExpanded = false;

  // Sidebar menu configuration lives here. Add/remove items as needed.
  List<_MenuItem> get _menuItems => [
    _MenuItem(Icons.dashboard, 'หน้าหลัก', () {}),
    _MenuItem(
      Icons.playlist_add,
      'รายการเพลง',
      () => Get.toNamed(AppRoutes.playlist),
    ),
    _MenuItem(
      Icons.music_note,
      'อัปโหลดเพลง',
      () => Get.toNamed(AppRoutes.song),
    ),
    _MenuItem(
      Icons.multitrack_audio_rounded,
      'สตรีมเสียง',
      () => Get.toNamed(AppRoutes.stream),
    ),
    _MenuItem(
      Icons.monitor_rounded,
      'ตรวจสอบสถานะ',
      () => Get.toNamed(AppRoutes.monitoring),
    ),
    _MenuItem(Icons.logout, 'ออกจากระบบ', widget.onLogout),
  ];

  List<_MenuItem> get _settingsMenuItems => [
    _MenuItem(
      Icons.schedule_rounded,
      'ตั้งเวลาเปิดเพลง',
      () => Get.toNamed(AppRoutes.schedule),
    ),
    _MenuItem(
      Icons.settings,
      'ตั้งค่าระบบ',
      () => Get.toNamed(AppRoutes.system),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // overlay
        if (widget.isOpen)
          GestureDetector(
            onTap: widget.onClose,
            child: AnimatedOpacity(
              opacity: widget.isOpen ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(color: Colors.black),
            ),
          ),

        // sidebar
        AnimatedPositioned(
          duration: const Duration(milliseconds: 500),
          top: 0,
          bottom: 0,
          right: widget.isOpen ? 0 : -270,
          child: Container(
            width: 270,
            color: Colors.blue[900],
            padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                const Text(
                  'เมนูหลัก',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),
                ..._menuItems.map(
                  (m) => Column(
                    children: [
                      _buildMenuItem(m.icon, m.title, m.action),
                      const Divider(color: Colors.white12),
                      if (m.title == 'ตรวจสอบสถานะ') _buildSettingsDropdown(),
                    ],
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsDropdown() {
    return Column(
      children: [
        InkWell(
          onTap: () =>
              setState(() => _isSettingsExpanded = !_isSettingsExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Icon(Icons.settings, color: Colors.white, size: 22),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'การตั้งค่า',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                Icon(
                  _isSettingsExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            children: _settingsMenuItems
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(left: 38),
                    child: _buildMenuItem(item.icon, item.title, item.action),
                  ),
                )
                .toList(),
          ),
          crossFadeState: _isSettingsExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
        const Divider(color: Colors.white12),
      ],
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        onTap();
        widget.onClose();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final VoidCallback action;

  _MenuItem(this.icon, this.title, this.action);
}
