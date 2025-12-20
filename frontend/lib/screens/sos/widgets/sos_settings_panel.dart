import 'package:flutter/material.dart';

class SosSettingsPanel extends StatelessWidget {
  final TextEditingController sipServerController;
  final FocusNode sipFocus;

  final TextEditingController recordFolderController;
  final FocusNode recordFolderFocus;

  final TextEditingController logFolderController;
  final FocusNode logFolderFocus;

  final VoidCallback onBrowseRecordFolder;
  final VoidCallback onClearRecordFolder;

  final VoidCallback onBrowseLogFolder;
  final VoidCallback onClearLogFolder;

  final VoidCallback onSave;

  const SosSettingsPanel({
    super.key,
    required this.sipServerController,
    required this.sipFocus,
    required this.recordFolderController,
    required this.recordFolderFocus,
    required this.logFolderController,
    required this.logFolderFocus,
    required this.onBrowseRecordFolder,
    required this.onClearRecordFolder,
    required this.onBrowseLogFolder,
    required this.onClearLogFolder,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final bool sipFocused = sipFocus.hasFocus;
    final Color sipBorderColor =
        sipFocused ? Colors.blue.shade700 : Colors.black;

    final bool recordFocused = recordFolderFocus.hasFocus;
    final Color recordBorderColor =
        recordFocused ? Colors.blue.shade700 : Colors.black;

    final bool logFocused = logFolderFocus.hasFocus;
    final Color logBorderColor =
        logFocused ? Colors.blue.shade700 : Colors.black;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SIP server
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SIP server',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 32,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: sipBorderColor, width: 1),
                      color: Colors.white,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: TextField(
                        controller: sipServerController,
                        focusNode: sipFocus,
                        style: const TextStyle(fontSize: 15),
                        textAlignVertical: TextAlignVertical.center,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Recording folder
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'โฟลเดอร์เก็บไฟล์บันทึกวิดีโอ (Recording)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: recordBorderColor,
                              width: 1,
                            ),
                            color: Colors.white,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: TextField(
                              controller: recordFolderController,
                              focusNode: recordFolderFocus,
                              style: const TextStyle(fontSize: 15),
                              maxLines: 1,
                              textAlignVertical: TextAlignVertical.center,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 30,
                          minHeight: 30,
                        ),
                        icon: const Icon(
                          Icons.folder_open,
                          size: 22,
                          color: Colors.black87,
                        ),
                        onPressed: onBrowseRecordFolder,
                        tooltip: 'เลือกโฟลเดอร์ Recording',
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 30,
                          minHeight: 30,
                        ),
                        icon: const Icon(
                          Icons.close,
                          size: 22,
                          color: Colors.black87,
                        ),
                        onPressed: onClearRecordFolder,
                        tooltip: 'ล้างค่า',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'สำหรับกำหนดที่เก็บไฟล์บันทึกวิดีโอ',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Log folder
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'โฟลเดอร์เก็บไฟล์ประวัติการโทร',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: logBorderColor,
                              width: 1,
                            ),
                            color: Colors.white,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: TextField(
                              controller: logFolderController,
                              focusNode: logFolderFocus,
                              style: const TextStyle(fontSize: 15),
                              maxLines: 1,
                              textAlignVertical: TextAlignVertical.center,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 30,
                          minHeight: 30,
                        ),
                        icon: const Icon(
                          Icons.folder_open,
                          size: 22,
                          color: Colors.black87,
                        ),
                        onPressed: onBrowseLogFolder,
                        tooltip: 'เลือกโฟลเดอร์ Log',
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 30,
                          minHeight: 30,
                        ),
                        icon: const Icon(
                          Icons.close,
                          size: 22,
                          color: Colors.black87,
                        ),
                        onPressed: onClearLogFolder,
                        tooltip: 'ล้างค่า',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'ระบบจะบันทึก log เป็นไฟล์ "call_logs.txt" ในโฟลเดอร์นี้',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          Center(
            child: SizedBox(
              width: 100,
              height: 38,
              child: ElevatedButton(
                onPressed: onSave,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF141E30),
                        Color(0xFF243B55),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.10),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.save_rounded, size: 18, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'บันทึก',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
