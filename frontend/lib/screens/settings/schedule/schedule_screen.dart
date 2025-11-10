import 'package:flutter/material.dart';
import 'package:smart_control/core/alert/app_snackbar.dart';
import 'package:smart_control/core/network/api_service.dart';
import 'package:smart_control/widgets/loading_overlay.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({Key? key}) : super(key: key);

  @override
  _ScheduleScreenState createState() => _ScheduleScreenState();
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
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      style: TextStyle(fontSize: 14),
    );
  }
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final TextEditingController _descriptionCtrl = TextEditingController();
  List<dynamic> _schedules = [];
  List<dynamic> _songs = [];
  String? _selectedSongId;
  Set<int> _selectedDays = {};
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
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

  void _loadSchedules() async {
    final api = await ApiService.private();

    try {
      final result = await api.get("/schedule");

      if (result['ok'] == true && result['data'] != null) {
        setState(() {
          _schedules = result['data'];
        });
      }
    } catch (error) {
      print("Error loading schedules: $error");
      AppSnackbar.error(
        "แจ้งเตือน",
        "เกิดข้อผิดพลาดในการโหลดข้อมูลเพลงตั้งเวลา",
      );
    }
  }

  Future<void> _loadSongs() async {
    final api = await ApiService.private();

    try {
      final result = await api.get("/song");
      if (result['status'] == 'success' && result['data'] != null) {
        if (mounted) {
          setState(() {
            _songs = result['data'];
          });
        }
      }
    } catch (error) {
      print("Error loading songs: $error");
      if (mounted) {
        AppSnackbar.error("แจ้งเตือน", "เกิดข้อผิดพลาดในการโหลดรายการเพลง");
      }
    }
  }

  void _changeStatus(String scheduleId, bool isActive) async {
    final api = await ApiService.private();

    try {
      // Optimistic UI update
      final index = _schedules.indexWhere((s) => s['_id'] == scheduleId);
      if (index != -1) {
        setState(() {
          _schedules[index]['is_active'] = isActive;
        });
      }

      final result = await api.patch(
        "/schedule/change-status/$scheduleId",
        data: {'is_active': isActive},
      );

      if (result['ok'] == true) {
        AppSnackbar.success("สำเร็จ", "เปลี่ยนสถานะเรียบร้อยแล้ว");
        _loadSchedules(); // refresh from server to ensure consistency
      }
    } catch (error) {
      print("Error changing schedule status: $error");
      AppSnackbar.error("แจ้งเตือน", "เกิดข้อผิดพลาดในการเปลี่ยนสถานะ");
      // revert optimistic update if failed
      final index = _schedules.indexWhere((s) => s['_id'] == scheduleId);
      if (index != -1) {
        setState(() {
          _schedules[index]['is_active'] = !_schedules[index]['is_active'];
        });
      }
    }
  }

  void _deleteSchedule(String scheduleId) async {
    final api = await ApiService.private();

    try {
      final result = await api.delete("/schedule/delete/$scheduleId");

      if (result['ok'] == true) {
        AppSnackbar.success("สำเร็จ", "ลบรายการเพลงตั้งเวลาเรียบร้อยแล้ว");
        _loadSchedules();
      }
    } catch (error) {
      print("Error deleting schedule: $error");
      AppSnackbar.error("แจ้งเตือน", "เกิดข้อผิดพลาดในการลบรายการเพลงตั้งเวลา");
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
    if (_selectedSongId == null) {
      AppSnackbar.error("แจ้งเตือน", "กรุณาเลือกเพลง");
      return;
    }

    if (_selectedDays.isEmpty) {
      AppSnackbar.error("แจ้งเตือน", "กรุณาเลือกวันในสัปดาห์");
      return;
    }

    LoadingOverlay.show(context);
    final api = await ApiService.private();

    try {
      final scheduleData = {
        'id_song': _selectedSongId,
        'days_of_week': _selectedDays.toList()..sort(),
        'time': _formatTime(_selectedTime),
        'description': _descriptionCtrl.text,
        'is_active': _isActive,
      };

      final result = await api.post("/schedule/save", data: scheduleData);

      if (result['ok'] == true) {
        Navigator.pop(modalContext);
        AppSnackbar.success("สำเร็จ", "บันทึกข้อมูลการตั้งเวลาเรียบร้อยแล้ว");
        _resetForm();
      }
    } catch (error) {
      print("Error saving schedule: $error");
      AppSnackbar.error("แจ้งเตือน", "เกิดข้อผิดพลาดในการบันทึกข้อมูล");
    } finally {
      LoadingOverlay.hide();
    }
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

  Future<void> scheduleForm() async {
    _resetForm();
    await _loadSongs();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext modalContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "เพิ่มรายการเพลงตั้งเวลา",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "เลือกเพลง",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
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
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: List.generate(7, (index) {
                              final dayIndex = index;
                              final isSelected = _selectedDays.contains(
                                dayIndex,
                              );
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
                                    color: isSelected
                                        ? Colors.blue
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.blue
                                          : Colors.grey[300]!,
                                      width: 2,
                                    ),
                                  ),
                                  child: Text(
                                    _dayNames[index],
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.black87,
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
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          InkWell(
                            onTap: () => _selectTime(context),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          _TextFieldBox(
                            controller: _descriptionCtrl,
                            hint: "คำอธิบาย",
                            textInputAction: TextInputAction.done,
                          ),
                          SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "สถานะ",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
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
                                    color: _isActive
                                        ? Colors.green
                                        : Colors.grey[400],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _isActive
                                            ? Icons.check_circle
                                            : Icons.cancel,
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
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _saveSchedule(modalContext),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          "บันทึก",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> deleteDialog(String scheduleId, String description) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("ยืนยันการลบ"),
          content: Text(
            "คุณแน่ใจหรือว่าต้องการลบรายการเพลงตั้งเวลา \"$description\" ?",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("ยกเลิก"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteSchedule(scheduleId);
              },
              child: Text("ยืนยัน"),
            ),
          ],
        );
      },
    );
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
                final days = (schedule['days_of_week'] as List<dynamic>)
                    .map((d) => _dayNames[d])
                    .join(', ');

                return Card(
                  color: Colors.grey[100],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    title: Text(
                      schedule['description'] ?? 'ไม่มีคำอธิบาย',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('เวลา: ${schedule['time']}'),
                        Text('วัน: $days'),
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
                            deleteDialog(
                              schedule['_id'].toString(),
                              schedule['description'] ?? '',
                            );
                          },
                          icon: Icon(Icons.delete, color: Colors.red),
                        ),
                        IconButton(
                          onPressed: () {},
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
        onPressed: () => scheduleForm(),
        foregroundColor: Colors.white,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ),
    );
  }
}
