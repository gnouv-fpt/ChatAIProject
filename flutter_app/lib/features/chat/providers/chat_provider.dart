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
  String _currentScope = 'curriculum';
  String _currentScopeId = 'BIT_SE_K19B';

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool? get isServerOnline => _isServerOnline;
  String get baseUrl => _baseUrl;
  String? get lastError => _lastError;
  String get currentScope => _currentScope;
  String get currentScopeId => _currentScopeId;

  ChatProvider({ChatApiService? apiService}) {
    _apiService = apiService ?? ChatApiService(baseUrl: _baseUrl);
    _initWelcomeMessage();
    checkServerHealth();
  }

  void updateScope({required String scope, required String id}) {
    if (_currentScope == scope && _currentScopeId == id) return;
    _currentScope = scope;
    _currentScopeId = id;
    notifyListeners();
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
        text: 'Xin chào, tôi là Trợ lý AI môn học FLM.\n\n'
            'Tôi có thể giải đáp thông tin và tư vấn chiến lược học tập theo đúng ngữ cảnh bạn đang xem:\n'
            '• Hình thức thi và cấu trúc đánh giá môn học (PE/FE)\n'
            '• Mục tiêu và chuẩn đầu ra môn học (LOs)\n'
            '• Số tín chỉ, môn tiên quyết và kế hoạch học tập\n'
            '• Phương pháp học và chiến lược ôn thi',
        sender: ChatSender.ai,
        timestamp: DateTime.now(),
        status: MessageStatus.success,
        sources: ['FLM Knowledge Base'],
      ),
    );
  }

  Future<void> checkServerHealth() async {
    _isServerOnline = null;
    notifyListeners();

    final isOnline = await _apiService.checkHealth();
    _isServerOnline = isOnline;
    notifyListeners();
  }

  Future<void> sendPrompt(String text, {String? scope, String? id}) async {
    final prompt = text.trim();
    if (prompt.isEmpty || _isLoading) return;

    final activeScope = scope ?? _currentScope;
    final activeId = id ?? _currentScopeId;

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

    // Call API Service with scope & id
    final result = await _apiService.sendMessage(
      prompt,
      scope: activeScope,
      id: activeId,
    );

    // Update AI Message
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
