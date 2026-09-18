import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../services/chat_api_service.dart';

class ChatProvider extends ChangeNotifier {
  late ChatApiService _apiService;
  
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool? _isServerOnline;
  String _baseUrl = 'http://localhost:8000';
  String? _lastError;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool? get isServerOnline => _isServerOnline;
  String get baseUrl => _baseUrl;
  String? get lastError => _lastError;

  ChatProvider({ChatApiService? apiService}) {
    _apiService = apiService ?? ChatApiService(baseUrl: _baseUrl);
    _initWelcomeMessage();
    checkServerHealth();
  }

  void updateBaseUrl(String newUrl) {
    if (newUrl.trim().isEmpty) return;
    _baseUrl = newUrl.trim();
    _apiService = ChatApiService(baseUrl: _baseUrl);
    checkServerHealth();
    notifyListeners();
  }

  void _initWelcomeMessage() {
    _messages.add(
      ChatMessage(
        id: 'welcome_msg',
        text: '👋 **Xin chào! Tôi là Trợ lý AI môn học FLM.**\n\n'
            'Bạn có thể hỏi tôi về các thông tin trong Đề cương & Khung chương trình FLM:\n'
            '• *Hình thức thi/đánh giá môn PRM392?*\n'
            '• *Mục tiêu môn học (Learning Outcomes)?*\n'
            '• *Số tín chỉ của môn PRM392 / SWD392?*\n'
            '• *Kế hoạch môn SWD392 học ở học kỳ mấy?*',
        sender: ChatSender.ai,
        timestamp: DateTime.now(),
        status: MessageStatus.success,
        sources: ['FLM Knowledge Base'],
      ),
    );
  }

  Future<void> checkServerHealth() async {
    _isServerOnline = null; // Loading state
    notifyListeners();

    final isOnline = await _apiService.checkHealth();
    _isServerOnline = isOnline;
    notifyListeners();
  }

  Future<void> sendPrompt(String text) async {
    final prompt = text.trim();
    if (prompt.isEmpty || _isLoading) return;

    final timestamp = DateTime.now();
    final userMsgId = 'user_${timestamp.millisecondsSinceEpoch}';
    final aiMsgId = 'ai_${timestamp.millisecondsSinceEpoch}';

    // Add User Message
    final userMessage = ChatMessage(
      id: userMsgId,
      text: prompt,
      sender: ChatSender.user,
      timestamp: timestamp,
      status: MessageStatus.success,
    );
    _messages.add(userMessage);

    // Add Loading AI Message placeholder
    final loadingAiMessage = ChatMessage(
      id: aiMsgId,
      text: 'Đang tra cứu dữ liệu FLM...',
      sender: ChatSender.ai,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
    );
    _messages.add(loadingAiMessage);

    _isLoading = true;
    _lastError = null;
    notifyListeners();

    // Call API Service
    final result = await _apiService.sendMessage(prompt);

    // Update AI Message with real result or fallback
    final index = _messages.indexWhere((m) => m.id == aiMsgId);
    if (index != -1) {
      _messages[index] = ChatMessage(
        id: aiMsgId,
        text: result.answer,
        sender: ChatSender.ai,
        timestamp: DateTime.now(),
        status: result.isOfflineFallback
            ? MessageStatus.offlineFallback
            : MessageStatus.success,
        sources: result.sources,
        errorMessage: result.errorMessage,
      );
    }

    _isLoading = false;
    _isServerOnline = !result.isOfflineFallback;
    if (result.isOfflineFallback) {
      _lastError = result.errorMessage;
    }
    notifyListeners();
  }

  void clearHistory() {
    _messages.clear();
    _initWelcomeMessage();
    notifyListeners();
  }
}
