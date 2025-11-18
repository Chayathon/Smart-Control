import 'package:flutter/material.dart';
import 'package:smart_control/core/alert/app_snackbar.dart';
import 'package:smart_control/core/network/api_exceptions.dart';
import 'package:smart_control/services/song_service.dart';
import 'package:smart_control/widgets/song_upload/song_model.dart';
import 'package:smart_control/widgets/inputs/text_field_box.dart';
import 'package:smart_control/widgets/inputs/file_field_box.dart';
import 'package:smart_control/widgets/loading_overlay.dart';
import 'package:smart_control/widgets/buttons/action_button.dart';
import 'package:smart_control/widgets/dialogs/alert_dialog.dart';
import 'package:smart_control/widgets/modals/modal_bottom_sheet.dart';

enum UploadSource { file, youtube }

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

  @override
  void initState() {
    super.initState();

    _fabCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _rotate = Tween<double>(
      begin: 0,
      end: 0.25,
    ).animate(CurvedAnimation(parent: _fabCtrl, curve: Curves.easeOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSongs();
    });
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

  void _loadSongs() async {
    LoadingOverlay.show(context);
    try {
      final songs = await SongService.getSongs();

      setState(() {
        _songs = songs;
      });
    } catch (error) {
      print('Error loading songs: $error');
      AppSnackbar.error(
        "ล้มเหลว",
        "เกิดข้อผิดพลาดในการโหลดเพลง กรุณาลองใหม่อีกครั้ง",
      );
    } finally {
      LoadingOverlay.hide();
    }
  }

  Future<void> _loadSong(String id) async {
    try {
      final song = await SongService.getSongById(id);
      setState(() {
        _nameCtrl.text = song.name;
      });
    } catch (error) {
      print(error);
      AppSnackbar.error(
        "ล้มเหลว",
        "เกิดข้อผิดพลาดในการโหลดข้อมูลเพลง กรุณาลองใหม่อีกครั้ง",
      );
    }
  }

  Future<void> _uploadSongFile(
    String filePath,
    String fileName,
    String name,
  ) async {
    try {
      LoadingOverlay.show(context);

      final res = await SongService.uploadSongFile(
        filePath: filePath,
        fileName: fileName,
        displayName: name,
      );

      if (res['ok'] == true) {
        AppSnackbar.success("สำเร็จ", "อัปโหลดเพลงสำเร็จ");
        _loadSongs();
        return;
      }
    } on ApiException catch (error) {
      AppSnackbar.error("ล้มเหลว", error.message);
    } catch (_) {
      AppSnackbar.error(
        "ล้มเหลว",
        "เกิดข้อผิดพลาดในการอัปโหลดเพลง กรุณาลองใหม่อีกครั้ง",
      );
    } finally {
      LoadingOverlay.hide();
    }
  }

  Future<void> _uploadSongYouTube({
    required String youtubeUrl,
    String? name,
  }) async {
    try {
      LoadingOverlay.show(context);

      final res = await SongService.uploadSongYouTube(
        youtubeUrl: youtubeUrl,
        name: name,
      );

      if (res['ok'] == true) {
        AppSnackbar.success("สำเร็จ", "อัปโหลดเพลงสำเร็จ");
        _loadSongs();
        return;
      }
    } on ApiException catch (error) {
      AppSnackbar.error("ล้มเหลว", error.message);
    } catch (error) {
      if (error.toString().contains('YouTube')) {
        AppSnackbar.error(
          "ล้มเหลว",
          error.toString().replaceAll('Exception: ', ''),
        );
      } else {
        AppSnackbar.error(
          "ล้มเหลว",
          "เกิดข้อผิดพลาดในการอัปโหลดเพลง กรุณาลองใหม่อีกครั้ง",
        );
      }
    } finally {
      LoadingOverlay.hide();
    }
  }

  Future<void> _editSong(String id, String newName) async {
    LoadingOverlay.show(context);
    try {
      final res = await SongService.updateSong(id, newName);

      if (res['ok'] == true && res['data']['name'] == newName) {
        AppSnackbar.success("สำเร็จ", "แก้ไขชื่อเพลงสำเร็จ");
        _loadSongs();
        return;
      }
    } on ApiException catch (e) {
      AppSnackbar.error("ล้มเหลว", e.message);
    } catch (_) {
      AppSnackbar.error(
        "ล้มเหลว",
        "เกิดข้อผิดพลาดในการแก้ไขชื่อเพลง กรุณาลองใหม่อีกครั้ง",
      );
    } finally {
      LoadingOverlay.hide();
    }
  }

  Future<void> _deleteSong(String id) async {
    try {
      if (context.mounted) LoadingOverlay.show(context);

      final res = await SongService.deleteSong(id);

      if (res['ok'] == true) {
        AppSnackbar.success('สำเร็จ', 'ลบเพลงสำเร็จแล้ว');
        _loadSongs();
        return;
      }
    } on ApiException catch (e) {
      AppSnackbar.error('ล้มเหลว', e.message);
    } catch (_) {
      AppSnackbar.error(
        "ล้มเหลว",
        "เกิดข้อผิดพลาดในการลบเพลง กรุณาลองใหม่อีกครั้ง",
      );
    } finally {
      if (context.mounted) LoadingOverlay.hide();
    }
  }

  Future<void> _showAddDialog(UploadSource source) async {
    final formKey = GlobalKey<FormState>();
    final fileFieldKey = GlobalKey<FileFieldBoxState>();
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    String? fileName;
    String? filePath;

    await ModalBottomSheet.showFormModal(
      context: context,
      title: source == UploadSource.file
          ? 'เพิ่มเพลงจากไฟล์'
          : 'เพิ่มเพลงจาก YouTube',
      child: Form(
        key: formKey,
        child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFieldBox(
                  controller: nameCtrl,
                  hint: 'ชื่อเพลง',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'กรุณากรอกชื่อเพลง';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                if (source == UploadSource.file) ...[
                  // โซนเลือกไฟล์
                  FileFieldBox(
                    key: fileFieldKey,
                    label: 'เลือกไฟล์เพลง (.mp3)',
                    allowedExtensions: ['mp3'],
                    onFileSelected: (path, name) {
                      setModalState(() {
                        fileName = name;
                        filePath = path;
                      });
                    },
                    onFileClear: () {
                      setModalState(() {
                        fileName = null;
                        filePath = null;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'กรุณาเลือกไฟล์เพลง';
                      }
                      return null;
                    },
                  ),
                ] else ...[
                  // โซน URL
                  TextFieldBox(
                    controller: urlCtrl,
                    hint: 'ลิงก์ YouTube',
                    textInputAction: TextInputAction.done,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'กรุณากรอกลิงก์ YouTube';
                      }
                      return null;
                    },
                  ),
                ],
              ],
            );
          },
        ),
      ),
      actions: Button(
        onPressed: () {
          // Validate form
          bool isValid = formKey.currentState?.validate() ?? false;

          // Validate file field separately if source is file
          if (source == UploadSource.file) {
            final fileError = fileFieldKey.currentState?.validate();
            if (fileError != null) {
              isValid = false;
            }
          }

          if (!isValid) {
            return; // หยุดถ้า validation ไม่ผ่าน
          }

          if (source == UploadSource.file) {
            if (fileName != null && filePath != null) {
              Navigator.of(context).pop();
              _uploadSongFile(filePath!, fileName!, nameCtrl.text.trim());
            }
          } else {
            Navigator.of(context).pop();
            _uploadSongYouTube(
              youtubeUrl: urlCtrl.text.trim(),
              name: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
            );
          }
        },
        label: 'เพิ่มเพลง',
        icon: Icons.save_outlined,
      ),
    );
  }

  Future<void> _showEditDialog(String id) async {
    await _loadSong(id);

    await ModalBottomSheet.showFormModal(
      context: context,
      title: "แก้ไขชื่อเพลง",
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [TextFieldBox(controller: _nameCtrl, hint: "ชื่อเพลง")],
      ),
      actions: Button(
        onPressed: () {
          _editSong(id, _nameCtrl.text);
          Navigator.pop(context);
        },
        label: "บันทึก",
        icon: Icons.save_outlined,
      ),
    );
  }

  void _showDeleteDialog(String id, String name) async {
    final confirmed = await CustomDialog.showConfirmation(
      context: context,
      title: "ยืนยันการลบ",
      message: "ยืนยันที่จะลบเพลง \"$name\" ?",
      confirmText: "ยืนยัน",
      cancelText: "ยกเลิก",
      confirmColor: Colors.red[50],
      cancelColor: Colors.grey[100],
      textColor: Colors.red,
      fontBold: true,
    );

    if (confirmed == true) {
      _deleteSong(id);
    }
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
                          onPressed: () => _showEditDialog(song.id.toString()),
                          icon: Icon(Icons.edit, color: Colors.amber),
                        ),
                        IconButton(
                          onPressed: () =>
                              _showDeleteDialog(song.id.toString(), song.name),
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
                            _showAddDialog(UploadSource.file);
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
                            _showAddDialog(UploadSource.youtube);
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
