import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/io.dart';

class MicPage extends StatefulWidget {
  const MicPage({super.key});

  @override
  State<MicPage> createState() => _MicPageState();
}

class _MicPageState extends State<MicPage> {
  final _recorder = AudioRecorder();

  IOWebSocketChannel? _channel;
  StreamSubscription<dynamic>? _micSub;
  StreamSubscription? _wsSub;
  Completer<void>? _wsDone;
  bool _isRecording = false;
  bool _isStopping = false;

  double tailSeconds = 0.6;
  static const int sampleRate = 44100;
  static const int channels = 2;
  static const int bitsPerSample = 16;

  Future<void> _startRecording() async {
    if (_isRecording || _isStopping) return;
    if (!await _recorder.hasPermission()) return;

    _channel = IOWebSocketChannel.connect("ws://192.168.1.83:8080/ws/mic");
    _wsDone = Completer<void>();
    _wsSub = _channel!.stream.listen(
      (_) {},
      onError: (_) {
        if (!(_wsDone?.isCompleted ?? true)) _wsDone?.complete();
      },
      onDone: () {
        if (!(_wsDone?.isCompleted ?? true)) _wsDone?.complete();
      },
      cancelOnError: true,
    );

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: channels,
      ),
    );

    _micSub = stream.listen((data) {
      final ch = _channel;
      if (ch == null) return;

      if (data is Uint8List) {
        ch.sink.add(data);
      } else if (data is List<int>) {
        ch.sink.add(Uint8List.fromList(data));
      }
    }, onError: (_) {});

    setState(() => _isRecording = true);
  }

  Future<void> _flushSilenceTail(double seconds) async {
    final ch = _channel;
    if (ch == null || seconds <= 0) return;

    final int bytesPerSecond = sampleRate * channels * (bitsPerSample ~/ 8);
    const int chunkMs = 40;
    final int chunkBytes = ((bytesPerSecond * chunkMs) / 1000).round();
    final Uint8List silenceChunk = Uint8List(chunkBytes);
    final int totalChunks = ((seconds * 1000) / chunkMs).ceil();

    for (int i = 0; i < totalChunks; i++) {
      ch.sink.add(silenceChunk);
      await Future.delayed(const Duration(milliseconds: chunkMs));
    }

    await Future.delayed(const Duration(milliseconds: 120));
  }

  Future<void> _stopRecording() async {
    if (!_isRecording || _isStopping) return;
    _isStopping = true;

    try {
      await _micSub?.cancel();
    } catch (_) {}
    _micSub = null;

    try {
      await _recorder.stop();
    } catch (_) {}

    try {
      await _flushSilenceTail(tailSeconds);
    } catch (_) {}

    try {
      final closeFuture = _channel?.sink.close(1000, 'normal');

      if (closeFuture is Future) {
        await closeFuture.catchError((_) {});
      }

      if (_wsDone != null && !(_wsDone!.isCompleted)) {
        await Future.any([
          _wsDone!.future,
          Future.delayed(const Duration(seconds: 1)),
        ]);
      }
    } catch (_) {}

    try {
      await _wsSub?.cancel();
    } catch (_) {}
    _wsSub = null;
    _wsDone = null;
    _channel = null;

    setState(() {
      _isRecording = false;
      _isStopping = false;
    });

    await Future.delayed(const Duration(milliseconds: 150));
  }

  @override
  void dispose() {
    _micSub?.cancel();
    _wsSub?.cancel();
    _recorder.dispose();
    _channel?.sink.close(1001, 'disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final btnText = _isRecording
        ? (_isStopping ? "Stopping..." : "Stop")
        : "Start Mic";
    return Scaffold(
      appBar: AppBar(title: const Text("Mic Stream")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Text("หน่วงก่อนปิด (วินาที): "),
                Expanded(
                  child: Slider(
                    min: 0.0,
                    max: 2.0,
                    divisions: 20,
                    value: tailSeconds,
                    label: tailSeconds.toStringAsFixed(2),
                    onChanged: _isRecording || _isStopping
                        ? null
                        : (v) => setState(() => tailSeconds = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isStopping
                  ? null
                  : (_isRecording ? _stopRecording : _startRecording),
              child: Text(btnText),
            ),
            const SizedBox(height: 8),
            const Text(
              "ถ้าสตรีม mono ให้เปลี่ยน numChannels=1 ทั้งฝั่งนี้และฝั่งรับ เพื่อกันบัฟเฟอร์เพี้ยน",
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
