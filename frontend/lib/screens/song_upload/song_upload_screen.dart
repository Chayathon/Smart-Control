import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:smart_control/core/alert/app_snackbar.dart';
import 'package:smart_control/core/network/api_service.dart';
import 'package:smart_control/widgets/loading_overlay.dart';
import 'package:smart_control/widgets/song_upload/song_item.dart';
import 'package:smart_control/widgets/song_upload/song_model.dart';
import 'package:toastification/toastification.dart';

class SongUploadScreen extends StatefulWidget {
  const SongUploadScreen({super.key});

  @override
  State<SongUploadScreen> createState() => _SongUploadScreenState();
}

class _SongUploadScreenState extends State<SongUploadScreen>
    with SingleTickerProviderStateMixin {
  List<Song> _songs = [];
  late AnimationController _fabController;
  late Animation<double> _fabAnimation;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();

    getSongList();

    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat();

    _fabAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.1), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.1, end: 0.1), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.1, end: -0.05), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.05, end: 0.05), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.05, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _fabController, curve: Curves.linear));
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  void getSongList() async {
    try {
      final api = await ApiService.private();
      final result = await api.get("/song/");

      LoadingOverlay.show(context);

      Future.delayed(Duration(milliseconds: 100), () {
        LoadingOverlay.hide();
        setState(() {
          _songs = (result["data"] as List)
              .map((item) => Song.fromJson(item))
              .toList();
        });
      });
    } catch (error) {
      print(error);
    }
  }

  Future<void> uploadSong(String filePath, String fileName, String name) async {
    try {
      LoadingOverlay.show(context);

      FormData formData = FormData.fromMap({
        'filename': name,
        'song': await MultipartFile.fromFile(
          filePath,
          filename: fileName,
          contentType: DioMediaType('audio', 'mpeg'),
        ),
      });

      final api = await ApiService.public();
      await api.post<Map<String, dynamic>>(
        "/song/uploadSongFile",
        data: formData,
        options: Options(headers: {"Content-Type": "multipart/form-data"}),
      );

      LoadingOverlay.hide();

      getSongList();
      AppSnackbar.success("แจ้งเตือน", "อัปโหลดสำเร็จ");
    } catch (error) {
      AppSnackbar.error("แจ้งเตือน", "อัปโหลดล้มเหลว");
    }
  }

  void playSong(int index) async {
    final api = await ApiService.public();
    await api.get("/stream/startFile?path=uploads/${_songs[index].url}");

    AppSnackbar.success("แจ้งเตือน", "กำลังเล่นเพลง ${_songs[index].name}");
  }

  void deleteSong(String id) async {
    LoadingOverlay.show(context);
    final api = await ApiService.public();
    await api.delete("/song/remove/${id}");

    Future.delayed(Duration(seconds: 3), () {
      LoadingOverlay.hide();
      AppSnackbar.success("แจ้งเตือน", "ลบเพลงสำเร็จแล้ว");
    });

    getSongList();
  }

  void _showDeleteConfirmDialog(BuildContext context, song) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.white,
        title: Text(
          "แจ้งเตือน",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: Text(
          "คุณยืนยันที่จะลบเพลง ${song.name} นี้ไหม?",
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("ยกเลิก", style: TextStyle(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              deleteSong(song.id);
            },
            child: Text("ลบ", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> showAddSongModal() async {
    final TextEditingController nameController = TextEditingController();
    String? selectedFileName;
    String? selectedFilePath;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'เพิ่มเพลงใหม่',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: 'ชื่อเพลง',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () async {
                  FilePickerResult? result = await FilePicker.platform
                      .pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['mp3'],
                        allowMultiple: false,
                      );
                  if (result != null && result.files.isNotEmpty) {
                    setState(() {
                      selectedFileName = result.files.first.name;
                      selectedFilePath = result.files.first.path;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.upload_file, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          selectedFileName ?? 'เลือกไฟล์เพลง',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.isNotEmpty &&
                      selectedFileName != null &&
                      selectedFilePath != null) {
                    Navigator.of(context).pop();
                    uploadSong(
                      selectedFilePath!,
                      selectedFileName!,
                      nameController.text,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('เพิ่มเพลง'),
              ),
            ],
          ),
        );
      },
    );
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
      body: _songs.isEmpty
          ? const Center(
              child: Text(
                "ยังไม่มีเพลง",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _songs.length,
              itemBuilder: (context, index) {
                final song = _songs[index];

                return Card(
                  color: Colors.grey[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.music_note, color: Colors.blue),
                    ),
                    title: Text(
                      song.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      song.url,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    // trailing: IconButton(
                    //   icon: const Icon(Icons.play_arrow, color: Colors.blue),
                    //   onPressed: () => playSong(index),
                    // ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _showDeleteConfirmDialog(context, song),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: AnimatedBuilder(
        animation: _fabAnimation,
        builder: (context, child) {
          return Transform.rotate(angle: _fabAnimation.value, child: child);
        },
        child: FloatingActionButton(
          onPressed: showAddSongModal,
          backgroundColor: Colors.blue,
          child: const Icon(Icons.add, size: 28, color: Colors.white),
        ),
      ),
    );
  }
}
