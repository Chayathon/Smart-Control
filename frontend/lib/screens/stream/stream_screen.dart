import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:smart_control/core/alert/app_snackbar.dart';
import 'package:smart_control/core/config/app_config.dart';
import 'package:smart_control/core/network/api_service.dart';
import 'package:smart_control/core/services/StreamStatusService.dart';
import 'dart:math' as math;
import 'package:smart_control/widgets/buttons/action_button.dart';

class StreamScreen extends StatefulWidget {
  const StreamScreen({Key? key}) : super(key: key);

  @override
  State<StreamScreen> createState() => _StreamScreenState();
}

class _StreamScreenState extends State<StreamScreen>
    with TickerProviderStateMixin {
  final AudioPlayer _player = AudioPlayer();
  final StreamStatusService _statusSse = StreamStatusService();

  bool _isListening = false;
  bool _isStreamActive = false;
  bool _isLoading = false;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  bool _isRetrying = false;

  int? _icecastPort;
  String? _icecastMount;

  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initPlayer();
    _fetchStatus();

    // ป้องกันหน้าจอดับ
    WakelockPlus.enable();

    _statusSse.onStatusUpdate = (data) {
      if (mounted) {
        _updateStatus(data);
      }
    };
    _statusSse.connect();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _waveAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(parent: _waveController, curve: Curves.linear));

    _pulseController.repeat(reverse: true);
    _waveController.repeat();
  }

  Future<void> _initPlayer() async {
    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isListening = state.playing;
          if (state.processingState == ProcessingState.loading ||
              state.processingState == ProcessingState.buffering) {
            _isLoading = true;
          } else {
            _isLoading = false;
          }

          if (state.processingState == ProcessingState.completed &&
              _isListening &&
              !_isRetrying) {
            _handleRetryOrStop();
          }
        });
      }
    });

    // Listen for errors
    _player.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace st) {
        if (mounted && !_isRetrying) {
          print('Playback error: $e');
          // Don't show error if we're going to retry
          if (_retryCount >= _maxRetries) {
            setState(() {
              _isListening = false;
              _isLoading = false;
            });
            AppSnackbar.error(
              'การเล่นเสียงขัดข้อง',
              'ไม่สามารถเชื่อมต่อกับสตรีมได้',
            );
          }
        }
      },
    );
  }

  Future<void> _fetchStatus() async {
    try {
      final api = await ApiService.private();
      final res = await api.get('/stream/status');
      if (res['status'] == 'success') {
        _updateStatus(res['data']);
      }
    } catch (e) {
      print('Error fetching stream status: $e');
    }
  }

  void _updateStatus(Map<String, dynamic> data) {
    final bool isPlaying = data['isPlaying'] == true;
    final String activeMode = data['activeMode'] ?? 'none';

    if (data['icecast'] != null) {
      _icecastPort = data['icecast']['port'];
      _icecastMount = data['icecast']['mount'];
    }

    setState(() {
      final wasActive = _isStreamActive;
      _isStreamActive = isPlaying && activeMode != 'none';

      // Reset retry count when stream becomes active again
      if (_isStreamActive && !wasActive) {
        _retryCount = 0;
      }
    });
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    if (!_isStreamActive) {
      AppSnackbar.error('ไม่สามารถเล่นได้', 'ไม่มีการถ่ายทอดสดในขณะนี้');
      return;
    }

    await _connectToStream();
  }

  Future<void> _retryListening() async {
    await _connectToStream();
  }

  Future<void> _connectToStream() async {
    if (_icecastPort == null || _icecastMount == null) {
      await _fetchStatus();
      if (_icecastPort == null || _icecastMount == null) {
        _handleRetryOrStop();
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final Uri baseUri = Uri.parse(AppConfig.baseUrl);
      final String host = baseUri.host;
      final String url = 'http://$host:$_icecastPort$_icecastMount';

      print('🎧 Connecting to stream: $url');

      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(url),
          tag: {'id': 'live_stream', 'title': 'Live Stream'},
        ),
        preload: true,
      );

      await _player.play();
      // Reset retry count on successful connection
      _retryCount = 0;
      _isRetrying = false;
    } catch (e) {
      print('Error starting stream: $e');
      setState(() => _isLoading = false);
      _handleRetryOrStop();
    }
  }

  void _handleRetryOrStop() {
    if (_retryCount < _maxRetries) {
      _retryCount++;
      _isRetrying = true;
      print('🔄 Retry attempt $_retryCount/$_maxRetries in 5s...');
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          _retryListening();
        }
      });
    } else {
      print('❌ Max retries reached, stopping stream');
      _retryCount = 0;
      _isRetrying = false;
      setState(() {
        _isListening = false;
      });
      AppSnackbar.info('สตรีมจบแล้ว', 'ไม่สามารถเชื่อมต่อสตรีมได้');
    }
  }

  Future<void> _stopListening() async {
    try {
      await _player.stop();
    } catch (e) {
      print('Error stopping stream: $e');
    }
  }

  @override
  void dispose() {
    // ปิด wakelock เมื่อออกจากหน้านี้
    WakelockPlus.disable();
    _pulseController.dispose();
    _waveController.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'สตรีมเสียง',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        centerTitle: true,
        elevation: 1,
        backgroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchStatus,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStreamVisualizer(),

              const SizedBox(height: 16),

              _buildControlCard(),

              const SizedBox(height: 16),

              _buildInfoCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreamVisualizer() {
    return AnimatedBuilder(
      animation: _waveAnimation,
      builder: (context, child) {
        return Container(
          height: 280,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_isListening) ...[
                Positioned.fill(
                  child: CustomPaint(
                    painter: WavePainter(
                      animation: _waveAnimation.value,
                      color: Colors.indigo.withOpacity(0.1),
                    ),
                  ),
                ),
              ],

              ScaleTransition(
                scale: _isListening
                    ? _pulseAnimation
                    : const AlwaysStoppedAnimation(1.0),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening
                        ? Colors.indigo.shade500
                        : Colors.grey.shade200,
                    boxShadow: [
                      BoxShadow(
                        color: _isListening
                            ? Colors.indigo.withOpacity(0.3)
                            : Colors.transparent,
                        blurRadius: 32,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isListening
                        ? Icons.graphic_eq_rounded
                        : Icons.headphones_rounded,
                    size: 60,
                    color: _isListening ? Colors.white : Colors.grey.shade400,
                  ),
                ),
              ),

              Positioned(
                bottom: 24,
                child: Column(
                  children: [
                    Text(
                      _isListening
                          ? 'กำลังเล่นสตรีม'
                          : _isStreamActive
                          ? 'พร้อมเล่น'
                          : 'ไม่มีสตรีม',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isListening
                          ? ''
                          : _isStreamActive
                          ? 'แตะปุ่มด้านล่างเพื่อเริ่มฟัง'
                          : 'รอการถ่ายทอดสด',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              if (_isLoading)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.indigo.shade500,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControlCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Button(
            onPressed: _toggleListening,
            label: _isListening ? 'หยุดเล่น' : 'เริ่มเล่น',
            icon: _isListening ? Icons.stop_circle : Icons.play_circle_fill,
            fontSize: 20,
            height: 56,
            backgroundColor: _isListening ? Colors.red : Colors.indigo,
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.tips_and_updates,
              color: Colors.blue.shade700,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'คุณสามารถฟังเสียงที่กำลังถ่ายทอดผ่านแอปพลิเคชันได้ทันที',
              style: TextStyle(
                fontSize: 13,
                color: Colors.blue.shade900,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for wave animation
class WavePainter extends CustomPainter {
  final double animation;
  final Color color;

  WavePainter({required this.animation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();
    final waveHeight = 30.0;
    final waveLength = size.width / 2;

    for (var i = 0; i < 3; i++) {
      path.reset();
      final yOffset = size.height / 2 + (i * 40) - 40;

      for (var x = 0.0; x <= size.width; x++) {
        final y =
            yOffset +
            math.sin((x / waveLength * 2 * math.pi) + animation + (i * 0.5)) *
                waveHeight;
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) => true;
}
