import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:smart_control/core/config/app_config.dart';
import 'package:smart_control/core/alert/app_snackbar.dart';

class StreamScreen extends StatefulWidget {
  const StreamScreen({Key? key}) : super(key: key);

  @override
  State<StreamScreen> createState() => _StreamScreenState();
}

class _StreamScreenState extends State<StreamScreen> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isLoading = false;
  String? _errorMessage;

  // URL ของ stream (ปรับตามเซิร์ฟเวอร์ของคุณ)
  String get _streamUrl => '${AppConfig.baseUrl}/stream/audio';

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _setupAudioPlayer();
  }

  Future<void> _setupAudioPlayer() async {
    // Listen to player state changes
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          _isLoading =
              state.processingState == ProcessingState.loading ||
              state.processingState == ProcessingState.buffering;

          // Clear error when successfully playing
          if (state.playing) {
            _errorMessage = null;
          }
        });
      }
    });

    // Listen to errors
    _audioPlayer.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace stackTrace) {
        print('Audio player error: $e');
        if (mounted) {
          String errorMsg = 'ไม่สามารถเล่นเสียงได้';

          // Provide more specific error messages
          if (e.toString().contains('Source error')) {
            errorMsg = 'ไม่มีเพลงกำลังเล่นในระบบ กรุณาเริ่มเล่นเพลงก่อน';
          } else if (e.toString().contains('Connection')) {
            errorMsg = 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้';
          }

          setState(() {
            _errorMessage = errorMsg;
            _isPlaying = false;
            _isLoading = false;
          });

          AppSnackbar.error('ข้อผิดพลาด', errorMsg);
        }
      },
    );
  }

  Future<void> _togglePlayback() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
        setState(() {
          _isPlaying = false;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });

        print('🎵 Attempting to play stream from: $_streamUrl');

        await _audioPlayer.setUrl(_streamUrl);
        await _audioPlayer.play();

        AppSnackbar.success('สำเร็จ', 'กำลังเล่นเสียงจากเซิร์ฟเวอร์');
      }
    } catch (e) {
      print('Error in _togglePlayback: $e');
      if (mounted) {
        String errorMsg = 'ไม่สามารถเล่นเสียงได้';

        if (e.toString().contains('Source error')) {
          errorMsg = 'ไม่มีเพลงกำลังเล่นในระบบ กรุณาเริ่มเล่นเพลงก่อน';
        }

        setState(() {
          _errorMessage = errorMsg;
          _isPlaying = false;
          _isLoading = false;
        });

        AppSnackbar.error('ข้อผิดพลาด', errorMsg);
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'เปิดเสียงเพลง',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
        elevation: 1,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon/Animation
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.blue[400]!, Colors.blue[700]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Icon(
                  _isPlaying ? Icons.graphic_eq : Icons.music_note,
                  size: 100,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 48),

              // Title
              Text(
                _isPlaying ? 'กำลังเล่นเสียง' : 'พร้อมเล่นเสียง',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              // Error message or status text
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(fontSize: 14, color: Colors.red[700]),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                Text(
                  _isPlaying
                      ? 'กำลังเล่นเสียงจากเซิร์ฟเวอร์'
                      : 'กดปุ่มเพื่อเริ่มฟังเสียง',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),

              const SizedBox(height: 48),

              // Play/Stop Button
              GestureDetector(
                onTap: _isLoading ? null : _togglePlayback,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isLoading
                        ? Colors.grey
                        : (_isPlaying ? Colors.red[600] : Colors.green[600]),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (_isPlaying ? Colors.red[600]! : Colors.green[600]!)
                                .withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : Icon(
                          _isPlaying ? Icons.stop : Icons.play_arrow,
                          size: 40,
                          color: Colors.white,
                        ),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                _isLoading
                    ? 'กำลังโหลด...'
                    : (_isPlaying ? 'กดเพื่อหยุด' : 'กดเพื่อเล่น'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 48),

              // Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'เสียงที่ได้ยินจะเป็นเสียงเพลงที่กำลังเล่นอยู่ในระบบ',
                        style: TextStyle(fontSize: 14, color: Colors.blue[900]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
