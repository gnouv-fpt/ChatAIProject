import 'package:flutter/foundation.dart';

import '../models/transcript_entry.dart';
import '../services/grade_import_service.dart';
import '../services/transcript_image_picker.dart';

enum ImportStatus { idle, loading, empty, error, data }

class TranscriptImportViewModel extends ChangeNotifier {
  TranscriptImportViewModel({required this.picker, required this.service});
  final TranscriptImagePicker picker;
  final GradeImportService Function() service;
  ImportStatus status = ImportStatus.idle;
  String? message;
  bool _disposed = false;
  bool get busy => status == ImportStatus.loading;

  Future<GradeImportResult?> import() async {
    if (busy) return null;
    status = ImportStatus.loading;
    message = null;
    notifyListeners();
    try {
      final images = await picker.pick();
      if (_disposed) return null;
      if (images == null) {
        status = ImportStatus.idle;
        return null;
      }
      final result = await service().importFromImages(images);
      if (_disposed) return null;
      if (result.entries.isEmpty) {
        status = ImportStatus.empty;
        message = 'Không đọc được môn học nào từ ảnh. Hãy thử ảnh rõ hơn hoặc nhập tay.';
        return null;
      }
      status = ImportStatus.data;
      return result;
    } on GradeImportException catch (error) {
      status = ImportStatus.error;
      message = error.message;
      return null;
    } catch (_) {
      status = ImportStatus.error;
      message = 'Không thể xử lý ảnh. Vui lòng thử lại hoặc nhập tay.';
      return null;
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  List<TranscriptEntry> merge(
    List<TranscriptEntry> saved,
    List<TranscriptEntry> imported,
  ) {
    final merged = List<TranscriptEntry>.from(saved);
    for (final entry in imported) {
      final index = merged.indexWhere(
        (old) =>
            old.courseCode == entry.courseCode &&
            old.semester == entry.semester,
      );
      if (index == -1) {
        merged.add(entry);
      } else {
        merged[index] = entry;
      }
    }
    return merged;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
