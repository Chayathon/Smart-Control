import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:smart_control/core/network/api_service.dart';
import 'package:smart_control/widgets/song_upload/song_item.dart';
import 'package:smart_control/widgets/song_upload/song_model.dart';
import 'package:toastification/toastification.dart';

class SongUploadScreen extends StatefulWidget {
  const SongUploadScreen({super.key});

  @override
  State<SongUploadScreen> createState() => _SongUploadScreenState();
}

class _SongUploadScreenState extends State<SongUploadScreen> {
  List<Song> _songs = [];

  @override
  void initState() {
    super.initState();
    getSongList();
  }

  void getSongList() async {
    try {
      final api = ApiService.public();
      final result = await api.get("/stream/getSongList");
      setState(() {
        _songs = (result["data"] as List)
            .map((item) => Song.fromJson(item))
            .toList();
      });
    } catch (error) {
      print(error);
    }
  }

  void removeSong(int index) {
    setState(() {
      _songs.removeAt(index);
    });
  }

  Future<void> uploadSong(String filePath, String fileName) async {
    try {
      FormData formData = FormData.fromMap({
        'filename': fileName.replaceAll('.mp3', ''),
        'song': await MultipartFile.fromFile(
          filePath,
          filename: fileName,
          contentType: DioMediaType('audio', 'mpeg'),
        ),
      });

      final api = ApiService.public();
      final res = await api.post<Map<String, dynamic>>(
        "/stream/uploadSongFile",
        data: formData,
        options: Options(headers: {"Content-Type": "multipart/form-data"}),
      );

      getSongList();
      print("✅ อัปโหลดสำเร็จ: ${res['file']}");
    } catch (error) {
      print("❌ อัปโหลดล้มเหลว: $error");
    }
  }

  void playSong(int index) async {
    final api = ApiService.public();
    await api.get("/stream/startFile?path=uploads/${_songs[index].url}");

    toastification.show(
      context: context,
      type: ToastificationType.success,
      style: ToastificationStyle.minimal,
      title: const Text('สำเร็จ'),
      description: Text('กำลังเล่นเพลง ${_songs[index].name}'),
      autoCloseDuration: const Duration(seconds: 3),
      alignment: Alignment.topRight,
      showProgressBar: true,
    );
  }

  Future<void> showAddSongModal() async {
    final TextEditingController nameController = TextEditingController();
    String? selectedFileName;
    String? selectedFilePath;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'เพิ่มเพลงใหม่',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: 'ชื่อเพลง',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
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
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('ยกเลิก'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        if (nameController.text.isNotEmpty &&
                            selectedFileName != null &&
                            selectedFilePath != null) {
                          Navigator.of(context).pop();
                          uploadSong(selectedFilePath!, selectedFileName!);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('เพิ่ม'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "อัปโหลดเพลง",
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      backgroundColor: Colors.white,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FloatingActionButton(
            heroTag: "btnAddSong",
            onPressed: showAddSongModal,
            backgroundColor: Colors.grey[200],
            elevation: 0,
            child: Icon(Icons.add_circle_outline, color: Colors.grey[800]),
          ),
          const SizedBox(width: 16),
          FloatingActionButton.extended(
            heroTag: "btnPlaylist",
            onPressed: () {},
            backgroundColor: Colors.grey[200],
            elevation: 0,
            label: Row(
              children: [
                Icon(Icons.playlist_add, color: Colors.grey[800]),
                const SizedBox(width: 8),
                const Text("จัด Playlist"),
              ],
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: _songs.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.music_note_outlined, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(
                      "ไม่มีเพลงในรายการ",
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: _songs.length,
                itemBuilder: (context, index) {
                  return SongItem(
                    song: _songs[index],
                    onPlay: () => playSong(index),
                    onDelete: () => removeSong(index),
                  );
                },
              ),
      ),
    );
  }
}
