import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smart_control/routes/app_routes.dart';

typedef LogoutCallback = void Function();

class SidebarPanel extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final LogoutCallback onLogout;

  const SidebarPanel({
    Key? key,
    required this.isOpen,
    required this.onClose,
    required this.onLogout,
  }) : super(key: key);

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
      Icons.monitor_rounded,
      'ตรวจสอบสถานะ',
      () => Get.toNamed(AppRoutes.monitoring),
    ),
    _MenuItem(Icons.mic, 'ทดสอบไมค์', () => Get.toNamed(AppRoutes.test)),
    _MenuItem(Icons.logout, 'ออกจากระบบ', onLogout),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // overlay
        if (isOpen)
          GestureDetector(
            onTap: onClose,
            child: AnimatedOpacity(
              opacity: isOpen ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(color: Colors.black),
            ),
          ),

        // sidebar
        AnimatedPositioned(
          duration: const Duration(milliseconds: 500),
          top: 0,
          bottom: 0,
          right: isOpen ? 0 : -270,
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

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        onTap();
        onClose();
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
