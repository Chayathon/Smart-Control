import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:smart_control/core/alert/app_snackbar.dart';
import 'package:smart_control/core/network/api_exceptions.dart';
import 'package:smart_control/core/network/api_service.dart';
import 'package:smart_control/widgets/loading_overlay.dart';
import 'package:smart_control/widgets/song_upload/song_model.dart';

enum UploadSource { file, youtube }

class _SongUploadScreen extends StatefulWidget {
  const _SongUploadScreen({
    required this.source,
    required this.onSubmitFile,
    required this.onSubmitYoutube,
  });

  final UploadSource source;
  final void Function(String path, String filename, String displayName)
  onSubmitFile;
  final void Function(String url, String? name) onSubmitYoutube;

  @override
  State<_SongUploadScreen> createState() => _SongUploadScreenState();
}

class _SongUploadScreenState extends State<_SongUploadScreen> {
  final _nameCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  String? _fileName;
  String? _filePath;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.source == UploadSource.file
                    ? 'เพิ่มเพลงจากไฟล์'
                    : 'เพิ่มเพลงจาก YouTube',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),

              _TextFieldBox(controller: _nameCtrl, hint: 'ชื่อเพลง'),
              const SizedBox(height: 16),

              if (widget.source == UploadSource.file) ...[
                // โซนเลือกไฟล์
                GestureDetector(
                  onTap: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['mp3'],
                      allowMultiple: false,
                    );
                    if (!mounted) return;
                    if (result != null && result.files.isNotEmpty) {
                      final f = result.files.first;
                      setState(() {
                        _fileName = f.name;
                        _filePath = f.path;
                      });
                    }
                  },
                  child: _FileSelectBox(
                    label: _fileName ?? 'เลือกไฟล์เพลง (.mp3)',
                    hasFile: _fileName != null,
                    onClear: () => setState(() {
                      _fileName = null;
                      _filePath = null;
                    }),
                  ),
                ),
              ] else ...[
                // โซน URL
                _TextFieldBox(
                  controller: _urlCtrl,
                  hint: 'ลิงก์ YouTube',
                  textInputAction: TextInputAction.done,
                ),
              ],

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (widget.source == UploadSource.file) {
                      final okName = _nameCtrl.text.trim().isNotEmpty;
                      if (okName && _fileName != null && _filePath != null) {
                        Navigator.of(context).pop();
                        widget.onSubmitFile(
                          _filePath!,
                          _fileName!,
                          _nameCtrl.text.trim(),
                        );
                      }
                    } else {
                      if (_urlCtrl.text.trim().isNotEmpty) {
                        Navigator.of(context).pop();
                        widget.onSubmitYoutube(
                          _urlCtrl.text.trim(),
                          _nameCtrl.text.trim().isEmpty
                              ? null
                              : _nameCtrl.text.trim(),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text(
                    'เพิ่มเพลง',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextFieldBox extends StatelessWidget {
  const _TextFieldBox({
    required this.controller,
    required this.hint,
    this.textInputAction,
  });
  final TextEditingController controller;
  final String hint;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: textInputAction ?? TextInputAction.next,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      style: TextStyle(fontSize: 14),
    );
  }
}

class _FileSelectBox extends StatelessWidget {
  const _FileSelectBox({
    required this.label,
    required this.hasFile,
    required this.onClear,
  });
  final String label;
  final bool hasFile;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: hasFile ? FontWeight.bold : FontWeight.normal,
                color: hasFile ? Colors.black : Colors.grey[600],
              ),
            ),
          ),
          if (hasFile)
            IconButton(
              tooltip: 'ลบไฟล์ที่เลือก',
              onPressed: onClear,
              icon: const Icon(Icons.close),
            ),
        ],
      ),
    );
  }
}

class SongScreen extends StatefulWidget {
  const SongScreen({super.key});

  @override
  State<SongScreen> createState() => _SongScreenState();
}

