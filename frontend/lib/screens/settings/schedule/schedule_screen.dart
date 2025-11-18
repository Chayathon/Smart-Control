import 'package:flutter/material.dart';
import 'package:smart_control/core/alert/app_snackbar.dart';
import 'package:smart_control/core/network/api_exceptions.dart';
import 'package:smart_control/services/schedule_service.dart';
import 'package:smart_control/widgets/loading_overlay.dart';
import 'package:smart_control/widgets/inputs/text_field_box.dart';
import 'package:smart_control/widgets/buttons/action_button.dart';
import 'package:smart_control/widgets/dialogs/alert_dialog.dart';
import 'package:smart_control/widgets/modals/modal_bottom_sheet.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({Key? key}) : super(key: key);

  @override
  _ScheduleScreenState createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final TextEditingController _descriptionCtrl = TextEditingController();
  List<dynamic> _schedules = [];
  List<dynamic> _songs = [];
  String? _selectedSongId;
  Set<int> _selectedDays = {};
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isActive = true;
  bool _songsLoaded = false;

  @override
  void initState() {
    super.initState();
    // Load schedules after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSchedules();
    });
  }

  final List<String> _dayNames = [
    'อาทิตย์',
    'จันทร์',
    'อังคาร',
    'พุธ',
    'พฤหัสบดี',
    'ศุกร์',
    'เสาร์',
  ];

  Future<void> _loadSchedules() async {
    if (!mounted) return;

    LoadingOverlay.show(context);

    try {
      final schedules = await ScheduleService.getSchedules();
      if (mounted) {
        setState(() {
          _schedules = schedules;
        });
      }
    } catch (error) {
      print("Error loading schedules: $error");
      if (mounted) {
        AppSnackbar.error(
          "ล้มเหลว",
          "เกิดข้อผิดพลาดในการโหลดข้อมูลเพลงตั้งเวลา กรุณาลองใหม่อีกครั้ง",
        );
      }
    } finally {
      if (mounted) {
        LoadingOverlay.hide();
      }
    }
  }

  Future<void> _loadSchedule(String scheduleId) async {
    LoadingOverlay.show(context);
    try {
      final schedule = await ScheduleService.getScheduleById(scheduleId);

      if (schedule != null && mounted) {
        setState(() {
          _selectedSongId = schedule['id_song']['_id'].toString();
          _selectedDays = Set<int>.from(
            schedule['days_of_week'] as List<dynamic>,
          );
          final timeParts = (schedule['time'] as String).split(':');
          _selectedTime = TimeOfDay(
            hour: int.parse(timeParts[0]),
            minute: int.parse(timeParts[1]),
          );
          _descriptionCtrl.text = schedule['description'] ?? '';
          _isActive = schedule['is_active'] ?? true;
        });
      }
    } catch (error) {
      print("Error loading schedule: $error");
      if (mounted) {
        AppSnackbar.error(
          "ล้มเหลว",
          "เกิดข้อผิดพลาดในการโหลดข้อมูล กรุณาลองใหม่อีกครั้ง",
        );
      }
    } finally {
      if (mounted) {
        LoadingOverlay.hide();
      }
    }
  }

  Future<void> _loadSongs() async {
    try {
      final songs = await ScheduleService.getSongs();
      if (mounted) {
        setState(() {
          _songs = songs;
          _songsLoaded = true;
        });
      }
    } catch (error) {
      print("Error loading songs: $error");
      if (mounted) {
        AppSnackbar.error(
          "ล้มเหลว",
          "เกิดข้อผิดพลาดในการโหลดข้อมูลเพลง กรุณาลองใหม่อีกครั้ง",
        );
      }
    }
  }

  Future<void> _changeStatus(String scheduleId, bool isActive) async {
    // Optimistic update
    final index = _schedules.indexWhere((s) => s['_id'] == scheduleId);
    if (index != -1) {
      setState(() {
        _schedules[index]['is_active'] = isActive;
      });
    }

    try {
      final success = await ScheduleService.changeStatus(scheduleId, isActive);

      if (success) {
        AppSnackbar.success("สำเร็จ", "เปลี่ยนสถานะเรียบร้อยแล้ว");
        _loadSchedules();
      } else {
        throw Exception("Failed to change status");
      }
    } catch (error) {
      print("Error changing schedule status: $error");
      if (mounted) {
        AppSnackbar.error(
          "ล้มเหลว",
          "เกิดข้อผิดพลาดในการเปลี่ยนสถานะ กรุณาลองใหม่อีกครั้ง",
        );
        // Revert optimistic update
        if (index != -1) {
          setState(() {
            _schedules[index]['is_active'] = !isActive;
          });
        }
      }
    }
  }

  Future<void> _deleteSchedule(String scheduleId) async {
    if (!mounted) return;

    LoadingOverlay.show(context);

    try {
      final success = await ScheduleService.deleteSchedule(scheduleId);

      if (success) {
        AppSnackbar.success("สำเร็จ", "ลบรายการเพลงตั้งเวลาเรียบร้อยแล้ว");
        await _loadSchedules();
      } else {
        throw Exception("Failed to delete schedule");
      }
    } catch (error) {
      print("Error deleting schedule: $error");
      if (mounted) {
        AppSnackbar.error(
          "ล้มเหลว",
          "เกิดข้อผิดพลาดในการลบรายการเพลงตั้งเวลา กรุณาลองใหม่อีกครั้ง",
        );
      }
    } finally {
      if (mounted) {
        LoadingOverlay.hide();
      }
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(primary: Colors.blue),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _saveSchedule(BuildContext modalContext) async {
    if (!_validateForm()) return;

    if (!mounted) return;
    LoadingOverlay.show(context);

    try {
      final scheduleData = _buildScheduleData();
      final success = await ScheduleService.createSchedule(scheduleData);

      if (success) {
        if (mounted) {
          Navigator.pop(modalContext);
          AppSnackbar.success("สำเร็จ", "บันทึกข้อมูลการตั้งเวลาเรียบร้อยแล้ว");
        }
        await _loadSchedules();
        _resetForm();
      } else {
        throw Exception("Failed to save schedule");
      }
    } on ApiException catch (error) {
      if (mounted) {
        AppSnackbar.error("ล้มเหลว", error.message);
      }
    } catch (error) {
      print("Error saving schedule: $error");
      if (mounted) {
        AppSnackbar.error(
          "ล้มเหลว",
          "เกิดข้อผิดพลาดในการบันทึกข้อมูล กรุณาลองใหม่อีกครั้ง",
        );
      }
    } finally {
      if (mounted) {
        LoadingOverlay.hide();
      }
    }
  }

  Future<void> _updateSchedule(
    BuildContext modalContext,
    String scheduleId,
  ) async {
    if (!_validateForm()) return;

    if (!mounted) return;
    LoadingOverlay.show(context);

    try {
      final scheduleData = _buildScheduleData();
      final success = await ScheduleService.updateSchedule(
        scheduleId,
        scheduleData,
      );

      if (success) {
        if (mounted) {
          Navigator.pop(modalContext);
          AppSnackbar.success("สำเร็จ", "อัปเดตข้อมูลการตั้งเวลาเรียบร้อยแล้ว");
        }
        await _loadSchedules();
        _resetForm();
      } else {
        throw Exception("Failed to update schedule");
      }
    } on ApiException catch (error) {
      if (mounted) {
        AppSnackbar.error("ล้มเหลว", error.message);
      }
    } catch (error) {
      print("Error updating schedule: $error");
      if (mounted) {
        AppSnackbar.error(
          "ล้มเหลว",
          "เกิดข้อผิดพลาดในการอัปเดตข้อมูล กรุณาลองใหม่อีกครั้ง",
        );
      }
    } finally {
      if (mounted) {
        LoadingOverlay.hide();
      }
    }
  }

  bool _validateForm() {
    if (_selectedSongId == null) {
      AppSnackbar.info("แจ้งเตือน", "กรุณาเลือกเพลง");
      return false;
    }

    if (_selectedDays.isEmpty) {
      AppSnackbar.info("แจ้งเตือน", "กรุณาเลือกวันในสัปดาห์");
      return false;
    }

    if (_descriptionCtrl.text.isEmpty) {
      AppSnackbar.info("แจ้งเตือน", "กรุณาใส่คำอธิบาย");
      return false;
    }

    return true;
  }

  Map<String, dynamic> _buildScheduleData() {
    return {
      'id_song': _selectedSongId,
      'days_of_week': _selectedDays.toList()..sort(),
      'time': _formatTime(_selectedTime),
      'description': _descriptionCtrl.text,
      'is_active': _isActive,
    };
  }

  void _resetForm() {
    setState(() {
      _selectedSongId = null;
      _selectedDays.clear();
      _selectedTime = TimeOfDay.now();
      _descriptionCtrl.clear();
      _isActive = true;
    });
  }

  Future<void> _showScheduleForm(String? scheduleId) async {
    _resetForm();

    if (!_songsLoaded) {
      await _loadSongs();
    }

    if (scheduleId != null) {
      await _loadSchedule(scheduleId);
    }

    if (!mounted) return;

    await ModalBottomSheet.showFormModal(
      context: context,
      title: scheduleId != null
          ? "แก้ไขรายการเพลงตั้งเวลา"
          : "เพิ่มรายการเพลงตั้งเวลา",
      child: StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "เลือกเพลง",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
              ),
              SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedSongId,
                  decoration: InputDecoration(
                    hintText: "เลือกเพลง",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  items: _songs.map((song) {
                    return DropdownMenuItem<String>(
                      value: song['_id'].toString(),
                      child: Text(
                        song['name'] ?? 'ไม่มีชื่อ',
                        style: TextStyle(fontSize: 14),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setModalState(() {
                      setState(() {
                        _selectedSongId = value;
                      });
                    });
                  },
                ),
              ),
              SizedBox(height: 20),
              Text(
                "เลือกวันในสัปดาห์",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(7, (index) {
                  final dayIndex = index;
                  final isSelected = _selectedDays.contains(dayIndex);
                  return InkWell(
                    onTap: () {
                      setModalState(() {
                        setState(() {
                          if (isSelected) {
                            _selectedDays.remove(dayIndex);
                          } else {
                            _selectedDays.add(dayIndex);
                          }
                        });
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? Colors.blue : Colors.grey[300]!,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        _dayNames[index],
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              SizedBox(height: 20),
              Text(
                "เลือกเวลา",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
              ),
              SizedBox(height: 8),
              InkWell(
                onTap: () => _selectTime(context),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatTime(_selectedTime),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Icon(Icons.access_time),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              Text(
                "คำอธิบาย",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
              ),
              SizedBox(height: 8),
              TextFieldBox(
                controller: _descriptionCtrl,
                hint: "เพลงชาติไทย, เพลงเช้า, เพลงเย็น ฯลฯ",
                textInputAction: TextInputAction.done,
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "สถานะ",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
                  ),
                  InkWell(
                    onTap: () {
                      setModalState(() {
                        setState(() {
                          _isActive = !_isActive;
                        });
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _isActive ? Colors.green : Colors.grey[400],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isActive ? Icons.check_circle : Icons.cancel,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            _isActive ? "เปิดใช้งาน" : "ปิดใช้งาน",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
      actions: Button(
        onPressed: () {
          if (scheduleId != null) {
            _updateSchedule(context, scheduleId);
          } else {
            _saveSchedule(context);
          }
        },
        label: "บันทึก",
        icon: Icons.save_outlined,
      ),
    );
  }

  Future<void> _showDeleteDialog(String scheduleId, String description) async {
    final confirmed = await CustomDialog.showConfirmation(
      context: context,
      title: "ยืนยันการลบ",
      message: "ยืนยันที่จะลบเพลงตั้งเวลา \"$description\" ?",
      confirmText: "ยืนยัน",
      cancelText: "ยกเลิก",
      confirmColor: Colors.red[50],
      cancelColor: Colors.grey[100],
      textColor: Colors.red,
      fontBold: true,
    );

    if (confirmed == true) {
      _deleteSchedule(scheduleId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "เพลงตั้งเวลา",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        actionsIconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
        elevation: 1,
      ),
      body: _schedules.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_off_rounded, size: 64, color: Colors.grey),
                  Text(
                    "ไม่มีรายการเพลงตั้งเวลา",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    "กดปุ่ม ➕ เพื่อตั้งเวลาเปิดเพลงอัตโนมัติ",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(12),
              itemCount: _schedules.length,
              itemBuilder: (context, index) {
                final schedule = _schedules[index];

                return Card(
                  color: Colors.grey[100],
                  child: ListTile(
                    title: Text(
                      schedule['time'],
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            ...((schedule['days_of_week'] as List<dynamic>)
                                .map<Widget>(
                                  (d) => Padding(
                                    padding: EdgeInsets.only(right: 4),
                                    child: Card(
                                      margin: EdgeInsets.symmetric(vertical: 4),
                                      color: Colors.blue[100],
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 4,
                                        ),
                                        child: Text(
                                          _dayNames[d],
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.blue[800],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList()),
                          ],
                        ),
                        Text('คำอธิบาย: ${schedule['description'] ?? ''}'),
                        Text(
                          'เพลง: ${schedule['id_song']['name'] ?? 'ไม่มีชื่อ'}',
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () {
                            _showDeleteDialog(
                              schedule['_id'].toString(),
                              schedule['description'] ?? '',
                            );
                          },
                          icon: Icon(Icons.delete, color: Colors.red),
                        ),
                        IconButton(
                          onPressed: () {
                            _showScheduleForm(schedule['_id'].toString());
                          },
                          icon: Icon(Icons.edit, color: Colors.amber),
                        ),
                        Switch(
                          value:
                              (schedule['is_active'] is bool
                                  ? schedule['is_active']
                                  : schedule['is_active'] == 1) ??
                              false,
                          onChanged: (value) {
                            _changeStatus(schedule['_id'].toString(), value);
                          },
                          activeColor: Colors.blue[600],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showScheduleForm(null),
        foregroundColor: Colors.white,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ),
    );
  }
}
