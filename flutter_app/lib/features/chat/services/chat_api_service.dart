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
  /// Nếu server lỗi hoặc ngắt mạng, tự động kích hoạt Offline Resilience Fallback
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
        // Server trả về mã lỗi HTTP (500, 404, etc.)
        return _generateOfflineResponse(
          prompt,
          errorMessage: 'Server AI trả về mã lỗi (${response.statusCode}). Đã chuyển sang chế độ trả lời ngoại tuyến.',
        );
      }
    } on SocketException catch (_) {
      return _generateOfflineResponse(
        prompt,
        errorMessage: 'Không thể kết nối đến AI Server Backend (SocketException). Đã kích hoạt Chế độ Ngoại tuyến (Resilience Mode).',
      );
    } on TimeoutException catch (_) {
      return _generateOfflineResponse(
        prompt,
        errorMessage: 'Kết nối đến AI Server quá thời gian chờ (Timeout). Đã dùng dữ liệu offline.',
      );
    } catch (e) {
      return _generateOfflineResponse(
        prompt,
        errorMessage: 'Lỗi kết nối: ${e.toString()}. Đã chuyển sang chế độ ngoại tuyến.',
      );
    }
  }

  /// Trả lời offline thông minh dựa trên dữ liệu FLM khi không có kết nối Backend
  ChatResponseResult _generateOfflineResponse(String prompt, {String? errorMessage}) {
    final lower = prompt.toLowerCase();
    String answer;
    List<String> sources = ['FLM Offline Knowledge Store (Local Cache)'];

    if (lower.contains('prm392') && (lower.contains('pe') || lower.contains('thi') || lower.contains('hình thức'))) {
      answer = '📌 **Thông tin môn PRM392 (Lập trình thiết bị di động):**\n\n'
          '• **Hình thức thi:** Môn PRM392 **CÓ thi PE (Practical Exam)** trực tiếp trên máy tính (thời gian 90 phút).\n'
          '• **Hình thức đánh giá khác:** Bài tập lớn / Dự án nhóm (Group Project) + Thi lý thuyết FE (Final Exam).';
      sources.add('PRM392 Syllabus - Assessment Scheme');
    } else if (lower.contains('prm392') && (lower.contains('mục tiêu') || lower.contains('lo') || lower.contains('learning outcome'))) {
      answer = '🎯 **Mục tiêu môn học (Learning Outcomes - LOs) của PRM392:**\n\n'
          '1. **LO1:** Nắm vững kiến thức nền tảng về phát triển ứng dụng di động (Flutter / Android Native).\n'
          '2. **LO2:** Xây dựng giao diện UI/UX trực quan, tương tác mượt mà và responsive trên nhiều kích thước màn hình.\n'
          '3. **LO3:** Xử lý gọi RESTful API, quản lý State Management và tích hợp dữ liệu local/remote.\n'
          '4. **LO4:** Làm việc nhóm hoàn thiện sản phẩm ứng dụng di động thực tế.';
      sources.add('PRM392 Syllabus - Course Learning Outcomes');
    } else if (lower.contains('tín chỉ') || lower.contains('credit')) {
      if (lower.contains('swd392')) {
        answer = '🔢 Môn **SWD392 (Software Architecture and Design)** trong khung chương trình có **3 tín chỉ**.';
      } else {
        answer = '🔢 Trong khung chương trình FLM của bạn:\n'
            '• **PRM392 (Mobile Programming):** 3 tín chỉ.\n'
            '• **SWD392 (Software Architecture):** 3 tín chỉ.\n'
            '• **PRF192 (Programming Fundamentals):** 3 tín chỉ.';
      }
      sources.add('FLM Curriculum Standard Credits');
    } else if (lower.contains('học kỳ') || lower.contains('swd392')) {
      answer = '🗓️ **Kế hoạch học tập:**\n'
          '• Môn **SWD392 (Software Architecture & Design)** nằm ở **Học kỳ 5** trong lộ trình tiêu chuẩn.\n'
          '• Môn **PRM392 (Mobile Programming)** nằm ở **Học kỳ 6** trong lộ trình ngành Software Engineering.';
      sources.add('FLM Roadmaps & Prerequisites');
    } else {
      answer = '💡 **[Trả lời Ngoại tuyến - FLM Offline Assistant]**\n\n'
          'Tôi đã nhận được câu hỏi: "$prompt".\n\n'
          'Hiện tại AI Server đang ngoại tuyến, nhưng dữ liệu FLM cơ bản thể hiện:\n'
          '• Các môn học chuyên ngành SE gồm: PRF192, PRO192, PRM392, SWD392, SEP490.\n'
          '• Bạn có thể hỏi về: *Hình thức thi PE môn PRM392*, *Mục tiêu môn học*, *Số tín chỉ*, *Môn SWD392 học ở học kỳ mấy*.';
    }

    return ChatResponseResult(
      answer: answer,
      sources: sources,
      isOfflineFallback: true,
      errorMessage: errorMessage,
    );
  }
}
