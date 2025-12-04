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

class _SidebarPanelState extends State<SidebarPanel>
    with SingleTickerProviderStateMixin {
  bool _isSettingsExpanded = false;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(covariant SidebarPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen != oldWidget.isOpen) {
      if (widget.isOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  List<_MenuItem> get _menuItems => [
    _MenuItem(Icons.dashboard_rounded, 'หน้าหลัก', () {}, isActive: true),
    _MenuItem(
      Icons.queue_music_rounded,
      'รายการเพลง',
      () => Get.toNamed(AppRoutes.playlist),
    ),
    _MenuItem(
      Icons.cloud_upload_rounded,
      'อัปโหลดเพลง',
      () => Get.toNamed(AppRoutes.song),
    ),
    _MenuItem(
      Icons.podcasts_rounded,
      'สตรีมเสียง',
      () => Get.toNamed(AppRoutes.stream),
    ),
    _MenuItem(
      Icons.monitor_heart_rounded,
      'ตรวจสอบสถานะ',
      () => Get.toNamed(AppRoutes.monitoring),
    ),
    _MenuItem(
      Icons.logout_rounded,
      'ออกจากระบบ',
      widget.onLogout,
      isDestructive: true,
    ),
  ];

  List<_MenuItem> get _settingsMenuItems => [
    _MenuItem(
      Icons.schedule_rounded,
      'ตั้งเวลาเปิดเพลง',
      () => Get.toNamed(AppRoutes.schedule),
    ),
    _MenuItem(
      Icons.mark_chat_unread_rounded,
      'แจ้งเตือนผ่าน LINE',
      () => Get.toNamed(AppRoutes.lineNotify),
    ),
    _MenuItem(
      Icons.tune_rounded,
      'ตั้งค่าระบบ',
      () => Get.toNamed(AppRoutes.system),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !widget.isOpen,
      child: Stack(
        children: [
          // Backdrop overlay
          FadeTransition(
            opacity: _fadeAnimation,
            child: GestureDetector(
              onTap: widget.onClose,
              child: Container(color: Colors.black54),
            ),
          ),

          // Sidebar panel
          Align(
            alignment: Alignment.centerRight,
            child: SlideTransition(
              position: _slideAnimation,
              child: RepaintBoundary(
                child: Container(
                  width: 300,
                  color: Colors.blue[900],
                  child: SafeArea(
                    child: Column(
                      children: [
                        // Header with profile
                        _buildHeader(),
                        // Menu items
                        Expanded(
                          child: ListView(
                            physics: const ClampingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            children: [
                              ..._menuItems.map((m) {
                                final menuWidget = _buildMenuItem(
                                  m.icon,
                                  m.title,
                                  m.action,
                                  isActive: m.isActive,
                                  isDestructive: m.isDestructive,
                                );
                                if (m.title == 'ตรวจสอบสถานะ') {
                                  return Column(
                                    children: [
                                      menuWidget,
                                      _buildSettingsDropdown(),
                                    ],
                                  );
                                }
                                return menuWidget;
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Close button
          Align(
            alignment: Alignment.centerRight,
            child: _buildIconButton(
              icon: Icons.close_rounded,
              onTap: widget.onClose,
            ),
          ),
          const SizedBox(height: 8),
          // Profile avatar
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.cyan.shade300, width: 2),
            ),
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white.withOpacity(0.1),
              child: const Icon(
                Icons.person_rounded,
                size: 45,
                color: Colors.white70,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // App title
          const Text(
            'Smart Control',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsDropdown() {
    return Column(
      children: [
        _buildMenuItem(
          Icons.settings_rounded,
          'การตั้งค่า',
          () => setState(() => _isSettingsExpanded = !_isSettingsExpanded),
          trailing: AnimatedRotation(
            turns: _isSettingsExpanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: Icon(
              Icons.expand_more_rounded,
              color: Colors.white.withOpacity(0.7),
              size: 22,
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Container(
            margin: const EdgeInsets.only(left: 16, top: 4),
            padding: const EdgeInsets.only(left: 12),
            child: Column(
              children: _settingsMenuItems
                  .map(
                    (item) => _buildMenuItem(
                      item.icon,
                      item.title,
                      item.action,
                      compact: true,
                    ),
                  )
                  .toList(),
            ),
          ),
          crossFadeState: _isSettingsExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 150),
        ),
      ],
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isActive = false,
    bool isDestructive = false,
    bool compact = false,
    Widget? trailing,
  }) {
    final Color iconColor = isDestructive
        ? Colors.red.shade300
        : isActive
        ? Colors.cyan.shade300
        : Colors.white.withOpacity(0.85);

    final Color textColor = isDestructive
        ? Colors.red.shade300
        : isActive
        ? Colors.white
        : Colors.white.withOpacity(0.85);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 2 : 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            onTap();
            if (title != 'การตั้งค่า') {
              widget.onClose();
            }
          },
          borderRadius: BorderRadius.circular(12),
          splashColor: Colors.white.withOpacity(0.1),
          highlightColor: Colors.white.withOpacity(0.05),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: compact ? 12 : 14,
            ),
            decoration: isActive
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withOpacity(0.1),
                  )
                : null,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: compact ? 18 : 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: compact ? 14 : 15,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white.withOpacity(0.8), size: 22),
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final VoidCallback action;
  final bool isActive;
  final bool isDestructive;

  _MenuItem(
    this.icon,
    this.title,
    this.action, {
    this.isActive = false,
    this.isDestructive = false,
  });
}
