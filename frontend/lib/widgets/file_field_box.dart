import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

/// Reusable File Selection Widget
class FileFieldBox extends StatefulWidget {
  const FileFieldBox({
    Key? key,
    required this.label,
    this.allowedExtensions = const ['mp3'],
    this.fileType = FileType.custom,
    this.onFileSelected,
    this.onFileClear,
    this.allowMultiple = false,
    this.initialFileName,
  }) : super(key: key);

  final String label;
  final List<String> allowedExtensions;
  final FileType fileType;
  final Function(String path, String fileName)? onFileSelected;
  final VoidCallback? onFileClear;
  final bool allowMultiple;
  final String? initialFileName;

  @override
  State<FileFieldBox> createState() => _FileFieldBoxState();
}

class _FileFieldBoxState extends State<FileFieldBox> {
  String? _fileName;
  String? _filePath;

  @override
  void initState() {
    super.initState();
    if (widget.initialFileName != null) {
      _fileName = widget.initialFileName;
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: widget.fileType,
      allowedExtensions: widget.fileType == FileType.custom
          ? widget.allowedExtensions
          : null,
      allowMultiple: widget.allowMultiple,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      setState(() {
        _fileName = file.name;
        _filePath = file.path;
      });

      if (widget.onFileSelected != null && _filePath != null) {
        widget.onFileSelected!(_filePath!, _fileName!);
      }
    }
  }

  void _clearFile() {
    setState(() {
      _fileName = null;
      _filePath = null;
    });

    if (widget.onFileClear != null) {
      widget.onFileClear!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFile = _fileName != null;

    return GestureDetector(
      onTap: _pickFile,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              hasFile ? Icons.check_circle : Icons.upload_file,
              color: hasFile ? Colors.green : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _fileName ?? widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: hasFile ? FontWeight.bold : FontWeight.normal,
                  color: hasFile ? Colors.black : Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ),
            if (hasFile)
              IconButton(
                tooltip: 'ลบไฟล์ที่เลือก',
                onPressed: _clearFile,
                icon: const Icon(Icons.close, color: Colors.red),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }

  // Getter methods to access file info from parent
  String? get fileName => _fileName;
  String? get filePath => _filePath;
  bool get hasFile => _fileName != null;
}