class _SongScreenState extends State<SongScreen>
    with SingleTickerProviderStateMixin {
  List<Song> _songs = [];
  final _nameCtrl = TextEditingController();
  late final AnimationController _fabCtrl;
  late final Animation<double> _rotate;
  bool isLoading = false;
  bool _isDeletingSong = false;

  @override
  void initState() {
    super.initState();
    getSongList();

    _fabCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _rotate = Tween<double>(
      begin: 0,
      end: 0.25,
    ).animate(CurvedAnimation(parent: _fabCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _fabCtrl.dispose();
    super.dispose();
  }

  void _toggleFabMenu() {
    if (_fabCtrl.isDismissed) {
      _fabCtrl.forward();
    } else {
      _fabCtrl.reverse();
    }
  }

  void getSongList() async {
    try {
      final api = await ApiService.private();
      final result = await api.get("/song");

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

  Future<void> getSong(String id) async {
    try {
      final api = await ApiService.private();

      final result = await api.get("/song/$id");

      if (result['status'] == 'success' && result['data'] != null) {
        final song = Song.fromJson(result['data']);
        setState(() {
          _nameCtrl.text = song.name;
        });
      }
    } catch (error) {
      print(error);
    }
  }

  String _normalizeYouTubeUrl(String raw) {
    final text = raw.trim();
    final short = RegExp(r'^https?:\/\/youtu\.be\/([A-Za-z0-9_-]{6,})');
    final m = short.firstMatch(text);
    if (m != null) {
      return 'https://www.youtube.com/watch?v=${m.group(1)!}';
    }
    return text;
  }

  bool _looksLikeYouTubeUrl(String url) {
    final u = url.toLowerCase();
    return u.contains('youtube.com/watch') || u.contains('youtu.be/');
  }

  Future<void> uploadSongFile(
    String filePath,
    String fileName,
    String name,
  ) async {
    final normalizedFileName = fileName.toLowerCase().endsWith('.mp3')
        ? fileName
        : '$fileName.mp3';

    try {
      LoadingOverlay.show(context);

      final formData = FormData.fromMap({
        'filename': name,
        'song': await MultipartFile.fromFile(
          filePath,
          filename: normalizedFileName,
          contentType: MediaType('audio', 'mpeg'),
        ),
      });

      final api = await ApiService.private();
      final res = await api.post<Map<String, dynamic>>(
        "/song/uploadSongFile",
        data: formData,
      );

      if (res['status'] == 'success') {
        AppSnackbar.success("สำเร็จ", "อัปโหลดสำเร็จ");
        getSongList();
        return;
      }
    } on DioException catch (e) {
      final msg = e.response?.data is Map<String, dynamic>
          ? (e.response!.data['message']?.toString() ?? 'อัปโหลดล้มเหลว')
          : 'อัปโหลดล้มเหลว';
      AppSnackbar.error("ล้มเหลว", msg);
    } catch (error) {
      AppSnackbar.error("ล้มเหลว", "อัปโหลดล้มเหลว");
    } finally {
      LoadingOverlay.hide();
    }
  }

  Future<void> uploadSongYouTube({
    required String youtubeUrl,
    String? name,
  }) async {
    try {
      final normalizedUrl = _normalizeYouTubeUrl(youtubeUrl);

      if (!_looksLikeYouTubeUrl(normalizedUrl)) {
        AppSnackbar.error("ล้มเหลว", "URL ไม่ใช่ลิงก์ YouTube ที่รองรับ");
        return;
      }

      LoadingOverlay.show(context);

      final api = await ApiService.private();
      final payload = {
        "url": normalizedUrl,
        if (name != null && name.trim().isNotEmpty) "filename": name.trim(),
      };

      final res = await api.post<Map<String, dynamic>>(
        "/song/uploadSongYT",
        data: payload,
        options: Options(
          sendTimeout: const Duration(minutes: 1),
          receiveTimeout: const Duration(minutes: 6),
        ),
      );

      final status = res['status']?.toString().toLowerCase();

      if (status == 'success') {
        AppSnackbar.success("สำเร็จ", "เพิ่มเพลงจาก YouTube สำเร็จ");
      }

      try {
        getSongList();
      } catch (_) {}
    } on DioException catch (e) {
      // ถ้าเป็น timeout หรือ 504 (เกทเวย์ timeout) มักหมายถึงฝั่งเซิร์ฟเวอร์ยังประมวลผลต่อและ “สำเร็จจริง”
      final code = e.response?.statusCode;
      final isTimeout =
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionTimeout ||
          code == 504;

      if (isTimeout) {
        AppSnackbar.success(
          "สำเร็จ",
          "เพิ่มเพลงจาก YouTube สำเร็จ (กำลังประมวลผลบนเซิร์ฟเวอร์)",
        );
        try {
          getSongList();
        } catch (_) {}
        return;
      }

      final msg = e.response?.data is Map<String, dynamic>
          ? (e.response!.data['message']?.toString() ?? 'อัปโหลดล้มเหลว')
          : 'อัปโหลดล้มเหลว';
      AppSnackbar.error("ล้มเหลว", msg);
    } catch (_) {
      AppSnackbar.error("ล้มเหลว", "อัปโหลดล้มเหลว");
    } finally {
      LoadingOverlay.hide();
    }
  }

  Future<void> editSong(String id, String newName) async {
    try {
      LoadingOverlay.show(context);

      final api = await ApiService.private();

      final res = await api.patch(
        "/song/update/$id",
        data: {'newName': newName},
      );

      if (res['status'] == 'success' && res['data']['name'] == newName) {
        AppSnackbar.success("สำเร็จ", "แก้ไขชื่อเพลงสำเร็จ");
        getSongList();
        return;
      }
    } on ApiException catch (e) {
      AppSnackbar.error("ล้มเหลว", e.message);
    } finally {
      LoadingOverlay.hide();
    }
  }

  Future<void> deleteSong(String id) async {
    if (_isDeletingSong) return;
    _isDeletingSong = true;

    try {
      if (context.mounted) LoadingOverlay.show(context);

      final api = await ApiService.private();
      final res = await api.delete<Map<String, dynamic>>('/song/remove/$id');

      if (res['status'] == 'success') {
        AppSnackbar.success('สำเร็จ', 'ลบเพลงสำเร็จแล้ว');
        getSongList();
        return;
      }
    } on ApiException catch (e) {
      AppSnackbar.error('ล้มเหลว', e.message);
    } finally {
      if (context.mounted) LoadingOverlay.hide();
      _isDeletingSong = false;
    }
  }

  Future<void> showAddSongDialog(UploadSource source) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SongUploadScreen(
        source: source,
        onSubmitFile: (path, filename, display) =>
            uploadSongFile(path, filename, display),
        onSubmitYoutube: (url, name) =>
            uploadSongYouTube(youtubeUrl: url, name: name),
      ),
    );
  }

  Future<void> showAddSongFileDialog() => showAddSongDialog(UploadSource.file);
  Future<void> showAddSongYoutubeDialog() =>
      showAddSongDialog(UploadSource.youtube);

  // void playSong(int index) async {
  //   final api = await ApiService.public();
  //   await api.get("/stream/startFile?path=uploads/${_songs[index].url}");

  //   AppSnackbar.success("แจ้งเตือน", "กำลังเล่นเพลง ${_songs[index].name}");
  // }

  Future<void> _editDialog(String id) async {
    await getSong(id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "แก้ไขชื่อเพลง",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _TextFieldBox(
                            controller: _nameCtrl,
                            hint: "ชื่อเพลง",
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              editSong(id, _nameCtrl.text);
                              Navigator.pop(context);
                            },
                            label: const Text(
                              "บักทึก",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            icon: const Icon(Icons.save_outlined),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.blue,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadiusGeometry.all(
                                  Radius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _deleteDialog(String id, String name) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("ยืนยันการลบ"),
          content: Text("ยืนยันที่จะลบเพลง \"${name}\" ?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(Colors.grey[200]),
              ),
              child: Text("ยกเลิก", style: TextStyle(color: Colors.grey[600])),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                deleteSong(id);
              },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(Colors.red[50]),
              ),
              child: Text(
                "ยืนยัน",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_off_rounded, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    "ยังไม่มีเพลง",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "กดปุ่ม ➕ เพื่ออัปโหลดเพลง",
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
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
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _editDialog(song.id.toString()),
                          icon: Icon(Icons.edit, color: Colors.amber),
                        ),
                        IconButton(
                          onPressed: () =>
                              _deleteDialog(song.id.toString(), song.name),
                          icon: const Icon(Icons.delete, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: SizedBox(
        width: 200,
        height: 200,
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            // ปุ่มย่อย #1
            AnimatedBuilder(
              animation: _fabCtrl,
              builder: (_, __) {
                final offset = Offset(0, -76) * _fabCtrl.value;
                return Transform.translate(
                  offset: offset,
                  child: FadeTransition(
                    opacity: _fabCtrl,
                    child: ScaleTransition(
                      scale: _fabCtrl,
                      child: IgnorePointer(
                        ignoring: _fabCtrl.isDismissed,
                        child: FloatingActionButton.small(
                          heroTag: 'fab_child_1',
                          onPressed: () {
                            _toggleFabMenu();
                            showAddSongFileDialog();
                          },
                          tooltip: 'แนบไฟล์',
                          child: const Icon(Icons.library_music),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // ปุ่มย่อย #2
            AnimatedBuilder(
              animation: _fabCtrl,
              builder: (_, __) {
                final offset = Offset(0, -140) * _fabCtrl.value;
                return Transform.translate(
                  offset: offset,
                  child: FadeTransition(
                    opacity: _fabCtrl,
                    child: ScaleTransition(
                      scale: _fabCtrl,
                      child: IgnorePointer(
                        ignoring: _fabCtrl.isDismissed,
                        child: FloatingActionButton.small(
                          heroTag: 'fab_child_2',
                          onPressed: () {
                            _toggleFabMenu();
                            showAddSongYoutubeDialog();
                          },
                          tooltip: 'แนบลิงก์',
                          child: const Icon(Icons.link),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // ปุ่มหลัก
            AnimatedBuilder(
              animation: _rotate,
              builder: (context, child) =>
                  Transform.rotate(angle: _rotate.value, child: child),
              child: FloatingActionButton(
                heroTag: 'fab_main',
                onPressed: _toggleFabMenu,
                backgroundColor: Colors.blue,
                child: const Icon(Icons.add, size: 28, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
