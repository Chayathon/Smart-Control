import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smart_control/services/playlist_service.dart';
import 'package:smart_control/core/network/api_service.dart';
import 'package:smart_control/services/mic_stream_service.dart';
import 'package:smart_control/core/alert/app_snackbar.dart';
import 'package:smart_control/widgets/loading_overlay.dart';
import 'package:smart_control/core/services/StreamStatusService.dart';
import 'package:smart_control/core/config/app_config.dart';

enum PlaybackMode { none, playlist, file, youtube }

class ControlPanel extends StatefulWidget {
  const ControlPanel({Key? key}) : super(key: key);

  @override
  State<ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends State<ControlPanel> {
  final PlaylistService _playlist = PlaylistService.instance;
  final MicStreamService _micService = MicStreamService();
  final StreamStatusService _statusSse = StreamStatusService();

  bool micOn = false;
  bool liveOn = false;
  double micVolume = 1.5;

  bool _micUiDisabled = false;
  Timer? _micUiCooldownTimer;

  Timer? _refreshDebounce;
  bool _refreshInFlight = false;
  bool _refreshQueued = false;
  DateTime? _lastRefreshAt;

  bool isPlaying = false;
  bool isPaused = false;
  bool isLoading = false;
  bool isControlsCoolingDown = false;
  bool isLoopEnabled = false;
  bool playlistActive = false;
  String currentSongTitle = '';
  int currentSongIndex = 0;
  int totalSongs = 0;

  PlaybackMode playbackMode = PlaybackMode.none;
  Timer? _localControlsCooldownTimer;

  static const String _micServerUrl = AppConfig.wsMic;

  @override
  void initState() {
    super.initState();

    _playlist.ensureInitialized();
    _syncFromPlaylistState();
    _playlist.state.addListener(_syncFromPlaylistState);

    _initStatusFromDb();

    _loadMicVolume();

    _statusSse.onStatusUpdate = (data) => _applySseStatus(data);
    _statusSse.connect();

    _micService.onStatusChanged = (isRecording) {
      if (!mounted) return;
      setState(() {
        micOn = isRecording;
        if (isRecording) {
          _micUiCooldownTimer?.cancel();
          _micUiDisabled = true;
        } else {
          _startMicControlsCooldown();
        }
      });
    };

    _micService.onError = (error) {
      if (!mounted) return;
      AppSnackbar.error('ข้อผิดพลาด', error);
    };
  }

  Future<void> _loadMicVolume() async {
    try {
      final api = await ApiService.private();
      final response = await api.get('/settings/micVolume');

      if (response['status'] == 'success' && response['value'] != null) {
        final value = response['value'];
        if (mounted) {
          setState(() {
            micVolume = (value is num) ? value.toDouble() : 1.5;
          });
          print('🎚️ Mic Volume from DB: $micVolume');
        }
      }
    } catch (error) {
      print('⚠️ ไม่สามารถดึง Mic Volume จาก DB ได้: $error');
      if (mounted) {
        setState(() {
          micVolume = 1.5;
        });
      }
    }
  }

  Future<void> _saveMicVolume(double value) async {
    final rounded = (value * 10).round() / 10.0;
    try {
      final api = await ApiService.private();
      await api.put('/settings/micVolume', data: {'value': rounded});
      print('💾 Mic Volume saved: $rounded');
    } catch (error) {
      print('⚠️ ไม่สามารถบันทึก Mic Volume ได้: $error');
    }
  }

  PlaybackMode _parseMode(dynamic value) {
    final s = value?.toString().toLowerCase() ?? '';
    switch (s) {
      case 'playlist':
        return PlaybackMode.playlist;
      case 'file':
      case 'single':
        return PlaybackMode.file;
      case 'youtube':
        return PlaybackMode.youtube;
      default:
        return PlaybackMode.none;
    }
  }

  String _titleFromUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    final parts = url.replaceAll('\\', '/').split('/');
    return parts.isNotEmpty ? parts.last : '';
  }

