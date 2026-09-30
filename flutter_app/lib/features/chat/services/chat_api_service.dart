import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../../services/grade_import_service.dart';

class ChatResponseResult {
  final String answer;
  final List<String> sources;
  final bool isOfflineFallback;
  final String? errorMessage;

  ChatResponseResult({
    required this.answer,
    required this.sources,
    required this.isOfflineFallback,
    this.errorMessage,
  });
}

class ChatApiService {
  final String baseUrl;
  final http.Client client;

  ChatApiService({this.baseUrl = 'http://localhost:8000', http.Client? client})
    : client = client ?? http.Client();

  /// Kiểm tra kết nối tới FastAPI Backend Server
  Future<bool> checkHealth() async {
    try {
      final response = await client
          .get(Uri.parse('$baseUrl/api/v1/health'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Gửi câu hỏi đến FastAPI RAG Chatbot Endpoint (`/api/v1/chat`)
  /// Hỗ trợ scope ('curriculum' | 'subject') và target id/courseCode theo Mục 5.1
  /// studentContext: dữ kiện GPA đã tính bằng code (Mục 7.4), gửi kèm để LLM tư vấn chính xác
  Future<ChatResponseResult> sendMessage(
    String prompt, {
    String? scope,
    String? id,
    String? courseCode,
    Map<String, dynamic>? studentContext,
  }) async {
    try {
      final payload = <String, dynamic>{'question': prompt, 'prompt': prompt};
      if (scope != null && scope.isNotEmpty) {
        payload['scope'] = scope;
      }
      if (id != null && id.isNotEmpty) {
        payload['id'] = id;
      }
      final targetCourse = courseCode ?? (scope == 'subject' ? id : null);
      if (targetCourse != null && targetCourse.isNotEmpty) {
        payload['course_code'] = targetCourse;
      }
      // Gửi dữ kiện học tập đã tính bằng code (Mục 7.4 — LLM không tự tính GPA)
      if (studentContext != null && studentContext.isNotEmpty) {
        payload['student_context'] = studentContext;
      }

      final response = await client
          .post(
            Uri.parse('$baseUrl/api/v1/chat'),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 90));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return ChatResponseResult(
          answer:
              data['answer'] ??
              data['response'] ??
              'Không nhận được câu trả lời.',
          sources:
              (data['sources'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              ['Hệ thống FLM Backend'],
          isOfflineFallback: false,
        );
      } else {
        return ChatResponseResult(
          answer:
              '⚠️ **Lỗi kết nối Server AI:** Server trả về mã lỗi HTTP `${response.statusCode}`. Vui lòng kiểm tra lại backend FastAPI tại `$baseUrl`.',
          sources: const [],
          isOfflineFallback: false,
          errorMessage: 'Server HTTP ${response.statusCode}',
        );
      }
    } on SocketException catch (_) {
      return ChatResponseResult(
        answer:
            '⚠️ **Không thể kết nối đến AI Server Backend:** Không thể kết nối tới `$baseUrl`. Vui lòng đảm bảo bạn đã khởi động backend FastAPI (chạy `python run_backend.py`).',
        sources: const [],
        isOfflineFallback: false,
        errorMessage: 'SocketException',
      );
    } on TimeoutException catch (_) {
      return ChatResponseResult(
        answer: '⚠️ **Kết nối quá thời gian chờ (Timeout):** AI Server không phản hồi trong 90 giây. Model Ollama có thể đang khởi động hoặc máy đang thiếu tài nguyên.',
        sources: const [],
        isOfflineFallback: false,
        errorMessage: 'TimeoutException',
      );
    } catch (e) {
      return ChatResponseResult(
        answer: '⚠️ **Lỗi gửi tin nhắn:** ${e.toString()}',
        sources: const [],
        isOfflineFallback: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<ChatResponseResult> sendMessageWithImages(
    String prompt,
    List<ImageFile> images, {
    String? scope,
    String? id,
    String? courseCode,
  }) async {
    try {
      final request =
          http.MultipartRequest(
              'POST',
              Uri.parse('$baseUrl/api/v1/chat/images'),
            )
            ..fields['question'] = prompt
            ..fields['scope'] = scope ?? ''
            ..fields['id'] = id ?? ''
            ..fields['course_code'] = courseCode ?? '';

      for (final image in images) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'images',
            image.bytes,
            filename: image.filename,
            contentType: MediaType.parse(image.mimeType),
          ),
        );
      }

      final streamed = await request.send().timeout(
        // Local qwen2.5vl:3b runs on CPU and may need several minutes for a
        // high-resolution screenshot.
        const Duration(seconds: 300),
      );
      final response = await http.Response.fromStream(streamed);
      final data = response.bodyBytes.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return ChatResponseResult(
          answer: data['answer'] ?? 'Không nhận được câu trả lời từ Vision AI.',
          sources:
              (data['sources'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const [],
          isOfflineFallback: false,
        );
      }

      final detail =
          data['detail']?.toString() ?? 'Vision AI không xử lý được ảnh.';
      return ChatResponseResult(
        answer: '⚠️ $detail',
        sources: const [],
        isOfflineFallback: false,
        errorMessage: 'Vision HTTP ${response.statusCode}',
      );
    } on TimeoutException catch (_) {
      return ChatResponseResult(
        answer: '⚠️ Vision AI xử lý ảnh quá lâu. Hãy thử ảnh ít hơn hoặc ảnh nhẹ hơn.',
        sources: const [],
        isOfflineFallback: false,
        errorMessage: 'VisionTimeoutException',
      );
    } catch (e) {
      return ChatResponseResult(
        answer: '⚠️ Gửi ảnh thất bại: $e',
        sources: const [],
        isOfflineFallback: false,
        errorMessage: e.toString(),
      );
    }
  }
}
