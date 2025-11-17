import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:smart_control/core/network/api_service.dart';
import 'package:smart_control/core/services/StreamStatusService.dart';

class PlaylistState {
  final bool active; // Playlist mode is active (playing or paused)
  final bool isPlaying; // Currently playing (not paused)
  final bool isPaused; // Paused state
  final bool isLoop; // Loop enabled
  final bool isLoading; // Start/stop in progress
  final String title; // Current song title
  final int index; // 1-based index of current song
  final int total; // total songs
  final DateTime? controlsCooldownUntil; // when controls become available again
  final List<dynamic> playlist; // Current playlist songs
  final List<dynamic> library; // All available songs

  const PlaylistState({
    this.active = false,
    this.isPlaying = false,
    this.isPaused = false,
    this.isLoop = false,
    this.isLoading = false,
    this.title = '',
    this.index = 0,
    this.total = 0,
    this.controlsCooldownUntil,
    this.playlist = const [],
    this.library = const [],
  });

  bool get isControlsCoolingDown =>
      controlsCooldownUntil != null &&
      DateTime.now().isBefore(controlsCooldownUntil!);

  PlaylistState copyWith({
    bool? active,
    bool? isPlaying,
    bool? isPaused,
    bool? isLoop,
    bool? isLoading,
    String? title,
    int? index,
    int? total,
    DateTime? controlsCooldownUntil,
    bool applyNullCooldown = false,
    List<dynamic>? playlist,
    List<dynamic>? library,
  }) {
    return PlaylistState(
      active: active ?? this.active,
      isPlaying: isPlaying ?? this.isPlaying,
      isPaused: isPaused ?? this.isPaused,
      isLoop: isLoop ?? this.isLoop,
      isLoading: isLoading ?? this.isLoading,
      title: title ?? this.title,
      index: index ?? this.index,
      total: total ?? this.total,
      controlsCooldownUntil: applyNullCooldown
          ? null
          : (controlsCooldownUntil ?? this.controlsCooldownUntil),
      playlist: playlist ?? this.playlist,
      library: library ?? this.library,
    );
  }
}

class PlaylistService with ChangeNotifier {
  PlaylistService._internal();
  static final PlaylistService instance = PlaylistService._internal();

  final ValueNotifier<PlaylistState> state = ValueNotifier<PlaylistState>(
    const PlaylistState(),
  );

  final StreamStatusService _sse = StreamStatusService();
  bool _sseConnected = false;

  // Prevent duplicate stop requests when playlist naturally ends
  bool _autoStopScheduled = false;

  Timer? _controlsCooldownTimer;
  DateTime? _lastButtonPress;

  // Call this once (e.g., on app start or first screen needing playlist)
  void ensureInitialized() {
    if (_sseConnected) return;
    _sseConnected = true;

    _sse.onStatusUpdate = (data) {
      final event = data['event'];
      final isPlaying = data['isPlaying'] ?? false;
      final mode = data['mode'] ?? 'single';
      final pausedState = data['isPaused'] ?? false;
      final loopState = data['loop'] ?? false;

      if (mode == 'playlist') {
        final idx = (data['index'] ?? 0) + 1;
        final tot = data['total'] ?? 0;

        String title = state.value.title;
        if (data['title'] != null) {
          title = data['title'];
        } else if (data['extra'] != null && data['extra']['title'] != null) {
          title = data['extra']['title'];
        }

        state.value = state.value.copyWith(
          active: true,
          isPlaying: isPlaying,
          isPaused: pausedState,
          isLoop: loopState,
          index: idx,
          total: tot,
          title: title,
          isLoading:
              (event == 'started' ||
                  event == 'stopped' ||
                  event == 'playlist-stopped')
              ? false
              : state.value.isLoading,
        );
      }

      // When playlist finishes all songs and loop is off, request stop
      if (event == 'playlist-ended') {
        // Reset active flag since backend sets mode back to single
        state.value = state.value.copyWith(active: false);

        if (!loopState && !_autoStopScheduled) {
          _autoStopScheduled = true;
          // Fire and forget; SSE will emit 'playlist-stopped' afterwards
          stop().catchError((_) {});
        }
      }

      // Reset guard when a new playlist session starts
      if (event == 'playlist-started') {
        _autoStopScheduled = false;
      }

      if (event == 'playlist-stopped') {
        state.value = const PlaylistState();
        _autoStopScheduled = false;
      }
    };

    _sse.connect();

    // On init, fetch current status to sync
    checkStatus();
  }