  void _applySseStatus(Map<String, dynamic> data) {
    try {
      final String event = (data['event'] ?? '').toString();
      final bool micEvent = event == 'mic-started' || event == 'mic-stopped';
      final PlaybackMode mode = _parseMode(
        data['activeMode'] ?? data['requestedMode'] ?? data['mode'],
      );

      final bool? playingMaybe = data.containsKey('isPlaying')
          ? (data['isPlaying'] == true)
          : null;
      final bool? pausedMaybe = data.containsKey('isPaused')
          ? (data['isPaused'] == true)
          : null;

      String title = currentSongTitle;
      int idx = currentSongIndex;
      int tot = totalSongs;

      if (mode == PlaybackMode.playlist) {
        final extra = data['extra'];
        if (data['title'] != null) {
          title = data['title'].toString();
        } else if (extra is Map && extra['title'] != null) {
          title = extra['title'].toString();
        }

        final int? iFromData = data['index'] is int
            ? data['index'] as int
            : (extra is Map && extra['index'] is int
                  ? extra['index'] as int
                  : null);
        if (iFromData != null) idx = iFromData + 1;

        final int? tFromData = data['total'] is int
            ? data['total'] as int
            : (extra is Map && extra['total'] is int
                  ? extra['total'] as int
                  : (data['totalSongs'] is int
                        ? data['totalSongs'] as int
                        : null));
        if (tFromData != null) tot = tFromData;
      } else if (mode == PlaybackMode.file) {
        if (!micEvent) {
          final nameField = data['name'] ?? data['title'];
          if (nameField != null && nameField.toString().isNotEmpty) {
            title = nameField.toString();
          } else {
            final candidate = _titleFromUrl(
              (data['url'] ?? data['currentUrl'])?.toString(),
            );
            if (candidate.toLowerCase() != 'flutter-mic' &&
                candidate.isNotEmpty) {
              title = candidate;
            }
          }
        }
      } else if (mode == PlaybackMode.youtube) {
        title = (data['url'] ?? data['currentUrl'])?.toString() ?? title;
      }

      if (!mounted) return;
      setState(() {
        playbackMode = mode;
        if (playingMaybe != null) isPlaying = playingMaybe;
        if (pausedMaybe != null) isPaused = pausedMaybe;
        playlistActive = mode == PlaybackMode.playlist;
        currentSongTitle = title;
        currentSongIndex = idx;
        totalSongs = tot;
      });

      if (playingMaybe == null ||
          event == 'mic-started' ||
          event == 'mic-stopped' ||
          event == 'stopped' ||
          event == 'stopped-all' ||
          event == 'ended') {
        _scheduleRefreshFromDb(const Duration(milliseconds: 200));
      }
    } catch (_) {
      _scheduleRefreshFromDb(const Duration(milliseconds: 200));
    }
  }

  void _syncFromPlaylistState() {
    final s = _playlist.state.value;
    if (!mounted) return;
    setState(() {
      playlistActive = s.active;
      isPlaying = s.isPlaying;
      isPaused = s.isPaused;
      isLoopEnabled = s.isLoop;
      isLoading = s.isLoading;
      isControlsCoolingDown = s.isControlsCoolingDown;
      currentSongIndex = s.index;
      totalSongs = s.total;
      currentSongTitle = s.title;
    });
  }

  void _scheduleRefreshFromDb([
    Duration delay = const Duration(milliseconds: 300),
  ]) {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(delay, () {
      _refreshFromDb();
    });
  }

