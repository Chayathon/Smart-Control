import 'package:flutter/material.dart';
import 'package:smart_control/core/mic/mic_stream_service.dart';

class MicPage extends StatefulWidget {
  const MicPage({super.key});

  @override
  State<MicPage> createState() => _MicPageState();
}

class _MicPageState extends State<MicPage> {
  final _micService = MicStreamService();
  bool _isRecording = false;
  String _statusMessage = 'พร้อมใช้งาน';

  static const String _serverUrl = "ws://192.168.1.83:8080/ws/mic";

  @override
  void initState() {
    super.initState();
    _setupCallbacks();
  }

  void _setupCallbacks() {
    _micService.onStatusChanged = (isRecording) {
      if (mounted) {
        setState(() {
          _isRecording = isRecording;
          _statusMessage = isRecording ? 'กำลังสตรีม...' : 'พร้อมใช้งาน';
        });
      }
    };

    _micService.onError = (error) {
      if (mounted) {
        setState(() => _statusMessage = 'ข้อผิดพลาด: $error');
        _showSnackBar(error, isError: true);
      }
    };
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _toggleRecording() async {
    if (_micService.isStopping) return;

    if (_isRecording) {
      await _micService.stopStreaming();
    } else {
      final success = await _micService.startStreaming(_serverUrl);
      if (!success && mounted) {
        _showSnackBar('ไม่สามารถเริ่มการสตรีมได้', isError: true);
      }
    }
  }

  @override
  void dispose() {
    _micService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ทดสอบไมโครโฟน"),
        backgroundColor: Colors.blue[700],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatusIndicator(),
              const SizedBox(height: 40),
              _buildControlButton(),
              const SizedBox(height: 40),
              _buildInfoBox(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _isRecording ? Colors.green[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isRecording ? Colors.green : Colors.grey[300]!,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(
            _isRecording ? Icons.mic : Icons.mic_off,
            size: 80,
            color: _isRecording ? Colors.green : Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            _statusMessage,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _isRecording ? Colors.green[900] : Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton() {
    return SizedBox(
      width: 200,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: _micService.isStopping ? null : _toggleRecording,
        icon: Icon(_isRecording ? Icons.stop : Icons.mic, size: 28),
        label: Text(
          _micService.isStopping
              ? "กำลังหยุด..."
              : (_isRecording ? "หยุดไมค์" : "เริ่มไมค์"),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _isRecording ? Colors.red : Colors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: const Column(
        children: [
          Text(
            "📱 ระบบปรับปรุงสำหรับ Raspberry Pi 4",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.blue,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            "• Low latency streaming\n"
            "• Auto gain & noise suppression\n"
            "• Stereo 44.1kHz PCM16",
            style: TextStyle(fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
