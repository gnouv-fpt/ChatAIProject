import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/transcript_entry.dart';

/// Gọi backend endpoint POST /api/v1/import-grade
/// Nhận List<(filename, bytes, mimeType)>, trả về raw JSON từ server.
class GradeImportService {
  final String baseUrl;

  GradeImportService({required this.baseUrl});

  /// Upload 1..10 ảnh bảng điểm, trả về danh sách TranscriptEntry + warning.
  Future<GradeImportResult> importFromImages(
    List<ImageFile> images,
  ) async {
    final uri = Uri.parse('$baseUrl/api/v1/import-grade');
    final request = http.MultipartRequest('POST', uri);

    for (final img in images) {
      final contentType = _detectMime(img.mimeType);
      request.files.add(
        http.MultipartFile.fromBytes(
          'images',
          img.bytes,
          filename: img.filename,
          contentType: contentType,
        ),
      );
    }

    try {
      final streamed = await request.send().timeout(const Duration(seconds: 90));
      final body = await streamed.stream.bytesToString();

      if (streamed.statusCode != 200) {
        final err = _extractErrorDetail(body);
        throw GradeImportException('Server lỗi ${streamed.statusCode}: $err');
      }

      final json = jsonDecode(body) as Map<String, dynamic>;
      final rawEntries = (json['entries'] as List?) ?? [];
      final entries = rawEntries
          .map((e) => TranscriptEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      final warning = json['warning'] as String? ?? '';

      return GradeImportResult(entries: entries, warning: warning);
    } on GradeImportException {
      rethrow;
    } catch (e) {
      throw GradeImportException('Không thể kết nối server: $e');
    }
  }

  static MediaType _detectMime(String mime) {
    if (mime.contains('/')) {
      final parts = mime.split('/');
      return MediaType(parts[0], parts[1]);
    }
    return MediaType('image', 'jpeg');
  }

  static String _extractErrorDetail(String body) {
    try {
      final j = jsonDecode(body);
      return j['detail']?.toString() ?? body;
    } catch (_) {
      return body.length > 200 ? '${body.substring(0, 200)}...' : body;
    }
  }
}

class ImageFile {
  final String filename;
  final Uint8List bytes;
  final String mimeType;

  const ImageFile({
    required this.filename,
    required this.bytes,
    this.mimeType = 'image/jpeg',
  });
}

class GradeImportResult {
  final List<TranscriptEntry> entries;
  final String warning;

  const GradeImportResult({required this.entries, required this.warning});
}

class GradeImportException implements Exception {
  final String message;
  GradeImportException(this.message);

  @override
  String toString() => message;
}
