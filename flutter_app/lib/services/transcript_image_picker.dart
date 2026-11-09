import 'package:file_picker/file_picker.dart';

import 'grade_import_service.dart';

abstract interface class TranscriptImagePicker {
  Future<List<ImageFile>?> pick();
}

class FileTranscriptImagePicker implements TranscriptImagePicker {
  @override
  Future<List<ImageFile>?> pick() async {
    final selected = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
      allowMultiple: true,
      withData: true,
    );
    if (selected == null) return null;
    if (selected.files.isEmpty || selected.files.length > 10) {
      throw GradeImportException('Chọn từ 1 đến 10 ảnh bảng điểm.');
    }
    return selected.files.map((file) {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw GradeImportException('Không thể đọc ảnh. Vui lòng chọn lại.');
      }
      return ImageFile(
        filename: file.name,
        bytes: bytes,
        mimeType: file.extension?.toLowerCase() == 'png'
            ? 'image/png'
            : 'image/jpeg',
      );
    }).toList();
  }
}
