import 'package:flutter/material.dart';
import 'package:smart_control/core/alert/app_snackbar.dart';
import 'package:smart_control/core/network/api_service.dart';
import 'package:smart_control/widgets/loading_overlay.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({Key? key}) : super(key: key);

  @override
  _SettingScreenState createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  // ตัวเลือก Sample Rate ที่รองรับ
  final List<int> _sampleRateOptions = [
    8000,
    16000,
    22050,
    44100,
    48000,
    96000,
  ];

  // ค่าการตั้งค่าปัจจุบัน
  int _selectedSampleRate = 44100;
  bool _loopPlaylist = false;

  // สถานะการโหลด
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// โหลดการตั้งค่าจาก API
  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      final api = await ApiService.private();
      final response = await api.get('/settings');

      if (response['status'] == 'success') {
        final data = response['data'];
        setState(() {
          _selectedSampleRate = data['sampleRate'] ?? 44100;
          _loopPlaylist = data['loopPlaylist'] ?? false;
          _hasChanges = false;
        });
      }
    } catch (error) {
      print('❌ Error loading settings: $error');
      AppSnackbar.error('แจ้งเตือน', 'ไม่สามารถโหลดการตั้งค่าได้');
    } finally {
      setState(() => _isLoading = false);
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
      final api = await ApiService.private();
      final response = await api.post(
        '/settings/bulk',
        data: {
          'sampleRate': _selectedSampleRate,
          'loopPlaylist': _loopPlaylist,
        },
      );

      if (response['status'] == 'success') {
        setState(() => _hasChanges = false);
        AppSnackbar.success('สำเร็จ', 'บันทึกการตั้งค่าเรียบร้อยแล้ว');
      }
    } catch (error) {
      print('❌ Error saving settings: $error');
      AppSnackbar.error('ผิดพลาด', 'ไม่สามารถบันทึกการตั้งค่าได้');
    } finally {
      LoadingOverlay.hide();
    }
  }

  /// รีเซ็ตการตั้งค่าเป็นค่าเริ่มต้น
  Future<void> _resetSettings() async {
    // แสดง dialog ยืนยัน
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        title: const Text(
          'ยืนยันการรีเซ็ต',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'คุณต้องการรีเซ็ตการตั้งค่ากลับเป็นค่าเริ่มต้นหรือไม่?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Colors.grey[200]),
            ),
            child: Text(
              'ยกเลิก',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Colors.orange[50]),
            ),
            child: const Text(
              'ยืนยัน',
              style: TextStyle(
                color: Colors.deepOrange,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    LoadingOverlay.show(context);

    try {
      final api = await ApiService.private();
      final response = await api.post('/settings/reset');

      if (response['status'] == 'success') {
        final data = response['data'];
        setState(() {
          _selectedSampleRate = data['sampleRate'] ?? 44100;
          _loopPlaylist = data['loopPlaylist'] ?? false;
          _hasChanges = false;
        });
        AppSnackbar.success('สำเร็จ', 'รีเซ็ตการตั้งค่าเรียบร้อยแล้ว');
      }
    } catch (error) {
      print('❌ Error resetting settings: $error');
      AppSnackbar.error('ผิดพลาด', 'ไม่สามารถรีเซ็ตการตั้งค่าได้');
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
          "การตั้งค่าระบบ",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 1,
        actions: [
          if (_hasChanges)
            IconButton(
              icon: const Icon(Icons.save, color: Colors.blue),
              tooltip: 'บันทึกการตั้งค่า',
              onPressed: _saveSettings,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSettings,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // การตั้งค่า Sample Rate
                  _buildSettingCard(
                    title: 'Sample Rate (ความถี่การสุ่มสัญญาณ)',
                    subtitle: 'ความละเอียดของเสียงที่บันทึก (Hz)',
                    icon: Icons.graphic_eq,
                    child: _buildSampleRateSelector(),
                  ),
                  const SizedBox(height: 12),

                  // การตั้งค่า Loop Playlist
                  _buildSettingCard(
                    title: 'Loop Playlist',
                    subtitle: 'เล่นเพลงซ้ำเมื่อเล่นครบทุกเพลง',
                    icon: Icons.repeat,
                    child: _buildLoopSwitch(),
                  ),
                  const SizedBox(height: 24),

                  // ปุ่มรีเซ็ต
                  _buildResetButton(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
      floatingActionButton: _hasChanges
          ? FloatingActionButton.extended(
              onPressed: _saveSettings,
              backgroundColor: Colors.green,
              icon: const Icon(Icons.save),
              label: const Text(
                'บันทึกการตั้งค่า',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }

  /// ส่วนหัวของหมวดหมู่
  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[700]!, Colors.blue[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Card สำหรับการตั้งค่าแต่ละรายการ
  Widget _buildSettingCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
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
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.blue[700], size: 24),
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
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  /// ตัวเลือก Sample Rate
  Widget _buildSampleRateSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _sampleRateOptions.map((rate) {
        final isSelected = _selectedSampleRate == rate;
        return ChoiceChip(
          label: Text(
            '${rate ~/ 1000} kHz',
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          selected: isSelected,
          selectedColor: Colors.blue[600],
          backgroundColor: Colors.grey[200],
          onSelected: (selected) {
            if (selected) {
              setState(() {
                _selectedSampleRate = rate;
                _hasChanges = true;
              });
            }
          },
          elevation: isSelected ? 4 : 0,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        );
      }).toList(),
    );
  }

  /// สวิตช์ Loop Playlist
  Widget _buildLoopSwitch() {
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
                _loopPlaylist ? Icons.repeat_on : Icons.repeat,
                color: _loopPlaylist ? Colors.green : Colors.grey,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                _loopPlaylist ? 'เปิดใช้งาน' : 'ปิดใช้งาน',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _loopPlaylist ? Colors.green : Colors.grey[700],
                ),
              ),
            ],
          ),
          Switch(
            value: _loopPlaylist,
            activeColor: Colors.green,
            onChanged: (value) {
              setState(() {
                _loopPlaylist = value;
                _hasChanges = true;
              });
            },
          ),
        ],
      ),
    );
  }

  /// ปุ่มรีเซ็ต
  Widget _buildResetButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _resetSettings,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange[50],
          foregroundColor: Colors.deepOrange,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.deepOrange, width: 2),
          ),
          elevation: 0,
        ),
        icon: const Icon(Icons.restore),
        label: const Text(
          'รีเซ็ตเป็นค่าเริ่มต้น',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
