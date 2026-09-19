import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

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

  ChatApiService({
    this.baseUrl = 'http://localhost:8000',
    http.Client? client,
  }) : client = client ?? http.Client();

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
  Future<ChatResponseResult> sendMessage(String prompt) async {
    try {
      final response = await client
          .post(
            Uri.parse('$baseUrl/api/v1/chat'),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({'question': prompt}),
          )
          .timeout(const Duration(seconds: 7));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return ChatResponseResult(
          answer: data['answer'] ?? data['response'] ?? 'Không nhận được câu trả lời.',
          sources: (data['sources'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              ['Hệ thống FLM Backend'],
          isOfflineFallback: false,
        );
      } else {
        return ChatResponseResult(
          answer: '⚠️ **Lỗi kết nối Server AI:** Server trả về mã lỗi HTTP `${response.statusCode}`. Vui lòng kiểm tra lại backend FastAPI tại `$baseUrl`.',
          sources: const [],
          isOfflineFallback: false,
          errorMessage: 'Server HTTP ${response.statusCode}',
        );
      }
    } on SocketException catch (_) {
      return ChatResponseResult(
        answer: '⚠️ **Không thể kết nối đến AI Server Backend:** Không thể kết nối tới `$baseUrl`. Vui lòng đảm bảo bạn đã khởi động backend FastAPI (chạy `python run_backend.py`).',
        sources: const [],
        isOfflineFallback: false,
        errorMessage: 'SocketException',
      );
    } on TimeoutException catch (_) {
      return ChatResponseResult(
        answer: '⚠️ **Kết nối quá thời gian chờ (Timeout):** AI Server không phản hồi trong 7 giây. Vui lòng kiểm tra lại server.',
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
}
