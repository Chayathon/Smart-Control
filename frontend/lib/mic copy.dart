import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/io.dart';

class MicStreamPage extends StatefulWidget {
  const MicStreamPage({super.key});
  @override
  State<MicStreamPage> createState() => _MicStreamPageState();
}

class _MicStreamPageState extends State<MicStreamPage> {
  final record = AudioRecorder();
  late IOWebSocketChannel _channel;
  bool _isStreaming = false;

  @override
  void initState() {
    super.initState();
    _channel = IOWebSocketChannel.connect(Uri.parse('ws://192.168.1.83:8080'));
  }

  Future<void> _startMic() async {
    if (await record.hasPermission()) {
      await record
          .startStream(
            const RecordConfig(
              encoder: AudioEncoder.pcm16bits,
              sampleRate: 44100,
              numChannels: 2, // ✅ สองแชนแนล (Stereo)
            ),
          )
          .then((stream) {
            stream.listen((data) {
              _channel.sink.add(data); // ส่งไป Node.js
            });
          });
      setState(() => _isStreaming = true);
    }
  }

  Future<void> _stopMic() async {
    await record.stop();
    setState(() => _isStreaming = false);
  }

  @override
  void dispose() {
    record.dispose();
    _channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mic → Node.js")),
      body: Center(
        child: ElevatedButton(
          onPressed: _isStreaming ? _stopMic : _startMic,
          child: Text(_isStreaming ? "Stop Mic" : "Start Mic"),
        ),
      ),
    );
  }
}