  Future<void> start() async {
    if (state.value.isLoading) return;
    state.value = state.value.copyWith(isLoading: true);
    try {
      final api = await ApiService.private();
      await api.get('/stream/start-playlist');
      // Wait for SSE to update playing state
    } catch (e) {
      state.value = state.value.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> stop() async {
    if (state.value.isLoading) return;
    state.value = state.value.copyWith(isLoading: true);
    try {
      final api = await ApiService.private();
      await api.get('/stream/stop');
      // reset will be handled by SSE; fallback in case SSE missing
      // state.value = const PlaylistState();
    } catch (e) {
      state.value = state.value.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> togglePlayStop() async {
    if (state.value.isPlaying || state.value.isPaused) {
      await stop();
    } else {
      await start();
    }
  }

  Future<void> togglePauseResume() async {
    // Allow both when playing or paused
    if (!(state.value.isPlaying || state.value.isPaused)) return;
    if (state.value.isControlsCoolingDown) return;

    _startControlsCooldown();
    final api = await ApiService.private();
    if (state.value.isPaused) {
      await api.get('/stream/resume');
      state.value = state.value.copyWith(isPaused: false);
    } else {
      await api.get('/stream/pause');
      state.value = state.value.copyWith(isPaused: true);
    }
  }

  Future<void> next() async {
    if (!(state.value.isPlaying || state.value.isPaused)) return;
    if (state.value.isControlsCoolingDown) return;

    // Edge guard if no loop and at last song
    if (state.value.index >= state.value.total && !state.value.isLoop) {
      return;
    }

    // Debounce rapid taps (500ms)
    final now = DateTime.now();
    if (_lastButtonPress != null &&
        now.difference(_lastButtonPress!).inMilliseconds < 500) {
      return;
    }
    _lastButtonPress = now;
    _startControlsCooldown();

    try {
      final api = await ApiService.private();
      await api.get('/stream/next-track');
    } catch (_) {}
  }

  Future<void> prev() async {
    if (!(state.value.isPlaying || state.value.isPaused)) return;
    if (state.value.isControlsCoolingDown) return;

    // Edge guard if no loop and at first song
    if (state.value.index <= 1 && !state.value.isLoop) {
      return;
    }

    // Debounce rapid taps (500ms)
    final now = DateTime.now();
    if (_lastButtonPress != null &&
        now.difference(_lastButtonPress!).inMilliseconds < 500) {
      return;
    }
    _lastButtonPress = now;
    _startControlsCooldown();

    try {
      final api = await ApiService.private();
      await api.get('/stream/prev-track');
    } catch (_) {}
  }

  Future<void> checkStatus() async {
    try {
      final api = await ApiService.private();
      final response = await api.get('/playlist/status');

      final isPlaying = response['isPlaying'] ?? false;
      final playlistMode = response['playlistMode'] ?? false;
      final pausedState = response['isPaused'] ?? false;
      final loopState = response['loop'] ?? false;

      if (playlistMode && (isPlaying || pausedState)) {
        final currentSong = response['currentSong'];
        state.value = state.value.copyWith(
          active: true,
          isPlaying: isPlaying,
          isPaused: pausedState,
          isLoop: loopState,
          total: response['totalSongs'] ?? 0,
          title: (currentSong != null ? (currentSong['title'] ?? '') : ''),
          index: (currentSong != null ? ((currentSong['index'] ?? 0) + 1) : 0),
        );
      } else {
        state.value = state.value.copyWith(active: false);
      }
    } catch (_) {
      // ignore
    }
  }

  void _startControlsCooldown() {
    _controlsCooldownTimer?.cancel();
    final until = DateTime.now().add(const Duration(seconds: 8));
    state.value = state.value.copyWith(controlsCooldownUntil: until);
    final delay = until.difference(DateTime.now());
    _controlsCooldownTimer = Timer(delay, () {
      state.value = state.value.copyWith(applyNullCooldown: true);
    });
  }

  // Fetch all songs from library
  Future<List<dynamic>> getSongs() async {
    final api = await ApiService.private();
    final result = await api.get("/song");
    return (result['data'] as List<dynamic>?) ?? [];
  }

  // Fetch current playlist
  Future<List<dynamic>> getPlaylist() async {
    final api = await ApiService.private();
    final result = await api.get('/playlist');
    final list = (result['list'] as List<dynamic>?) ?? [];
    return list.map((item) => item['id_song']).toList();
  }

  // Save playlist to backend
  Future<void> savePlaylist(List<dynamic> playlist) async {
    final mapPlaylist = playlist.asMap().entries.map((entry) {
      final index = entry.key;
      final song = entry.value;
      return {"order": index + 1, "id_song": song["_id"]};
    }).toList();

    final api = await ApiService.private();
    await api.post("/playlist/save", data: {"songList": mapPlaylist});
  }

  @override
  void dispose() {
    _controlsCooldownTimer?.cancel();
    super.dispose();
  }
}