  Future<bool> _refreshFromDb() async {
    final now = DateTime.now();
    if (_lastRefreshAt != null &&
        now.difference(_lastRefreshAt!) < const Duration(milliseconds: 150)) {
      _scheduleRefreshFromDb(const Duration(milliseconds: 150));
      return true;
    }
    if (_refreshInFlight) {
      _refreshQueued = true;
      return true;
    }
    _refreshInFlight = true;
    try {
      final api = await ApiService.private();
      final devices = await api.get('/device') as List<dynamic>;
      PlaybackMode mode = playbackMode;
      if (devices.isNotEmpty) {
        final first = devices.first;
        final m = (first['status']?['playback_mode'] ?? 'none').toString();
        if (m.isNotEmpty) mode = _parseMode(m);
      }

      final engine = await api.get('/stream/status');
      final data = engine['data'] ?? engine;
      final bool engIsPlaying = data['isPlaying'] == true;
      liveOn = data['streamEnabled'] == true;
      final bool engIsPaused = data['isPaused'] == true;
      final PlaybackMode activeMode = _parseMode(
        data['activeMode'] ?? data['mode'] ?? 'none',
      );
      final bool engPlaylistMode =
          activeMode == PlaybackMode.playlist || data['playlistMode'] == true;

      String title = currentSongTitle;
      int idx = currentSongIndex;
      int tot = totalSongs;
      if (engPlaylistMode && data['currentSong'] != null) {
        final cs = data['currentSong'];
        title = (cs['title'] ?? '').toString();
        idx = ((cs['index'] ?? 0) as int) + 1;
        tot = (cs['total'] ?? data['totalSongs'] ?? 0) as int;
      } else if (activeMode == PlaybackMode.file) {
        if (data['name'] != null && data['name'].toString().isNotEmpty) {
          title = data['name'].toString();
        } else if (data['title'] != null &&
            data['title'].toString().isNotEmpty) {
          title = data['title'].toString();
        } else {
          final candidate = _titleFromUrl(
            (data['currentUrl'] ?? data['url'])?.toString(),
          );
          if (candidate.toLowerCase() != 'flutter-mic' &&
              candidate.isNotEmpty) {
            title = candidate;
          }
        }
      } else if (activeMode == PlaybackMode.youtube) {
        // For YouTube, we keep a friendly label in UI; no need to set title here
      }

      if (!mounted) return true;
      setState(() {
        playbackMode = mode;
        isPlaying = engIsPlaying;
        isPaused = engIsPaused;
        playlistActive = engPlaylistMode;
        isLoading = false;
        currentSongTitle = title;
        currentSongIndex = idx;
        totalSongs = tot;
        liveOn = data['streamEnabled'] == true;
      });
      return true;
    } catch (_) {
      return false;
    } finally {
      _lastRefreshAt = DateTime.now();
      _refreshInFlight = false;
      if (_refreshQueued) {
        _refreshQueued = false;
        _scheduleRefreshFromDb(const Duration(milliseconds: 120));
      }
    }
  }

