import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:web_socket_channel/io.dart';
import 'package:smart_control/core/network/api_service.dart';

/// Singleton service สำหรับจัดการ Microphone Streaming แบบ Real-time
/// Optimized สำหรับ Raspberry Pi 4 - Low Latency & High Stability
class MicStreamService {
  // Singleton pattern
  static final MicStreamService _instance = MicStreamService._internal();
  factory MicStreamService() => _instance;
  MicStreamService._internal();

  // Core components
  final AudioRecorder _recorder = AudioRecorder();
  IOWebSocketChannel? _channel;
  StreamSubscription<Uint8List>? _micSub;
  StreamSubscription<dynamic>? _wsSub;

  // State management
  bool _isRecording = false;
  bool _isStopping = false;

  // Audio configuration – tuned for low latency
  int _sampleRate = 44100; // Default value, will be loaded from DB
  static const int channels = 2;
  // Keep the post-stop silence short to flush server/ffmpeg buffers quickly
  static const int flushTailMs = 200; // ms

  // Callbacks
  void Function(bool isRecording)? onStatusChanged;
  void Function(String error)? onError;

  // Getters
  bool get isRecording => _isRecording;
  bool get isStopping => _isStopping;
  int get sampleRate => _sampleRate;

  /// โหลด Sample Rate จากฐานข้อมูล
  Future<void> _loadSampleRate() async {
    try {
      final api = await ApiService.private();
      final response = await api.get('/settings/sampleRate');

      if (response['status'] == 'success') {
        _sampleRate = response['value'] ?? 44100;
        print('🎵 Sample Rate from DB: $_sampleRate Hz');
      }
    } catch (error) {
      print(
        '⚠️ ไม่สามารถดึง Sample Rate จาก DB ได้, ใช้ค่าเริ่มต้น 44100: $error',
      );
      _sampleRate = 44100;
    }
  }

  /// เริ่มสตรีมเสียง
  Future<bool> startStreaming(String serverUrl) async {
    if (_isRecording || _isStopping) return false;

    if (!await _recorder.hasPermission()) {
      _handleError('ไม่มีสิทธิ์เข้าถึงไมโครโฟน');
      return false;
    }

    try {
      // โหลด Sample Rate จาก DB ก่อนเริ่มบันทึก
      await _loadSampleRate();

      // Connect WebSocket
      _channel = IOWebSocketChannel.connect(
        serverUrl,
        pingInterval: const Duration(seconds: 15),
      );

      // Setup WebSocket listener
      _wsSub = _channel!.stream.listen(
        null, // ไม่ต้องประมวลผลข้อความจาก server
        onError: (_) => _handleError('เชื่อมต่อเซิร์ฟเวอร์ล้มเหลว'),
        onDone: () => print('🔌 WebSocket closed'),
        cancelOnError: true,
      );

      // Start audio recording
      final stream = await _recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRate,
          numChannels: channels,
          // Note: These DSP features improve audio quality but can cost CPU on low-end devices.
          // If you see high CPU or latency, consider turning off one or more of them.
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
      );

      // Stream audio data to server
      _micSub = stream.listen(
        _sendAudioData,
        onError: (_) => _handleError('เกิดข้อผิดพลาดในการบันทึกเสียง'),
        onDone: () => print('🎤 Recording ended'),
      );

      _isRecording = true;
      onStatusChanged?.call(true);
      print('✅ Mic streaming started');
      return true;
    } catch (e) {
      _handleError('เริ่มการสตรีมล้มเหลว: $e');
      await _cleanup();
      return false;
    }
  }

  /// ส่งข้อมูลเสียงไปยัง server
  void _sendAudioData(Uint8List data) {
    if (_channel?.closeCode != null) return;
    try {
      _channel!.sink.add(data);
    } catch (e) {
      print('⚠️ Send error: $e');
    }
  }

  /// หยุดสตรีมเสียง
  Future<void> stopStreaming() async {
    if (!_isRecording || _isStopping) return;

    _isStopping = true;
    print('🛑 Stopping mic stream...');

    try {
      // Stop recording
      await _micSub?.cancel();
      _micSub = null;
      await _recorder.stop();

      // Flush silence tail
      await _flushSilenceTail();

      // Close WebSocket gracefully
      await _channel?.sink.close(1000, 'normal');
      await _wsSub?.cancel();
      _wsSub = null;

      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      print('⚠️ Stop error: $e');
    } finally {
      await _cleanup();
    }
  }

  /// ส่ง silence tail เพื่อ flush buffer
  Future<void> _flushSilenceTail() async {
    if (_channel?.closeCode != null) return;

    try {
      const int chunkMs = 40;
      final int bytesPerChunk = (_sampleRate * channels * 2 * chunkMs) ~/ 1000;
      final silence = Uint8List(bytesPerChunk);
      final chunks = flushTailMs ~/ chunkMs;

      for (int i = 0; i < chunks && _channel?.closeCode == null; i++) {
        _channel?.sink.add(silence);
        await Future.delayed(const Duration(milliseconds: chunkMs));
      }
    } catch (e) {
      print('⚠️ Flush error: $e');
    }
  }

  /// จัดการ error
  void _handleError(String message) {
    print('❌ $message');
    onError?.call(message);
  }

  /// ล้างทรัพยากร
  Future<void> _cleanup() async {
    _channel = null;
    _isRecording = false;
    _isStopping = false;
    onStatusChanged?.call(false);
    print('🧹 Cleanup completed');
  }

  /// Toggle สตรีม
  Future<bool> toggleStreaming(String serverUrl) async {
    if (_isRecording) {
      await stopStreaming();
      return false;
    }
    return await startStreaming(serverUrl);
  }

  /// ทำลาย service
  Future<void> dispose() async {
    await stopStreaming();
    await _recorder.dispose();
    print('🗑️ MicStreamService disposed');
  }
}
