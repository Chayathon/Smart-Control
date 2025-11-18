import 'package:flutter/material.dart';
import 'package:smart_control/core/alert/app_snackbar.dart';
import 'package:smart_control/core/color/app_colors.dart';
import 'package:smart_control/widgets/loading_overlay.dart';
import 'package:smart_control/services/playlist_service.dart';
import 'package:smart_control/widgets/modals/modal_bottom_sheet.dart';

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  final _playlistService = PlaylistService.instance;
  List<dynamic> _playlist = [];
  List<dynamic> _originalPlaylist = [];
  List<dynamic> _library = [];
  bool _libraryLoaded = false;

  void _loadPlaylist() async {
    LoadingOverlay.show(context);
    try {
      final playlist = await _playlistService.getPlaylist();
      setState(() {
        _playlist = playlist;
        _originalPlaylist = List.from(playlist);
      });
    } catch (error) {
      print(error);
      AppSnackbar.error(
        "ล้มเหลว",
        "เกิดข้อผิดพลาดในการโหลดรายการเพลง กรุณาลองใหม่อีกครั้ง",
      );
    } finally {
      LoadingOverlay.hide();
    }
  }

  Future<void> _loadSongs() async {
    LoadingOverlay.show(context);
    try {
      final songs = await _playlistService.getSongs();
      setState(() {
        _library = songs;
        _libraryLoaded = true;
      });
    } catch (error) {
      print(error);
      AppSnackbar.error(
        "ล้มเหลว",
        "เกิดข้อผิดพลาดในการโหลดข้อมูลเพลง กรุณาลองใหม่อีกครั้ง",
      );
    } finally {
      LoadingOverlay.hide();
    }
  }

  void _savePlaylist() async {
    LoadingOverlay.show(context);
    try {
      await _playlistService.savePlaylist(_playlist);
      setState(() {
        _originalPlaylist = List.from(_playlist);
      });
      AppSnackbar.success("สำเร็จ", "บันทึกรายการเพลงเรียบร้อยแล้ว");
    } catch (error) {
      print("❌ Error savePlaylist: $error");
      AppSnackbar.error(
        "ล้มเหลว",
        "เกิดข้อผิดพลาดในการบันทึกรายการเพลง กรุณาลองใหม่อีกครั้ง",
      );
    } finally {
      LoadingOverlay.hide();
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _playlist.removeAt(oldIndex);
      _playlist.insert(newIndex, item);
    });
  }

  Future<void> _showAddSongDialog() async {
    if (!_libraryLoaded) {
      await _loadSongs();
    }

    ModalBottomSheet.showDraggable(
      context: context,
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      showSearch: true,
      searchHint: 'ค้นหาชื่อเพลง...',
      title: 'เลือกเพลง',
      builder: (context, scrollController, searchQuery) {
        // Filter songs based on search query
        final filteredSongs = searchQuery.isEmpty
            ? _library
            : _library.where((song) {
                final name = song["name"].toString().toLowerCase();
                final url = song["url"].toString().toLowerCase();
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
                  'ไม่พบเพลงที่ค้นหา',
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
            final isInPlaylist = _playlist.any((s) => s["_id"] == song["_id"]);

            return ListTile(
              leading: Icon(
                Icons.music_note,
                color: isInPlaylist ? Colors.grey : AppColors.primary,
              ),
              title: Text(
                song["name"],
                style: TextStyle(
                  color: isInPlaylist ? Colors.grey : Colors.black,
                ),
              ),
              subtitle: Text(
                song["url"],
                style: TextStyle(
                  color: isInPlaylist ? Colors.grey : Colors.black54,
                ),
              ),
              trailing: IconButton(
                icon: Icon(
                  isInPlaylist ? Icons.check_circle : Icons.add_circle,
                  color: isInPlaylist ? Colors.grey : AppColors.primary,
                ),
                onPressed: isInPlaylist
                    ? null
                    : () {
                        setState(() {
                          _playlist.add(song);
                        });
                        Navigator.pop(context);
                      },
              ),
            );
          },
        );
      },
    );
  }

  void _removeSong(int index) {
    setState(() {
      _playlist.removeAt(index);
    });
  }

  bool _hasChanges() {
    // เช็คความยาวก่อน
    if (_playlist.length != _originalPlaylist.length) return true;

    // เช็คแต่ละ item ว่าเหมือนกันหรือไม่
    for (int i = 0; i < _playlist.length; i++) {
      if (_playlist[i]["_id"] != _originalPlaylist[i]["_id"]) {
        return true;
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _playlistService.ensureInitialized();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPlaylist();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          "เพลงของฉัน",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _playlist.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_off_rounded, color: Colors.grey, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    "ยังไม่มีเพลงใน Playlist",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "กดปุ่ม ➕ เพื่อเพิ่มเพลงในรายการ",
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            )
          : ReorderableListView.builder(
              itemCount: _playlist.length,
              onReorder: _onReorder,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (context, index) {
                final song = _playlist[index];
                return Card(
                  color: Colors.white,
                  key: ValueKey(song["_id"]),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      child: Text("${index + 1}"),
                    ),
                    title: Text(
                      song["name"],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(song["url"]),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeSong(index),
                        ),
                        const Icon(Icons.drag_handle, color: Colors.grey),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_playlist.isNotEmpty && _hasChanges())
            FloatingActionButton.extended(
              onPressed: _savePlaylist,
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.save_outlined),
              label: const Text("บันทึก"),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          const SizedBox(width: 12),
          FloatingActionButton(
            onPressed: _showAddSongDialog,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            tooltip: "เพิ่มเพลงใหม่",
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.add, size: 28),
          ),
        ],
      ),
    );
  }
}