  Future<void> _initStatusFromDb({
    int maxRetries = 6,
    int delayMs = 500,
  }) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      final ok = await _refreshFromDb();
      if (ok) return;
      await Future.delayed(Duration(milliseconds: delayMs));
    }
    await _refreshFromDb();
  }

  void _startLocalControlsCooldown() {
    _localControlsCooldownTimer?.cancel();
    setState(() => isControlsCoolingDown = true);
    _localControlsCooldownTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => isControlsCoolingDown = false);
    });
  }

  @override
  void dispose() {
    _localControlsCooldownTimer?.cancel();
    _micUiCooldownTimer?.cancel();
    _refreshDebounce?.cancel();
    _playlist.state.removeListener(_syncFromPlaylistState);
    if (micOn && !_micService.isStopping) {
      _micService.stopStreaming();
    }
    super.dispose();
  }

  Future<void> _toggleMic() async {
    if (_micService.isStopping) return;
    if (!liveOn) {
      AppSnackbar.error('โหมดถ่ายทอดปิดอยู่', 'ไม่สามารถเปิดไมโครโฟนได้');
      return;
    }
    final start = DateTime.now();
    LoadingOverlay.show(context);
    try {
      if (micOn) {
        await _micService.stopStreaming();
        final elapsed = DateTime.now().difference(start).inMilliseconds;
        final remain = 10000 - elapsed;
        if (remain > 0) {
          await Future.delayed(Duration(milliseconds: remain));
        }
        if (mounted) {
          setState(() {
            micOn = false;
            _startMicControlsCooldown();
          });
        }
        AppSnackbar.success('ไมโครโฟน', 'ปิดไมโครโฟนแล้ว');
      } else {
        if (playbackMode == PlaybackMode.none) {
          // No pre-action required; open mic immediately
        } else {
          try {
            final api = await ApiService.private();
            if (playbackMode == PlaybackMode.playlist ||
                playbackMode == PlaybackMode.file) {
              await api.get('/stream/pause');
            } else if (playbackMode == PlaybackMode.youtube) {
              await api.get('/stream/stop');
            }
          } catch (_) {
            // Continue attempting to open mic even if pre-action fails
          }

          await Future.delayed(const Duration(seconds: 8));
        }

        final success = await _micService.startStreaming(_micServerUrl);

        final elapsed = DateTime.now().difference(start).inMilliseconds;
        final int targetMs = playbackMode == PlaybackMode.none ? 5000 : 10000;
        final remain = targetMs - elapsed;
        if (remain > 0) {
          await Future.delayed(Duration(milliseconds: remain));
        }

        if (success) {
          if (mounted) {
            setState(() {
              micOn = true;
              _micUiCooldownTimer?.cancel();
              _micUiDisabled = true;
            });
          }
          AppSnackbar.success('ไมโครโฟน', 'เปิดไมโครโฟนแล้ว');
        } else {
          AppSnackbar.error('ข้อผิดพลาด', 'ไม่สามารถเปิดไมโครโฟนได้');
        }
      }
    } finally {
      LoadingOverlay.hide();
    }
  }

  void _startMicControlsCooldown() {
    _micUiCooldownTimer?.cancel();
    _micUiDisabled = true;
    _micUiCooldownTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _micUiDisabled = false;
      });
    });
  }

  Future<void> _toggleLive() async {
    final bool target = !liveOn;
    LoadingOverlay.show(context);
    try {
      final api = await ApiService.private();
      final resp = await api.put(
        '/device/stream-enabled',
        data: {'enabled': target},
      );

      if (!target) {
        try {
          await api.get('/stream/stop');
        } catch (_) {}
        if (micOn && !_micService.isStopping) {
          try {
            await _micService.stopStreaming();
          } catch (_) {}
          if (mounted)
            setState(() {
              micOn = false;
            });
        }
      }
      if (mounted)
        setState(() {
          liveOn = target;
        });
      await _refreshFromDb();
      if (target) {
        final zones =
            (resp['enabledZones'] as List<dynamic>?)?.cast<int>() ??
            const <int>[];
        AppSnackbar.success(
          'ถ่ายทอด',
          zones.isNotEmpty
              ? 'เริ่มถ่ายทอดแล้ว ${zones.length} โซน'
              : 'เริ่มถ่ายทอดแล้ว',
        );
      } else {
        AppSnackbar.success('ถ่ายทอด', 'หยุดถ่ายทอดและปิดทุกโซนแล้ว');
      }
    } catch (e) {
      AppSnackbar.error('ข้อผิดพลาด', 'ไม่สามารถเปลี่ยนสถานะถ่ายทอดได้');
    } finally {
      LoadingOverlay.hide();
    }
  }

  Future<void> _onPlayPressed() async {
    if (isPlaying || isPaused) {
      await _stopActive();
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.playlist_play),
                title: const Text('รายการเพลง'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  try {
                    await _playlist.start();
                    // Refresh from DB/engine to set the mode reliably
                    await _refreshFromDb();
                  } catch (e) {
                    AppSnackbar.error('ข้อผิดพลาด', e.toString());
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.library_music),
                title: const Text('ไฟล์เพลง'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showSongFilePicker();
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library),
                title: const Text('YouTube (URL)'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showYoutubeInput();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showSongFilePicker() async {
    List<dynamic> songs = [];
    LoadingOverlay.show(context);
    try {
      final api = await ApiService.private();
      final res = await api.get('/song');
      songs = res['data'] ?? [];
    } catch (e) {
      AppSnackbar.error('ข้อผิดพลาด', 'ไม่สามารถดึงรายการไฟล์เพลงได้');
      LoadingOverlay.hide();
      return;
    }
    LoadingOverlay.hide();

    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.7,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    'เลือกไฟล์เพลง',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: songs.isEmpty
                      ? const Center(child: Text('ไม่มีไฟล์เพลง'))
                      : ListView.separated(
                          itemCount: songs.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (c, i) {
                            final s = songs[i];
                            final title =
                                (s['name'] ??
                                        s['title'] ??
                                        s['url'] ??
                                        'ไม่ทราบชื่อ')
                                    .toString();
                            final filename = (s['url'] ?? s['file'] ?? '')
                                .toString();
                            return ListTile(
                              title: Text(title),
                              subtitle: Text(filename),
                              onTap: () async {
                                Navigator.of(ctx).pop();
                                // Try to start local file. Use path relative to backend cwd: uploads/<filename>
                                if (filename.isEmpty) {
                                  AppSnackbar.error(
                                    'ข้อผิดพลาด',
                                    'ไฟล์ไม่สามารถใช้งานได้',
                                  );
                                  return;
                                }
                                try {
                                  final api = await ApiService.private();
                                  final id =
                                      (s['_id'] ?? s['id'] ?? s['songId'])
                                          ?.toString();
                                  if (id == null || id.isEmpty) {
                                    AppSnackbar.error(
                                      'ข้อผิดพลาด',
                                      'ข้อมูลเพลงไม่ถูกต้อง',
                                    );
                                    return;
                                  }
                                  await api.get(
                                    '/stream/start-file',
                                    query: {'songId': id},
                                  );
                                  await _refreshFromDb();
                                  AppSnackbar.success(
                                    'สำเร็จ',
                                    'เริ่มเล่นไฟล์เพลงแล้ว',
                                  );
                                } catch (e) {
                                  AppSnackbar.error(
                                    'ข้อผิดพลาด',
                                    'ไม่สามารถเริ่มไฟล์เพลงได้',
                                  );
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showYoutubeInput() async {
    final ctrl = TextEditingController();
    if (!mounted) return;

    bool isValidYoutubeUrl(String u) {
      final s = u.toLowerCase();
      return s.contains('youtube.com') || s.contains('youtu.be');
    }

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('เล่นจาก YouTube'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              hintText: 'วางลิงก์ YouTube ที่นี่',
            ),
            keyboardType: TextInputType.url,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () async {
                final url = ctrl.text.trim();
                if (url.isEmpty) return;
                if (!isValidYoutubeUrl(url)) {
                  AppSnackbar.error('ข้อผิดพลาด', 'URL YouTube ไม่ถูกต้อง');
                  return;
                }
                Navigator.of(ctx).pop();
                LoadingOverlay.show(context);
                try {
                  final api = await ApiService.private();
                  await api.get('/stream/start-youtube', query: {'url': url});
                  await _refreshFromDb();
                  AppSnackbar.success('สำเร็จ', 'เริ่มเล่นจาก YouTube แล้ว');
                } catch (e) {
                  LoadingOverlay.hide();
                  AppSnackbar.error(
                    'ข้อผิดพลาด',
                    'ไม่สามารถเริ่มเล่นจาก YouTube ได้',
                  );
                } finally {
                  LoadingOverlay.hide();
                }
              },
              child: const Text('เริ่มเล่น'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _togglePause() async {
    if (!(isPlaying || isPaused)) return;

    try {
      if (playbackMode == PlaybackMode.playlist) {
        if (_playlist.state.value.isControlsCoolingDown) return;
        await _playlist.togglePauseResume();
        if (mounted) setState(() => isPaused = _playlist.state.value.isPaused);
        AppSnackbar.success(
          'แจ้งเตือน',
          _playlist.state.value.isPaused ? 'หยุดชั่วคราว' : 'เล่นต่อ',
        );
        _startLocalControlsCooldown();
      } else if (playbackMode == PlaybackMode.file) {
        final api = await ApiService.private();
        if (isPaused) {
          await api.get('/stream/resume');
          if (mounted) setState(() => isPaused = false);
          AppSnackbar.success('สำเร็จ', 'เล่นต่อ');
        } else {
          await api.get('/stream/pause');
          if (mounted) setState(() => isPaused = true);
          AppSnackbar.success('สำเร็จ', 'หยุดชั่วคราว');
        }
        _startLocalControlsCooldown();
      } else if (playbackMode == PlaybackMode.youtube) {
        await _stopActive();
      }
    } catch (error) {
      AppSnackbar.error('ข้อผิดพลาด', 'ไม่สามารถดำเนินการได้');
    }
  }

  Future<void> _nextSong() async => await _playlist.next();
  Future<void> _prevSong() async => await _playlist.prev();

  Future<void> _stopActive() async {
    try {
      final api = await ApiService.private();
      await api.get('/stream/stop');
      await _refreshFromDb();
      AppSnackbar.success('สำเร็จ', 'หยุดการเล่นแล้ว');
    } catch (e) {
      AppSnackbar.error('ข้อผิดพลาด', 'ไม่สามารถหยุดการเล่นได้');
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Colors.blue[700]!;

    final bool hasActiveMode =
        playbackMode != PlaybackMode.none || isPlaying || isPaused;
    final bool controlsDisabled = micOn || _micUiDisabled || !liveOn;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _CircularToggleButton(
                    isActive: liveOn,
                    activeIcon: Icons.live_tv,
                    inactiveIcon: Icons.live_tv_outlined,
                    activeLabel: 'หยุดถ่ายทอด',
                    inactiveLabel: 'เริ่มถ่ายทอด',
                    activeColor: Colors.red[600]!,
                    inactiveColor: Colors.grey[700]!,
                    onTap: _toggleLive,
                    enabled: !micOn,
                  ),
                  const SizedBox(width: 24),
                  _CircularToggleButton(
                    isActive: controlsDisabled ? false : hasActiveMode,
                    activeIcon: isLoading ? Icons.hourglass_empty : Icons.stop,
                    inactiveIcon: isLoading
                        ? Icons.hourglass_empty
                        : Icons.play_arrow,
                    activeLabel: isLoading ? 'กำลังโหลด...' : 'หยุดเล่น',
                    inactiveLabel: isLoading ? 'กำลังโหลด...' : 'เล่นเพลง',
                    activeColor: Colors.red[600]!,
                    inactiveColor: Colors.green[600]!,
                    onTap: () {
                      if (isLoading) return;
                      if (controlsDisabled) return;
                      if (hasActiveMode) {
                        _stopActive();
                      } else {
                        _onPlayPressed();
                      }
                    },
                    enabled: !isLoading && !controlsDisabled,
                  ),
                  const SizedBox(width: 24),
                  _CircularToggleButton(
                    isActive: micOn,
                    activeIcon: Icons.mic,
                    inactiveIcon: Icons.mic_off,
                    activeLabel: 'ปิดไมค์',
                    inactiveLabel: 'เปิดไมค์',
                    activeColor: Colors.green[600]!,
                    inactiveColor: Colors.grey[700]!,
                    onTap: _toggleMic,
                    enabled: micOn || liveOn,
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.volume_down,
                            size: 28,
                            color: Colors.grey[600],
                          ),
                          Expanded(
                            child: Slider(
                              min: 0.0,
                              max: 3.0,
                              value: micVolume.clamp(0.0, 3.0),
                              onChanged: !controlsDisabled
                                  ? (v) {
                                      setState(() => micVolume = v);
                                      _saveMicVolume(v);
                                    }
                                  : null,
                              activeColor: accent,
                            ),
                          ),
                          Icon(Icons.volume_up, size: 28, color: accent),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              if ((playbackMode == PlaybackMode.playlist ||
                      playbackMode == PlaybackMode.file) &&
                  !isLoading) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[100]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Builder(
                        builder: (context) {
                          final prevDisabled =
                              playbackMode != PlaybackMode.playlist ||
                              (currentSongIndex <= 1 && !isLoopEnabled) ||
                              isControlsCoolingDown ||
                              controlsDisabled;
                          return _buildCircularToggleButton(
                            isActive: false,
                            activeIcon: Icons.skip_previous,
                            inactiveIcon: Icons.skip_previous,
                            activeLabel: 'เพลงก่อนหน้า',
                            inactiveLabel: 'เพลงก่อนหน้า',
                            activeColor: Colors.blue[700]!,
                            inactiveColor: prevDisabled
                                ? Colors.grey
                                : Colors.blue[700]!,
                            onTap: _prevSong,
                            enabled: !prevDisabled,
                          );
                        },
                      ),
                      const SizedBox(width: 32),

                      Opacity(
                        opacity: isControlsCoolingDown ? 0.3 : 1.0,
                        child: () {
                          return _buildCircularToggleButton(
                            isActive: isPaused,
                            activeIcon: Icons.play_circle,
                            inactiveIcon: Icons.pause_circle,
                            activeLabel: 'เล่นต่อ',
                            inactiveLabel: 'หยุด',
                            activeColor: Colors.green[600]!,
                            inactiveColor: isControlsCoolingDown
                                ? Colors.grey
                                : Colors.orange[700]!,
                            onTap: _togglePause,
                            enabled:
                                !isControlsCoolingDown && !controlsDisabled,
                          );
                        }(),
                      ),

                      const SizedBox(width: 32),

                      Builder(
                        builder: (context) {
                          final nextDisabled =
                              playbackMode != PlaybackMode.playlist ||
                              (currentSongIndex >= totalSongs &&
                                  !isLoopEnabled) ||
                              isControlsCoolingDown ||
                              controlsDisabled;
                          return _buildCircularToggleButton(
                            isActive: false,
                            activeIcon: Icons.skip_next,
                            inactiveIcon: Icons.skip_next,
                            activeLabel: 'เพลงถัดไป',
                            inactiveLabel: 'เพลงถัดไป',
                            activeColor: Colors.blue[700]!,
                            inactiveColor: nextDisabled
                                ? Colors.grey
                                : Colors.blue[700]!,
                            onTap: _nextSong,
                            enabled: !nextDisabled,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 12),

        if ((playbackMode == PlaybackMode.playlist && totalSongs > 0) ||
            (playbackMode == PlaybackMode.file &&
                currentSongTitle.isNotEmpty) ||
            (playbackMode == PlaybackMode.youtube))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue[700]!.withValues(alpha: 0.1),
                  Colors.blue[500]!.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue[700],
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Icon(
                    Icons.music_note,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        playbackMode == PlaybackMode.youtube
                            ? 'กำลังเล่นจาก YouTube'
                            : (currentSongTitle.isNotEmpty
                                  ? currentSongTitle
                                  : 'กำลังโหลดข้อมูลเพลง...'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (playbackMode == PlaybackMode.playlist)
                        Text(
                          'เพลงที่ $currentSongIndex จาก $totalSongs',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isPaused ? Colors.orange[100] : Colors.green[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPaused ? Icons.pause : Icons.graphic_eq,
                        size: 14,
                        color: isPaused
                            ? Colors.orange[700]
                            : Colors.green[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isPaused ? 'หยุดชั่วคราว' : 'กำลังเล่น',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isPaused
                              ? Colors.orange[700]
                              : Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

Widget _buildCircularToggleButton({
  required bool isActive,
  required IconData activeIcon,
  required IconData inactiveIcon,
  required String activeLabel,
  required String inactiveLabel,
  required Color activeColor,
  required Color inactiveColor,
  required VoidCallback onTap,
  bool enabled = true,
}) {
  return _CircularToggleButton(
    isActive: isActive,
    activeIcon: activeIcon,
    inactiveIcon: inactiveIcon,
    activeLabel: activeLabel,
    inactiveLabel: inactiveLabel,
    activeColor: activeColor,
    inactiveColor: inactiveColor,
    onTap: onTap,
    enabled: enabled,
  );
}

class _CircularToggleButton extends StatelessWidget {
  final bool isActive;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String activeLabel;
  final String inactiveLabel;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;
  final bool enabled;

  const _CircularToggleButton({
    Key? key,
    required this.isActive,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.activeLabel,
    required this.inactiveLabel,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.35,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (isActive ? activeColor : inactiveColor).withValues(
                  alpha: 0.15,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isActive ? activeIcon : inactiveIcon,
                color: isActive ? activeColor : inactiveColor,
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isActive ? activeLabel : inactiveLabel,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
