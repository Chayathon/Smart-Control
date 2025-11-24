import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:web_socket_channel/io.dart';
import 'package:smart_control/core/network/api_service.dart';

/// Singleton service for real-time microphone streaming
/// Optimized for Raspberry Pi 4 - Low Latency & High Stability
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

  // Audio configuration - loaded from backend
  int _sampleRate = 44100;
  double _micVolume = 1.5;

  // Audio constants
  static const int channels = 2;
  static const int flushTailMs = 100; // Reduced from 200ms for faster stop

  // WebSocket retry configuration
  static const int maxRetries = 3;
  static const int retryDelayMs = 500;

  // Callbacks
  void Function(bool isRecording)? onStatusChanged;
  void Function(String error)? onError;

  // Getters
  bool get isRecording => _isRecording;
  bool get isStopping => _isStopping;
  int get sampleRate => _sampleRate;
  double get micVolume => _micVolume;

  /// Load stream configuration from backend (consolidated endpoint)
  Future<void> _loadStreamConfig() async {
    try {
      final api = await ApiService.private();
      final response = await api.get('/settings/stream-config');

      if (response['status'] == 'success') {
        final data = response['data'];
        _sampleRate = data['sampleRate'] ?? 44100;
        _micVolume = (data['micVolume'] ?? 1.5).toDouble();
        print(
          '🎵 Stream config loaded: ${_sampleRate}Hz, volume=${_micVolume}',
        );
      }
    } catch (error) {
      print('⚠️ Failed to load stream config, using defaults: $error');
      _sampleRate = 44100;
      _micVolume = 1.5;
    }
  }

  /// Start streaming with automatic retry
  Future<bool> startStreaming(String serverUrl) async {
    if (_isRecording || _isStopping) return false;

    if (!await _recorder.hasPermission()) {
      _handleError('ไม่มีสิทธิ์เข้าถึงไมโครโฟน');
      return false;
    }

    // Try to start with retry logic
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await _attemptStart(serverUrl);
      } catch (e) {
        print('⚠️ Start attempt $attempt/$maxRetries failed: $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(milliseconds: retryDelayMs * attempt));
        } else {
          _handleError('เชื่อมต่อล้มเหลวหลังจากลองหลายครั้ง: $e');
          await _cleanup();
          return false;
        }
      }
    }
    return false;
  }

  /// Internal start attempt
  Future<bool> _attemptStart(String serverUrl) async {
    // Load configuration from backend
    await _loadStreamConfig();

    // Connect WebSocket
    _channel = IOWebSocketChannel.connect(
      serverUrl,
      pingInterval: const Duration(seconds: 15),
    );

    // Setup WebSocket listener
    _wsSub = _channel!.stream.listen(
      null, // No incoming messages expected
      onError: (error) {
        print('⚠️ WebSocket error: $error');
        _handleError('เชื่อมต่อเซิร์ฟเวอร์ล้มเหลว');
      },
      onDone: () => print('🔌 WebSocket closed'),
      cancelOnError: true,
    );

    // Start audio recording with configuration
    final stream = await _recorder.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: channels,
        // Enable DSP features for better audio quality
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
      ),
    );

    // Stream audio data to server
    _micSub = stream.listen(
      _sendAudioData,
      onError: (error) {
        print('⚠️ Recording error: $error');
        _handleError('เกิดข้อผิดพลาดในการบันทึกเสียง');
      },
      onDone: () => print('🎤 Recording ended'),
    );

    _isRecording = true;
    onStatusChanged?.call(true);
    print('✅ Mic streaming started (${_sampleRate}Hz)');
    return true;
  }

  /// Send audio data to server
  void _sendAudioData(Uint8List data) {
    if (_channel?.closeCode != null) return;
    try {
      _channel!.sink.add(data);
    } catch (e) {
      print('⚠️ Send error: $e');
    }
  }

  /// Stop streaming
  Future<void> stopStreaming() async {
    if (!_isRecording || _isStopping) return;

    _isStopping = true;
    print('🛑 Stopping mic stream...');

    try {
      // Stop recording
      await _micSub?.cancel();
      _micSub = null;
      await _recorder.stop();

      // Flush silence tail (reduced from 200ms to 100ms)
      await _flushSilenceTail();

      // Close WebSocket gracefully
      await _channel?.sink.close(1000, 'normal');
      await _wsSub?.cancel();
      _wsSub = null;

      await Future.delayed(const Duration(milliseconds: 50));
    } catch (e) {
      print('⚠️ Stop error: $e');
    } finally {
      await _cleanup();
    }
  }

  /// Flush silence tail to clear buffers (optimized)
  Future<void> _flushSilenceTail() async {
    if (_channel?.closeCode != null) return;

    try {
      const int chunkMs = 50; // Increased from 40ms for fewer iterations
      final int bytesPerChunk = (_sampleRate * channels * 2 * chunkMs) ~/ 1000;
      final silence = Uint8List(bytesPerChunk);
      final chunks = flushTailMs ~/ chunkMs; // Only 2 chunks now (100ms / 50ms)

      for (int i = 0; i < chunks && _channel?.closeCode == null; i++) {
        _channel?.sink.add(silence);
        await Future.delayed(Duration(milliseconds: chunkMs));
      }
    } catch (e) {
      print('⚠️ Flush error: $e');
    }
  }

  /// Handle error
  void _handleError(String message) {
    print('❌ $message');
    onError?.call(message);
  }

  /// Cleanup resources
  Future<void> _cleanup() async {
    _channel = null;
    _isRecording = false;
    _isStopping = false;
    onStatusChanged?.call(false);
    print('🧹 Cleanup completed');
  }

  /// Dispose service
  Future<void> dispose() async {
    await stopStreaming();
    await _recorder.dispose();
    print('🗑️ MicStreamService disposed');
  }
}
