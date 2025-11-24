import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smart_control/services/playlist_service.dart';
import 'package:smart_control/core/network/api_service.dart';
import 'package:smart_control/services/mic_stream_service.dart';
import 'package:smart_control/services/stream_service.dart';
import 'package:smart_control/core/alert/app_snackbar.dart';
import 'package:smart_control/widgets/buttons/action_button.dart';
import 'package:smart_control/widgets/inputs/text_field_box.dart';
import 'package:smart_control/widgets/loading_overlay.dart';
import 'package:smart_control/core/services/StreamStatusService.dart';
import 'package:smart_control/core/config/app_config.dart';
import 'package:smart_control/widgets/modals/modal_bottom_sheet.dart';

enum PlaybackMode { none, playlist, file, youtube, schedule }

// Constants
class _ControlPanelConstants {
  static const Duration controlsCooldown = Duration(seconds: 8);
  static const Duration refreshDebounce = Duration(milliseconds: 300);
  static const Duration minRefreshInterval = Duration(milliseconds: 150);
  static const double defaultMicVolume = 1.5;
}

class ControlPanel extends StatefulWidget {
  const ControlPanel({Key? key}) : super(key: key);

  @override
  State<ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends State<ControlPanel> {
  final PlaylistService _playlist = PlaylistService.instance;
  final MicStreamService _micService = MicStreamService();
  final StreamStatusService _statusSse = StreamStatusService();
  final StreamService _streamService = StreamService.instance;

  bool micOn = false;
  bool streamEnabled = true;
  double micVolume = _ControlPanelConstants.defaultMicVolume;

  // Debounced/throttled status refresh helpers
  Timer? _refreshDebounce;
  bool _refreshInFlight = false;
  bool _refreshQueued = false;
  DateTime? _lastRefreshAt;

  // Playlist state
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

  // Schedule state
  bool scheduleActive = false;
  String scheduleSongName = '';
  String scheduleTime = '';
  List<int> scheduleDays = [];
  String scheduleDescription = '';

  static const String _micServerUrl = AppConfig.wsMic;

  @override
  void initState() {
    super.initState();

    _playlist.ensureInitialized();
    _syncFromPlaylistState();
    _playlist.state.addListener(_syncFromPlaylistState);

    // Initialize playback mode and engine status from backend/DB (with retries)
    _initStatusFromDb();

    _loadMicVolume();

    // Realtime sync via SSE: reflect backend status regardless of local actions
    _statusSse.onStatusUpdate = (data) => _applySseStatus(data);
    _statusSse.connect();

    _micService.onStatusChanged = (isRecording) {
      if (!mounted) return;
      setState(() {
        micOn = isRecording;
      });
    };

    _micService.onError = (error) {
      if (!mounted) return;
      AppSnackbar.error('ข้อผิดพลาด', error);
    };
  }

  // ----------------------------
  // Types and helpers
  // ----------------------------

  Future<void> _loadMicVolume() async {
    try {
      final api = await ApiService.private();
      final response = await api.get('/settings/micVolume');

      if (response['ok'] == true && response['value'] != null) {
        final value = response['value'];
        if (mounted) {
          setState(() {
            micVolume = (value is num)
                ? value.toDouble()
                : _ControlPanelConstants.defaultMicVolume;
          });
          print('🎚️ Mic Volume from DB: $micVolume');
        }
      }
    } catch (error) {
      print('⚠️ ไม่สามารถดึง Mic Volume จาก DB ได้: $error');
      if (mounted) {
        setState(() {
          micVolume = _ControlPanelConstants.defaultMicVolume;
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
      case 'schedule':
        return PlaybackMode.schedule;
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

      if (data.containsKey('stream_enabled')) {
        final streamEnabledValue = data['stream_enabled'];
        if (streamEnabledValue is bool && mounted) {
          setState(() {
            streamEnabled = streamEnabledValue;
          });
        }
      }

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
        // Avoid overriding file title with the mic sentinel or on mic events
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
      } else if (mode == PlaybackMode.schedule) {
        // รับข้อมูล schedule จาก SSE
        if (data['currentSchedule'] != null) {
          final sched = data['currentSchedule'];
          title = (sched['songName'] ?? '').toString();

          if (mounted) {
            setState(() {
              scheduleActive = true;
              scheduleSongName = (sched['songName'] ?? '').toString();
              scheduleTime = (sched['time'] ?? '').toString();
              scheduleDays = List<int>.from(sched['days'] ?? []);
              scheduleDescription = (sched['description'] ?? '').toString();
            });
          }
        }
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

        // Reset schedule state เฉพาะเมื่อ schedule จบจริงๆ (ไม่ใช่แค่ pause)
        if (event == 'schedule-ended') {
          scheduleActive = false;
          scheduleSongName = '';
          scheduleTime = '';
          scheduleDays = [];
          scheduleDescription = '';
        }
        // ถ้า mode ไม่ใช่ schedule และไม่ใช่ event paused ให้ reset schedule state
        else if (mode != PlaybackMode.schedule && event != 'paused') {
          scheduleActive = false;
          scheduleSongName = '';
          scheduleTime = '';
          scheduleDays = [];
          scheduleDescription = '';
        }
      });

      // For events that may not include full state, fetch authoritative status
      if (playingMaybe == null ||
          event == 'mic-started' ||
          event == 'mic-stopped' ||
          event == 'stopped' ||
          event == 'stopped-all' ||
          event == 'ended' ||
          event == 'schedule-ended') {
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
    Duration delay = _ControlPanelConstants.refreshDebounce,
  ]) {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(delay, () {
      _refreshFromDb();
    });
  }

  Future<bool> _refreshFromDb() async {
    final now = DateTime.now();
    if (_lastRefreshAt != null &&
        now.difference(_lastRefreshAt!) <
            _ControlPanelConstants.minRefreshInterval) {
      _scheduleRefreshFromDb(_ControlPanelConstants.minRefreshInterval);
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
      bool streamEnabledFromDb = false;

      // ตรวจสอบทุกโซน ถ้ามีโซนใดโซนหนึ่งเปิดใช้งานถือว่าระบบถ่ายทอดเปิดอยู่
      for (final device in devices) {
        final streamEnabledValue = device['status']?['stream_enabled'];
        if (streamEnabledValue == true) {
          streamEnabledFromDb = true;
          break;
        }
      }

      if (devices.isNotEmpty) {
        final first = devices.first;
        final m = (first['status']?['playback_mode'] ?? 'none').toString();
        if (m.isNotEmpty) mode = _parseMode(m);
      }

      final engine = await api.get('/stream/status');
      final data = engine['data'] ?? engine;
      final bool engIsPlaying = data['isPlaying'] == true;
      final bool engIsPaused = data['isPaused'] == true;
      final PlaybackMode activeMode = _parseMode(
        data['activeMode'] ?? data['mode'] ?? 'none',
      );
      final bool engPlaylistMode =
          activeMode == PlaybackMode.playlist || data['playlistMode'] == true;

      // ดึงข้อมูล schedule
      bool schedActive = false;
      String schedSongName = '';
      String schedTime = '';
      List<int> schedDays = [];
      String schedDesc = '';

      if (data['schedule'] != null) {
        final sched = data['schedule'];
        schedActive = sched['isPlaying'] == true;
        if (sched['currentSchedule'] != null) {
          final curr = sched['currentSchedule'];
          schedSongName = (curr['songName'] ?? '').toString();
          schedTime = (curr['time'] ?? '').toString();
          schedDays = List<int>.from(curr['days'] ?? []);
          schedDesc = (curr['description'] ?? '').toString();
        }
      }

      String title = currentSongTitle;
      int idx = currentSongIndex;
      int tot = totalSongs;
      if (engPlaylistMode && data['currentSong'] != null) {
        final cs = data['currentSong'];
        title = (cs['title'] ?? '').toString();
        idx = ((cs['index'] ?? 0) as int) + 1;
        tot = (cs['total'] ?? data['totalSongs'] ?? 0) as int;
      } else if (activeMode == PlaybackMode.schedule) {
        // แสดงชื่อเพลงจาก schedule
        if (schedActive && schedSongName.isNotEmpty) {
          title = schedSongName;
        }
        // ถ้า pause อยู่ ให้คงค่า schedule state เดิมไว้ ไม่ต้องเคลียร์
        if (engIsPaused) {
          schedActive = this.scheduleActive || schedActive;
          schedSongName = this.scheduleSongName.isNotEmpty
              ? this.scheduleSongName
              : schedSongName;
          schedTime = this.scheduleTime.isNotEmpty
              ? this.scheduleTime
              : schedTime;
          schedDays = this.scheduleDays.isNotEmpty
              ? this.scheduleDays
              : schedDays;
          schedDesc = this.scheduleDescription.isNotEmpty
              ? this.scheduleDescription
              : schedDesc;
        }
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
        streamEnabled = streamEnabledFromDb;

        // อัปเดต schedule state
        scheduleActive = schedActive;
        scheduleSongName = schedSongName;
        scheduleTime = schedTime;
        scheduleDays = schedDays;
        scheduleDescription = schedDesc;
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
    _localControlsCooldownTimer = Timer(
      _ControlPanelConstants.controlsCooldown,
      () {
        if (mounted) setState(() => isControlsCoolingDown = false);
      },
    );
  }

  @override
  void dispose() {
    _localControlsCooldownTimer?.cancel();
    _refreshDebounce?.cancel();
    _playlist.state.removeListener(_syncFromPlaylistState);
    if (micOn && !_micService.isStopping) {
      _micService.stopStreaming();
    }
    super.dispose();
  }

  Future<void> _toggleMic() async {
    if (_micService.isStopping) return;

    LoadingOverlay.show(context);
    try {
      if (micOn) {
        // Stop mic
        await _micService.stopStreaming();
        AppSnackbar.success('ไมโครโฟน', 'ปิดไมโครโฟนแล้ว');
      } else {
        // Pause or stop active playback before starting mic
        if (playbackMode != PlaybackMode.none) {
          try {
            if (playbackMode == PlaybackMode.playlist ||
                playbackMode == PlaybackMode.file) {
              await _streamService.pause();
            } else if (playbackMode == PlaybackMode.youtube ||
                playbackMode == PlaybackMode.schedule) {
              await _streamService.stop();
            }
            // Wait for backend to process stop/pause
            await Future.delayed(const Duration(seconds: 3));
          } catch (e) {
            print('⚠️ Failed to stop/pause before mic: $e');
          }
        }

        // Start mic stream
        final success = await _micService.startStreaming(_micServerUrl);

        if (success) {
          AppSnackbar.success('ไมโครโฟน', 'เปิดไมโครโฟนแล้ว');
        } else {
          AppSnackbar.error('ข้อผิดพลาด', 'ไม่สามารถเปิดไมโครโฟนได้');
        }
      }
    } catch (e) {
      AppSnackbar.error('ข้อผิดพลาด', 'เกิดข้อผิดพลาด: $e');
    } finally {
      LoadingOverlay.hide();
    }
  }

  Future<void> _toggleStream() async {
    LoadingOverlay.show(context);
    try {
      if (streamEnabled) {
        await _streamService.disableStream();
        setState(() {
          streamEnabled = false;
        });
        AppSnackbar.success('สำเร็จ', 'หยุดการถ่ายทอดทุกโซน');
      } else {
        await _streamService.enableStream();
        setState(() {
          streamEnabled = true;
        });
        AppSnackbar.success('สำเร็จ', 'เริ่มการถ่ายทอดแล้ว');
      }

      await _refreshFromDb();
    } catch (e) {
      AppSnackbar.error('ข้อผิดพลาด', e.toString());
    } finally {
      LoadingOverlay.hide();
    }
  }

  Future<void> _onPlayPressed() async {
    if (isPlaying || isPaused) {
      await _stopActive();
      return;
    }

    ModalBottomSheet.show(
      context: context,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.playlist_play),
              title: const Text('รายการเพลง'),
              onTap: () async {
                Navigator.of(context).pop();
                try {
                  await _streamService.playPlaylist();
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
                Navigator.of(context).pop();
                _showSongFilePicker();
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('YouTube (URL)'),
              onTap: () {
                Navigator.of(context).pop();
                _showYoutubeInput();
              },
            ),
          ],
        ),
      ),
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

    if (songs.isEmpty) {
      AppSnackbar.info('แจ้งเตือน', 'ไม่มีไฟล์เพลงในระบบ');
      return;
    }

    final selectedSong =
        await ModalBottomSheet.showDraggable<Map<String, dynamic>>(
          context: context,
          title: 'เลือกไฟล์เพลง',
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          showSearch: true,
          searchHint: 'ค้นหาเพลง...',
          builder: (context, scrollController, searchQuery) {
            // Filter songs based on search query
            final filteredSongs = searchQuery.isEmpty
                ? songs
                : songs.where((song) {
                    final name =
                        (song['name'] ?? song['title'] ?? song['url'] ?? '')
                            .toString()
                            .toLowerCase();
                    final url = (song['url'] ?? song['file'] ?? '')
                        .toString()
                        .toLowerCase();
                    final query = searchQuery.toLowerCase();
                    return name.contains(query) || url.contains(query);
                  }).toList();

            if (filteredSongs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'ไม่พบไฟล์เพลงที่ค้นหา',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              controller: scrollController,
              itemCount: filteredSongs.length,
              itemBuilder: (context, index) {
                final song = filteredSongs[index];
                final title =
                    (song['name'] ??
                            song['title'] ??
                            song['url'] ??
                            'ไม่ทราบชื่อ')
                        .toString();
                final filename = (song['url'] ?? song['file'] ?? '').toString();

                return ListTile(
                  leading: Icon(Icons.music_note, color: Colors.blue[700]),
                  title: Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    filename,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  onTap: () {
                    Navigator.pop(context, song);
                  },
                );
              },
            );
          },
        );

    if (selectedSong != null) {
      final filename = (selectedSong['url'] ?? selectedSong['file'] ?? '')
          .toString();
      if (filename.isEmpty) {
        AppSnackbar.error('ข้อผิดพลาด', 'ไฟล์ไม่สามารถใช้งานได้');
        return;
      }

      LoadingOverlay.show(context);
      try {
        final id =
            (selectedSong['_id'] ??
                    selectedSong['id'] ??
                    selectedSong['songId'])
                ?.toString();
        if (id == null || id.isEmpty) {
          AppSnackbar.error('ข้อผิดพลาด', 'ข้อมูลเพลงไม่ถูกต้อง');
          return;
        }
        await _streamService.playFile(id);
        await _refreshFromDb();
        AppSnackbar.success('สำเร็จ', 'เริ่มเล่นไฟล์เพลงแล้ว');
      } catch (e) {
        AppSnackbar.error('ข้อผิดพลาด', 'ไม่สามารถเริ่มไฟล์เพลงได้');
      } finally {
        LoadingOverlay.hide();
      }
    }
  }

  Future<void> _showYoutubeInput() async {
    final ctrl = TextEditingController();
    if (!mounted) return;

    bool isValidYoutubeUrl(String u) {
      final s = u.toLowerCase();
      return s.contains('youtube.com') || s.contains('youtu.be');
    }

    await ModalBottomSheet.showFormModal(
      context: context,
      title: 'เล่นจาก YouTube',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFieldBox(controller: ctrl, hint: 'วางลิงก์ YouTube ที่นี่'),
        ],
      ),
      actions: Button(
        onPressed: () async {
          final url = ctrl.text.trim();
          if (url.isEmpty) return;
          if (!isValidYoutubeUrl(url)) {
            AppSnackbar.error('ข้อผิดพลาด', 'URL YouTube ไม่ถูกต้อง');
            return;
          }
          Navigator.of(context).pop();
          LoadingOverlay.show(context);
          try {
            await _streamService.playYoutube(url);
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
        label: 'เริ่มเล่น',
        icon: Icons.play_arrow,
      ),
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
      } else if (playbackMode == PlaybackMode.file ||
          playbackMode == PlaybackMode.schedule) {
        if (isPaused) {
          await _streamService.resume();
          if (mounted) setState(() => isPaused = false);
          AppSnackbar.success('สำเร็จ', 'เล่นต่อ');
        } else {
          await _streamService.pause();
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
      await _streamService.stop();
      await _refreshFromDb();
      AppSnackbar.success('สำเร็จ', 'หยุดการเล่นแล้ว');
    } catch (e) {
      AppSnackbar.error('ข้อผิดพลาด', 'ไม่สามารถหยุดการเล่นได้');
    }
  }

  String _getDayName(int dayNum) {
    const days = ['อา.', 'จ.', 'อ.', 'พ.', 'พฤ.', 'ศ.', 'ส.'];
    if (dayNum >= 0 && dayNum < days.length) return days[dayNum];
    return '';
  }

  Widget _buildScheduleInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple[50]!, Colors.purple[100]!],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, color: Colors.purple[700], size: 14),
              const SizedBox(width: 8),
              Text(
                'เพลงตั้งเวลา',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple[900],
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.settings, color: Colors.purple[700]),
                onPressed: () {
                  Navigator.pushNamed(context, '/settings/schedule');
                },
                tooltip: 'ตั้งค่าเพลงตั้งเวลา',
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scheduleDescription,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.purple[900],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: Colors.purple[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          scheduleTime,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.purple[700],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Colors.purple[600],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            scheduleDays.map(_getDayName).join(', '),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.purple[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.music_note,
                          size: 16,
                          color: Colors.purple[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          scheduleSongName,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.purple[600],
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasActiveMode =
        playbackMode != PlaybackMode.none || isPlaying || isPaused;

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
                    isActive: streamEnabled,
                    activeIcon: Icons.broadcast_on_personal,
                    inactiveIcon: Icons.broadcast_on_personal_outlined,
                    activeLabel: 'หยุดถ่ายทอด',
                    inactiveLabel: 'เริ่มถ่ายทอด',
                    activeColor: Colors.red[600]!,
                    inactiveColor: Colors.grey[700]!,
                    onTap: _toggleStream,
                    enabled: !micOn,
                  ),
                  const SizedBox(width: 24),
                  _CircularToggleButton(
                    isActive: hasActiveMode,
                    activeIcon: isLoading ? Icons.hourglass_empty : Icons.stop,
                    inactiveIcon: isLoading
                        ? Icons.hourglass_empty
                        : Icons.play_arrow,
                    activeLabel: isLoading ? 'กำลังโหลด...' : 'หยุดเล่น',
                    inactiveLabel: isLoading ? 'กำลังโหลด...' : 'เล่นเพลง',
                    activeColor: Colors.red[600]!,
                    inactiveColor: Colors.green[600]!,
                    onTap: () {
                      if (isLoading || micOn) return;
                      if (hasActiveMode) {
                        _stopActive();
                      } else {
                        _onPlayPressed();
                      }
                    },
                    enabled: !isLoading && streamEnabled && !micOn,
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
                    enabled: streamEnabled,
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
                              max: 9.9,
                              value: micVolume.clamp(0.0, 9.9),
                              onChanged: (v) {
                                setState(() => micVolume = v);
                                _saveMicVolume(v);
                              },
                              activeColor: Colors.blue,
                              inactiveColor: Colors.grey,
                              label: 'ระดับเสียงไมโครโฟน',
                              divisions: 9,
                            ),
                          ),
                          Icon(Icons.volume_up, size: 28, color: Colors.blue),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              if ((playbackMode == PlaybackMode.playlist ||
                      playbackMode == PlaybackMode.file ||
                      playbackMode == PlaybackMode.schedule) &&
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
                              micOn;
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

                      // Center button: pause/resume for playlist/file, stop for youtube
                      Opacity(
                        opacity: (isControlsCoolingDown || micOn) ? 0.3 : 1.0,
                        child: () {
                          return _buildCircularToggleButton(
                            isActive: isPaused,
                            activeIcon: Icons.play_circle,
                            inactiveIcon: Icons.pause_circle,
                            activeLabel: 'เล่นต่อ',
                            inactiveLabel: 'หยุด',
                            activeColor: Colors.green[600]!,
                            inactiveColor: (isControlsCoolingDown || micOn)
                                ? Colors.grey
                                : Colors.orange[700]!,
                            onTap: _togglePause,
                            enabled: !isControlsCoolingDown && !micOn,
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
                              micOn;
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

              // แสดง Schedule Info
              if (playbackMode == PlaybackMode.schedule && scheduleActive) ...[
                const SizedBox(height: 12),
                _buildScheduleInfo(context),
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

// ============================
// UI widgets
// ============================
// Backwards-compatible factory function to keep existing call sites working
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
