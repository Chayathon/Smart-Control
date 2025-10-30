import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smart_control/services/playlist_service.dart';
import 'package:smart_control/core/network/api_service.dart';
import 'package:smart_control/services/mic_stream_service.dart';
import 'package:smart_control/core/alert/app_snackbar.dart';
import 'package:smart_control/widgets/loading_overlay.dart';
import 'package:smart_control/core/services/StreamStatusService.dart';

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
  double micVolume = 0.5;

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
  // Local playback mode: 'none' | 'playlist' | 'file' | 'youtube'
  String playbackMode = 'none';
  // bool _isFetchingSongs = false; (not used)
  Timer? _localControlsCooldownTimer;

  static const String _micServerUrl = "ws://192.168.1.83:8080/ws/mic";

  @override
  void initState() {
    super.initState();

    _playlist.ensureInitialized();
    _syncFromPlaylistState();
    _playlist.state.addListener(_syncFromPlaylistState);

    // Initialize playback mode and engine status from backend/DB
    _refreshFromDb();

    // Realtime sync via SSE: reflect backend status regardless of local actions
    _statusSse.onStatusUpdate = (data) {
      try {
        final String event = (data['event'] ?? '').toString();
        final String mode =
            (data['activeMode'] ??
                    data['requestedMode'] ??
                    (data['mode'] == 'playlist' ? 'playlist' : playbackMode))
                .toString();
        final bool? playingMaybe = data.containsKey('isPlaying')
            ? (data['isPlaying'] == true)
            : null;
        final bool? pausedMaybe = data.containsKey('isPaused')
            ? (data['isPaused'] == true)
            : null;

        String title = currentSongTitle;
        int idx = currentSongIndex;
        int tot = totalSongs;

        if (mode == 'playlist') {
          if (data['title'] != null) {
            title = data['title'].toString();
          } else if (data['extra'] != null && data['extra']['title'] != null) {
            title = data['extra']['title'].toString();
          }
          final int? iFromData = data['index'] is int
              ? (data['index'] as int)
              : (data['extra'] != null && data['extra']['index'] is int
                    ? data['extra']['index'] as int
                    : null);
          if (iFromData != null) idx = iFromData + 1;
          final int? tFromData = data['total'] is int
              ? (data['total'] as int)
              : (data['extra'] != null && data['extra']['total'] is int
                    ? data['extra']['total'] as int
                    : (data['totalSongs'] is int
                          ? data['totalSongs'] as int
                          : null));
          if (tFromData != null) tot = tFromData;
        } else if (mode == 'file') {
          // Prefer provided name, fallback to url-derived filename
          final nameField = data['name'] ?? data['title'];
          if (nameField != null && nameField.toString().isNotEmpty) {
            title = nameField.toString();
          } else {
            final url = (data['url'] ?? data['currentUrl'])?.toString();
            if (url != null && url.isNotEmpty) {
              final parts = url.replaceAll('\\', '/').split('/');
              if (parts.isNotEmpty) title = parts.last;
            }
          }
        } else if (mode == 'youtube') {
          final url = (data['url'] ?? data['currentUrl'])?.toString();
          if (url != null && url.isNotEmpty) title = url;
        }

        if (!mounted) return;
        setState(() {
          playbackMode = mode;
          if (playingMaybe != null) isPlaying = playingMaybe;
          if (pausedMaybe != null) isPaused = pausedMaybe;
          playlistActive = mode == 'playlist';
          currentSongTitle = title;
          currentSongIndex = idx;
          totalSongs = tot;
        });

        // For events that don't include full state (e.g., mic-started/ended), fetch authoritative status
        if (playingMaybe == null ||
            event == 'mic-started' ||
            event == 'mic-stopped' ||
            event == 'stopped' ||
            event == 'stopped-all' ||
            event == 'ended') {
          _refreshFromDb();
        }
      } catch (_) {
        // Fallback to a full refresh if parsing fails
        _refreshFromDb();
      }
    };
    _statusSse.connect();

    _micService.onStatusChanged = (isRecording) {
      if (!mounted) return;
      setState(() => micOn = isRecording);
    };

    _micService.onError = (error) {
      if (!mounted) return;
      AppSnackbar.error('ข้อผิดพลาด', error);
    };
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
      // Do not override playbackMode here; it is sourced from DB/engine status.
    });
  }

  Future<void> _refreshFromDb() async {
    try {
      final api = await ApiService.private();
      // Fetch devices to get status.playback_mode
      final devices = await api.get('/device') as List<dynamic>;
      String mode = playbackMode;
      if (devices.isNotEmpty) {
        // playing_mode is centrally synced, so any device carries it
        final first = devices.first;
        final m = (first['status']?['playback_mode'] ?? 'none').toString();
        if (m.isNotEmpty) mode = m;
      }

      // Fetch engine status for isPlaying/isPaused and playlist info
      final engine = await api.get('/stream/status');
      final data =
          engine['data'] ??
          engine; // controller returns {status:'success', data: ...}
      final bool engIsPlaying = data['isPlaying'] == true;
      final bool engIsPaused = data['isPaused'] == true;
      final String activeMode = (data['activeMode'] ?? data['mode'] ?? 'none')
          .toString();
      final bool engPlaylistMode =
          activeMode == 'playlist' || data['playlistMode'] == true;

      String title = currentSongTitle;
      int idx = currentSongIndex;
      int tot = totalSongs;
      if (engPlaylistMode && data['currentSong'] != null) {
        final cs = data['currentSong'];
        title = (cs['title'] ?? '').toString();
        idx = ((cs['index'] ?? 0) as int) + 1;
        tot = (cs['total'] ?? data['totalSongs'] ?? 0) as int;
      } else if (activeMode == 'file') {
        // Prefer name from engine status (backend now provides it)
        if (data['name'] != null && data['name'].toString().isNotEmpty) {
          title = data['name'].toString();
        } else if (data['title'] != null &&
            data['title'].toString().isNotEmpty) {
          title = data['title'].toString();
        } else {
          final url = (data['currentUrl'] ?? data['url'])?.toString();
          if (url != null && url.isNotEmpty) {
            final parts = url.replaceAll('\\', '/').split('/');
            if (parts.isNotEmpty) title = parts.last;
          }
        }
      } else if (activeMode == 'youtube') {
        // For YouTube, we keep a friendly label in UI; no need to set title here
      }

      if (!mounted) return;
      setState(() {
        playbackMode = mode;
        isPlaying = engIsPlaying;
        isPaused = engIsPaused;
        playlistActive = engPlaylistMode;
        currentSongTitle = title;
        currentSongIndex = idx;
        totalSongs = tot;
      });
    } catch (_) {
      // ignore errors silently for now
    }
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
    _playlist.state.removeListener(_syncFromPlaylistState);
    // Do not dispose singletons globally here; only stop streaming if active
    super.dispose();
  }

  Future<void> _toggleMic() async {
    if (_micService.isStopping) return;

    if (micOn) {
      await _micService.stopStreaming();
      if (mounted) setState(() => micOn = false);
      AppSnackbar.success('ไมโครโฟน', 'ปิดไมโครโฟนแล้ว');
    } else {
      final success = await _micService.startStreaming(_micServerUrl);
      if (success) {
        if (mounted) setState(() => micOn = true);
        AppSnackbar.success('ไมโครโฟน', 'เปิดไมโครโฟนแล้ว');
      } else {
        AppSnackbar.error('ข้อผิดพลาด', 'ไม่สามารถเปิดไมโครโฟนได้');
      }
    }
  }

  void _toggleLive() => setState(() => liveOn = !liveOn);

  // (playlist start/stop handled via _onPlayPressed and PlaylistService)

  // New handler: if currently playing/paused -> toggle stop. Otherwise show play options.
  Future<void> _onPlayPressed() async {
    // If already playing or paused, use existing toggle
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
    // No-op if nothing playing
    if (!(isPlaying || isPaused)) return;

    try {
      if (playbackMode == 'playlist') {
        if (_playlist.state.value.isControlsCoolingDown) return;
        await _playlist.togglePauseResume();
        if (mounted) setState(() => isPaused = _playlist.state.value.isPaused);
        AppSnackbar.success(
          'แจ้งเตือน',
          _playlist.state.value.isPaused ? 'หยุดชั่วคราว' : 'เล่นต่อ',
        );
        // mirror playlist cooldown visually
        _startLocalControlsCooldown();
      } else if (playbackMode == 'file') {
        // For local file, call pause/resume endpoints
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
      } else if (playbackMode == 'youtube') {
        // YouTube only supports stop
        await _stopActive();
      }
    } catch (error) {
      AppSnackbar.error('ข้อผิดพลาด', 'ไม่สามารถดำเนินการได้');
    }
  }

  Future<void> _nextSong() async => await _playlist.next();
  Future<void> _prevSong() async => await _playlist.prev();

  // Stop current active playback according to mode
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
      return InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (isActive ? activeColor : inactiveColor).withOpacity(
                  0.15,
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
      );
    }

    final bool hasActiveMode = playbackMode != 'none' || isPlaying || isPaused;

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
                  _buildCircularToggleButton(
                    isActive: micOn,
                    activeIcon: Icons.mic,
                    inactiveIcon: Icons.mic_off,
                    activeLabel: 'ปิดไมค์',
                    inactiveLabel: 'เปิดไมค์',
                    activeColor: Colors.green[600]!,
                    inactiveColor: Colors.grey[700]!,
                    onTap: _toggleMic,
                  ),
                  const SizedBox(width: 24),
                  _buildCircularToggleButton(
                    isActive: liveOn,
                    activeIcon: Icons.live_tv,
                    inactiveIcon: Icons.live_tv_outlined,
                    activeLabel: 'หยุดถ่ายทอด',
                    inactiveLabel: 'เริ่มถ่ายทอด',
                    activeColor: Colors.red[600]!,
                    inactiveColor: Colors.grey[700]!,
                    onTap: _toggleLive,
                  ),
                  const SizedBox(width: 24),
                  _buildCircularToggleButton(
                    // Show as active (stop) whenever any playback mode is active or paused.
                    isActive: hasActiveMode,
                    activeIcon: isLoading ? Icons.hourglass_empty : Icons.stop,
                    inactiveIcon: isLoading
                        ? Icons.hourglass_empty
                        : Icons.play_arrow,
                    activeLabel: isLoading ? 'กำลังโหลด...' : 'หยุดเล่น',
                    inactiveLabel: isLoading ? 'กำลังโหลด...' : 'เล่นเพลง',
                    activeColor: Colors.red[600]!,
                    inactiveColor: Colors.green[600]!,
                    // When loading, disable interaction. Otherwise, if any mode is active or paused -> stop;
                    // else open the play options sheet.
                    onTap: () {
                      if (isLoading) return;
                      if (hasActiveMode) {
                        _stopActive();
                      } else {
                        _onPlayPressed();
                      }
                    },
                    enabled: !isLoading,
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
                              value: micVolume,
                              onChanged: (v) => setState(() => micVolume = v),
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

              if ((playbackMode == 'playlist' || playbackMode == 'file') &&
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
                      // Previous button (only enabled for playlist)
                      Builder(
                        builder: (context) {
                          final prevDisabled =
                              playbackMode != 'playlist' ||
                              (currentSongIndex <= 1 && !isLoopEnabled) ||
                              isControlsCoolingDown;
                          return Opacity(
                            opacity: prevDisabled ? 0.3 : 1.0,
                            child: _buildCircularToggleButton(
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
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 32),

                      // Center button: pause/resume for playlist/file, stop for youtube
                      Opacity(
                        opacity: isControlsCoolingDown ? 0.3 : 1.0,
                        child: () {
                          // playlist or file -> pause/resume
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
                            enabled: !isControlsCoolingDown,
                          );
                        }(),
                      ),

                      const SizedBox(width: 32),

                      // Next button (only enabled for playlist)
                      Builder(
                        builder: (context) {
                          final nextDisabled =
                              playbackMode != 'playlist' ||
                              (currentSongIndex >= totalSongs &&
                                  !isLoopEnabled) ||
                              isControlsCoolingDown;
                          return Opacity(
                            opacity: nextDisabled ? 0.3 : 1.0,
                            child: _buildCircularToggleButton(
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
                            ),
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

        if ((playbackMode == 'playlist' && totalSongs > 0) ||
            (playbackMode == 'file' && currentSongTitle.isNotEmpty) ||
            (playbackMode == 'youtube'))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue[700]!.withOpacity(0.1),
                  Colors.blue[500]!.withOpacity(0.05),
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
                        playbackMode == 'youtube'
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
                      if (playbackMode == 'playlist')
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
