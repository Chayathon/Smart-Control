import 'package:flutter/material.dart';
import 'package:smart_control/core/alert/app_snackbar.dart';
import 'package:smart_control/core/color/app_colors.dart';
import 'package:smart_control/core/network/api_service.dart';
import 'package:smart_control/widgets/loading_overlay.dart';

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  List<dynamic> _playlist = [];
  List<dynamic> _library = [];

  void getSong() async {
    try {
      final api = await ApiService.private();
      var res = await api.get("/song");
      setState(() {
        _library = res['data'];
      });
    } catch (error) {
      print(error);
    }
  }

  void getPlaylist() async {
    try {
      final api = await ApiService.private();
      var res = await api.get('/playlist');

      final list = res['list'] as List;

      final idSongs = list.map((item) => item['id_song']).toList();

      setState(() {
        _playlist = idSongs;
      });
    } catch (error) {
      print(error);
    }
  }

  void savePlaylist() async {
    try {
      final mapPlaylist = _playlist.asMap().entries.map((entry) {
        final index = entry.key;
        final song = entry.value;
        return {"order": index + 1, "id_song": song["_id"]};
      }).toList();

      final api = await ApiService.private();
      final res = await api.post(
        "/playlist/save",
        data: {"songList": mapPlaylist},
      );

      LoadingOverlay.show(context);
      Future.delayed(Duration(seconds: 3), () {
        LoadingOverlay.hide();
        AppSnackbar.success("สำเร็จ", "บันทึก Playlist เรียบร้อยแล้ว");
      });
    } catch (error) {
      print("❌ Error savePlaylist: $error");
      AppSnackbar.error("ผิดพลาด", "ไม่สามารถบันทึก Playlist ได้");
    }
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      LoadingOverlay.show(context);
      Future.delayed(Duration(seconds: 3), () {
        getSong();
        getPlaylist();
        LoadingOverlay.hide();
      });
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _playlist.removeAt(oldIndex);
      _playlist.insert(newIndex, item);
    });
  }

  void _addSong() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (context, scrollController) {
            return ListView.builder(
              controller: scrollController,
              itemCount: _library.length,
              itemBuilder: (context, index) {
                final song = _library[index];
                return ListTile(
                  title: Text(song["name"]),
                  subtitle: Text(song["url"]),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.add_circle,
                      color: AppColors.primary,
                    ),
                    onPressed: () {
                      final exists = _playlist.any(
                        (s) => s["_id"] == song["_id"],
                      );
                      if (!exists) {
                        setState(() {
                          _playlist.add(song);
                        });
                        Navigator.pop(context);
                      } else {
                        AppSnackbar.info("แจ้งเตือน", "เพลงนี้ถูกเพิ่มแล้ว");
                      }
                    },
                  ),
                );
              },
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
                    "กดปุ่ม ➕ เพื่อเพิ่มเพลง",
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
          if (_playlist.isNotEmpty)
            FloatingActionButton.extended(
              onPressed: () {
                savePlaylist();
              },
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.save),
              label: const Text("บันทึก"),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          const SizedBox(width: 12),
          FloatingActionButton(
            onPressed: _addSong,
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
