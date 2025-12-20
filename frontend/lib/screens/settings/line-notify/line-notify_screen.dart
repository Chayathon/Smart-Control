import 'package:flutter/material.dart';
import 'package:smart_control/core/alert/app_snackbar.dart';
import 'package:smart_control/services/system_service.dart';
import 'package:smart_control/widgets/inputs/text_field_box.dart';
import 'package:smart_control/widgets/loading_overlay.dart';

class LineNotifyScreen extends StatefulWidget {
  const LineNotifyScreen({Key? key}) : super(key: key);

  @override
  _LineNotifyScreenState createState() => _LineNotifyScreenState();
}

class _LineNotifyScreenState extends State<LineNotifyScreen> {
  bool _hasChanges = false;

  final TextEditingController _lineChannelAccessTokenCtrl =
      TextEditingController();
  final TextEditingController _lineChannelSecretCtrl = TextEditingController();
  final TextEditingController _lineUserIdCtrl = TextEditingController();
  final TextEditingController _lineMessageStartCtrl = TextEditingController();
  final TextEditingController _lineMessageEndCtrl = TextEditingController();
  final TextEditingController _appBaseUrlCtrl = TextEditingController();

  bool _obscureLineAccessToken = true;
  bool _obscureLineSecret = true;
  bool _lineNotifyEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _lineChannelAccessTokenCtrl.dispose();
    _lineChannelSecretCtrl.dispose();
    _lineUserIdCtrl.dispose();
    _lineMessageStartCtrl.dispose();
    _lineMessageEndCtrl.dispose();
    _appBaseUrlCtrl.dispose();
    super.dispose();
  }

  /// โหลดการตั้งค่าจาก API
  Future<void> _loadSettings() async {
    try {
      final data = await SystemService.getSettings();
      setState(() {
        _lineChannelAccessTokenCtrl.text = data['lineChannelAccessToken'] ?? '';
        _lineChannelSecretCtrl.text = data['lineChannelSecret'] ?? '';
        _lineUserIdCtrl.text = data['lineUserId'] ?? '';
        _lineNotifyEnabled = data['lineNotifyEnabled'] ?? false;
        _lineMessageStartCtrl.text =
            data['lineMessageStart'] ?? '🎵 กำลังเล่น: {songTitle}';
        _lineMessageEndCtrl.text =
            data['lineMessageEnd'] ?? '⏹️ เพลงจบแล้ว{songTitle}';
        _appBaseUrlCtrl.text = data['appBaseUrl'] ?? '';
        _hasChanges = false;
      });
    } catch (error) {
      print('❌ Error loading settings: $error');
      AppSnackbar.error(
        'แจ้งเตือน',
        'เกิดข้อผิดพลาดในการโหลดการตั้งค่า กรุณาลองใหม่อีกครั้ง',
      );
    } finally {
      LoadingOverlay.hide();
    }
  }

  /// บันทึกการตั้งค่าไปยัง API
  Future<void> _saveSettings() async {
    if (!_hasChanges) {
      AppSnackbar.info('แจ้งเตือน', 'ไม่มีการเปลี่ยนแปลงการตั้งค่า');
      return;
    }

    LoadingOverlay.show(context);

    try {
      // Get current system settings first
      final currentSettings = await SystemService.getSettings();

      await SystemService.saveSettings(
        sampleRate: currentSettings['sampleRate'] ?? 44100,
        loopPlaylist: currentSettings['loopPlaylist'] ?? false,
        lineChannelAccessToken: _lineChannelAccessTokenCtrl.text,
        lineChannelSecret: _lineChannelSecretCtrl.text,
        lineUserId: _lineUserIdCtrl.text,
        lineNotifyEnabled: _lineNotifyEnabled,
        lineMessageStart: _lineMessageStartCtrl.text,
        lineMessageEnd: _lineMessageEndCtrl.text,
        appBaseUrl: _appBaseUrlCtrl.text,
      );
      setState(() => _hasChanges = false);
      AppSnackbar.success('สำเร็จ', 'บันทึกการตั้งค่าเรียบร้อยแล้ว');
    } catch (error) {
      print('❌ Error saving settings: $error');
      AppSnackbar.error(
        'ผิดพลาด',
        'เกิดข้อผิดพลาดในการบันทึกการตั้งค่า กรุณาลองใหม่อีกครั้ง',
      );
    } finally {
      LoadingOverlay.hide();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "แจ้งเตือนผ่าน LINE",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green[700]!, Colors.green[500]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.notifications_active,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LINE Broadcast Notify',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'ส่งแจ้งเตือนไปยังทุกคนที่เป็นเพื่อนกับบอท เมื่อเริ่มและจบการเล่นเพลง',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Enable Toggle
          _buildSettingCard(
            title: 'เปิดใช้งานแจ้งเตือน LINE',
            subtitle: 'เปิด/ปิดการส่งข้อความแจ้งเตือนผ่าน LINE',
            icon: Icons.notifications_rounded,
            iconColor: Colors.blue,
            child: _buildLineEnableSwitch(),
          ),
          const SizedBox(height: 8),
          // Channel Access Token
          _buildSettingCard(
            title: 'Channel Access Token',
            subtitle: 'Token สำหรับเข้าถึง LINE Messaging API',
            icon: Icons.vpn_key,
            iconColor: Colors.orange,
            child: TextFieldBox(
              hint: 'ใส่ Channel Access Token',
              controller: _lineChannelAccessTokenCtrl,
              obscureText: _obscureLineAccessToken,
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _obscureLineAccessToken = !_obscureLineAccessToken;
                  });
                },
                icon: Icon(
                  _obscureLineAccessToken
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _hasChanges = true;
                });
              },
              textInputAction: TextInputAction.done,
            ),
          ),
          const SizedBox(height: 8),

          // Channel Secret
          _buildSettingCard(
            title: 'Channel Secret',
            subtitle: 'รหัสลับของ LINE Channel',
            icon: Icons.lock_outline,
            iconColor: Colors.orange,
            child: TextFieldBox(
              hint: 'ใส่ Channel Secret',
              controller: _lineChannelSecretCtrl,
              obscureText: _obscureLineSecret,
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _obscureLineSecret = !_obscureLineSecret;
                  });
                },
                icon: Icon(
                  _obscureLineSecret ? Icons.visibility_off : Icons.visibility,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _hasChanges = true;
                });
              },
              textInputAction: TextInputAction.done,
            ),
          ),
          const SizedBox(height: 8),

          // App Base URL
          _buildSettingCard(
            title: 'URL ของ Server',
            subtitle: 'URL สำหรับลิงก์เปิดแอป (ใช้กับตัวแปร {link})',
            icon: Icons.link,
            iconColor: Colors.purple,
            child: TextFieldBox(
              hint: 'https://your-server.com',
              controller: _appBaseUrlCtrl,
              keyboardType: TextInputType.url,
              onChanged: (value) {
                setState(() {
                  _hasChanges = true;
                });
              },
              textInputAction: TextInputAction.done,
            ),
          ),
          const SizedBox(height: 8),

          // Message Start Template
          _buildSettingCard(
            title: 'ข้อความเมื่อเริ่มเล่น',
            subtitle: 'แจ้งเตือนเมื่อเริ่มเล่นเพลง',
            icon: Icons.play_circle_outline,
            iconColor: Colors.green,
            trailing: _buildVariableHelpTooltip(),
            child: TextFieldBox(
              hint: '🟢 เริ่มถ่ายทอดสดเพลง! {date} 🎵',
              controller: _lineMessageStartCtrl,
              maxLines: null,
              minLines: 3,
              keyboardType: TextInputType.multiline,
              onChanged: (value) {
                setState(() {
                  _hasChanges = true;
                });
              },
              textInputAction: TextInputAction.newline,
            ),
          ),
          const SizedBox(height: 8),

          // Message End Template
          _buildSettingCard(
            title: 'ข้อความเมื่อเพลงจบ',
            subtitle: 'แจ้งเตือนเมื่อเพลงเล่นจบ',
            icon: Icons.stop_circle_outlined,
            iconColor: Colors.red,
            trailing: _buildVariableHelpTooltip(),
            child: TextFieldBox(
              hint: '🔴 หยุดการถ่ายทอดสด {date}',
              controller: _lineMessageEndCtrl,
              maxLines: null,
              minLines: 3,
              keyboardType: TextInputType.multiline,
              onChanged: (value) {
                setState(() {
                  _hasChanges = true;
                });
              },
              textInputAction: TextInputAction.newline,
            ),
          ),
          const SizedBox(height: 8),

          // Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!, width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'วิธีการตั้งค่า LINE Messaging API',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '1. ไปที่ https://developers.line.biz/console และเข้าสู่ระบบ\n'
                        '2. ไปที่แท็บ Providers -> Channels\n'
                        '3. เลือก Channel ที่ใช้สำหรับการแจ้งเตือน\n'
                        '4. สามารถปรับแต่งการตั้งค่าต่างๆ ได้ตามต้องการ เช่น รูปภาพ, คำอธิบาย ฯลฯ',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue[800],
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _hasChanges
          ? FloatingActionButton.extended(
              onPressed: _saveSettings,
              foregroundColor: Colors.white,
              backgroundColor: Colors.green,
              icon: const Icon(Icons.save_outlined),
              label: const Text(
                'บันทึกการตั้งค่า',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }

  Widget _buildSettingCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Widget child,
    Widget? trailing,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildLineEnableSwitch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                _lineNotifyEnabled
                    ? Icons.notifications_active
                    : Icons.notifications_off,
                color: _lineNotifyEnabled ? Colors.green : Colors.grey,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                _lineNotifyEnabled ? 'เปิดใช้งาน' : 'ปิดใช้งาน',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _lineNotifyEnabled
                      ? Colors.green[800]
                      : Colors.grey[700],
                ),
              ),
            ],
          ),
          Switch(
            value: _lineNotifyEnabled,
            activeColor: Colors.green[600],
            onChanged: (value) {
              setState(() {
                _lineNotifyEnabled = value;
                _hasChanges = true;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVariableHelpTooltip() {
    return Tooltip(
      richMessage: TextSpan(
        children: [
          const TextSpan(
            text: 'ตัวแปรที่ใช้ได้:\n',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const TextSpan(text: '{song} - ชื่อเพลง\n'),
          const TextSpan(text: '{mode} - โหมดการเล่น\n'),
          const TextSpan(text: '{date} - วันที่\n'),
          const TextSpan(text: '{time} - เวลา\n'),
          const TextSpan(text: '{timestamp} - วันที่และเวลา\n'),
          const TextSpan(text: '{link} - ลิงก์เปิดแอป'),
        ],
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 5),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.help_outline_rounded,
          color: Colors.blue[700],
          size: 20,
        ),
      ),
    );
  }
}
