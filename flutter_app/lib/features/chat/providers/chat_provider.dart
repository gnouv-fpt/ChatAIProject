import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../services/chat_api_service.dart';
import '../../../services/grade_import_service.dart';
import '../../../state/learning_profile_provider.dart';

class ChatProvider extends ChangeNotifier {
  static const _historyKey = 'flm_chat_history_v1';
  static const _sessionsKey = 'flm_chat_sessions_v1';
  late ChatApiService _apiService;
  final LearningProfileProvider? profile;

  final List<ChatMessage> _messages = [];
  final Map<String, List<ChatMessage>> _scopeMessages = {};
  final Map<String, String> _activeSessionIds = {};
  final List<ChatSession> _archivedSessions = [];
  int _sessionSequence = 0;
  bool _isLoading = false;
  bool? _isServerOnline;
  String _baseUrl = _defaultBaseUrl();

  static String _defaultBaseUrl() {
    const configured = String.fromEnvironment('FLM_API_BASE_URL');
    if (configured.isNotEmpty) return configured;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  String? _lastError;
  String _currentScope = 'curriculum';
  String _currentScopeId = 'BIT_SE_K19B';

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool? get isServerOnline => _isServerOnline;
  String get baseUrl => _baseUrl;
  String? get lastError => _lastError;
  bool get canRetryLastFailed =>
      _messages.length >= 2 &&
      _messages.last.status == MessageStatus.error &&
      _messages[_messages.length - 2].sender == ChatSender.user &&
      !_messages[_messages.length - 2].text.startsWith('📎');
  String get currentScope => _currentScope;
  String get currentScopeId => _currentScopeId;
  String get _scopeKey => '$_currentScope:$_currentScopeId';
  String _newSessionId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${++_sessionSequence}';

  List<ChatSession> get sessions {
    final active = _scopeMessages.entries.map((entry) {
      final separator = entry.key.indexOf(':');
      return ChatSession(
        id: _activeSessionIds.putIfAbsent(entry.key, _newSessionId),
        scope: entry.key.substring(0, separator),
        scopeId: entry.key.substring(separator + 1),
        messages: entry.key == _scopeKey ? List.of(_messages) : entry.value,
      );
    }).where((session) => session.messages.any((m) => m.sender == ChatSender.user));
    final current = ChatSession(
      id: _activeSessionIds.putIfAbsent(_scopeKey, _newSessionId),
      scope: _currentScope,
      scopeId: _currentScopeId,
      messages: List.of(_messages),
    );
    final items = <ChatSession>[
      if (!_scopeMessages.containsKey(_scopeKey) &&
          current.messages.any((m) => m.sender == ChatSender.user)) current,
      ...active,
      ..._archivedSessions,
    ];
    return List.unmodifiable(items.reversed);
  }

  void startNewSession() {
    if (_isLoading) return;
    _archiveCurrent();
    _activeSessionIds[_scopeKey] = _newSessionId();
    _messages.clear();
    _initWelcomeMessage();
    _scopeMessages[_scopeKey] = List.of(_messages);
    notifyListeners();
    unawaited(_persistHistory());
  }

  void openSession(String sessionId) {
    if (_isLoading) return;
    final archivedIndex = _archivedSessions.indexWhere((s) => s.id == sessionId);
    if (archivedIndex >= 0) {
      final selected = _archivedSessions.removeAt(archivedIndex);
      _archiveCurrent();
      final targetKey = '${selected.scope}:${selected.scopeId}';
      if (targetKey != _scopeKey) _archiveScope(targetKey);
      _currentScope = selected.scope;
      _currentScopeId = selected.scopeId;
      _activeSessionIds[_scopeKey] = selected.id;
      _messages..clear()..addAll(selected.messages);
      _scopeMessages[_scopeKey] = List.of(_messages);
    } else {
      final scopeKey = _activeSessionIds.entries
          .where((entry) => entry.value == sessionId)
          .map((entry) => entry.key)
          .firstOrNull;
      if (scopeKey == null || scopeKey == _scopeKey) return;
      _scopeMessages[_scopeKey] = List.of(_messages);
      final separator = scopeKey.indexOf(':');
      _currentScope = scopeKey.substring(0, separator);
      _currentScopeId = scopeKey.substring(separator + 1);
      _messages..clear()..addAll(_scopeMessages[scopeKey] ?? []);
    }
    _lastError = null;
    notifyListeners();
    unawaited(_persistHistory());
  }

  void _archiveCurrent() {
    _archiveScope(_scopeKey, messages: _messages);
  }

  void _archiveScope(String key, {List<ChatMessage>? messages}) {
    final saved = messages ?? _scopeMessages[key] ?? const [];
    if (!saved.any((message) => message.sender == ChatSender.user)) return;
    final separator = key.indexOf(':');
    final id = _activeSessionIds.putIfAbsent(key, _newSessionId);
    _archivedSessions.removeWhere((session) => session.id == id);
    _archivedSessions.add(ChatSession(
      id: id,
      scope: key.substring(0, separator),
      scopeId: key.substring(separator + 1),
      messages: List.of(saved),
    ));
    _scopeMessages.remove(key);
    _activeSessionIds.remove(key);
  }

  ChatProvider({ChatApiService? apiService, this.profile}) {
    _apiService = apiService ?? ChatApiService(baseUrl: _baseUrl);
    _initWelcomeMessage();
    unawaited(_loadHistory());
    checkServerHealth();
  }

  void updateScope({required String scope, required String id}) {
    if (_currentScope == scope && _currentScopeId == id) return;
    _scopeMessages[_scopeKey] = List<ChatMessage>.from(_messages);
    _currentScope = scope;
    _currentScopeId = id;
    _activeSessionIds.putIfAbsent(_scopeKey, _newSessionId);
    _messages
      ..clear()
      ..addAll(_scopeMessages[_scopeKey] ?? []);
    if (_messages.isEmpty) _initWelcomeMessage();
    notifyListeners();
    unawaited(_persistHistory());
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          final rows = entry.value as List<dynamic>;
          _scopeMessages[entry.key] = rows
              .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
              .where((message) => message.status != MessageStatus.sending)
              .toList();
        }
      }
      final sessionsRaw = prefs.getString(_sessionsKey);
      if (sessionsRaw != null) {
        final decoded = jsonDecode(sessionsRaw) as Map<String, dynamic>;
        _activeSessionIds.addAll(Map<String, String>.from(decoded['active_ids'] as Map));
        _archivedSessions.addAll((decoded['archived'] as List<dynamic>)
            .map((row) => ChatSession.fromJson(row as Map<String, dynamic>)));
      }
      if (_messages.length == 1 && _scopeMessages.containsKey(_scopeKey)) {
        _messages
          ..clear()
          ..addAll(_scopeMessages[_scopeKey]!);
        notifyListeners();
      }
    } catch (error) {
      debugPrint('[ChatProvider] Failed to load history: $error');
    }
  }

  Future<void> _persistHistory() async {
    try {
      _scopeMessages[_scopeKey] = _messages
          .where((message) => message.status != MessageStatus.sending)
          .toList();
      final encoded = jsonEncode(
        _scopeMessages.map(
          (scope, messages) => MapEntry(
            scope,
            messages.reversed
                .take(100)
                .toList()
                .reversed
                .map((message) => message.toJson())
                .toList(),
          ),
        ),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_historyKey, encoded);
      await prefs.setString(_sessionsKey, jsonEncode({
        'active_ids': _activeSessionIds,
        'archived': _archivedSessions.map((session) => session.toJson()).toList(),
      }));
    } catch (error) {
      debugPrint('[ChatProvider] Failed to save history: $error');
    }
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
        text:
            'Xin chào, tôi là Trợ lý AI môn học FLM.\n\n'
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

  Future<void> sendPrompt(
    String text, {
    String? scope,
    String? id,
    Map<String, dynamic>? studentContext,
  }) async {
    final prompt = text.trim();
    if (prompt.isEmpty || _isLoading) return;
    if (profile != null && !profile!.isLoaded) await profile!.load();

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

    // Call API Service with scope, id, and student_context facts (Mục 7.4)
    final result = await _apiService.sendMessage(
      prompt,
      scope: activeScope,
      id: activeId,
      studentContext: {...?studentContext, ...?profile?.chatContext},
      history: _messages
          .where((message) => message.status != MessageStatus.sending)
          .toList()
          .reversed
          .skip(1)
          .take(8)
          .toList()
          .reversed
          .map(
            (message) => {
              'role': message.sender == ChatSender.user ? 'user' : 'assistant',
              'content': message.text,
            },
          )
          .toList(),
    );

    // Update AI Message
    final index = _messages.indexWhere((m) => m.id == aiMsgId);
    if (index != -1) {
      _messages[index] = ChatMessage(
        id: aiMsgId,
        text: result.answer,
        sender: ChatSender.ai,
        timestamp: DateTime.now(),
        status: result.errorMessage != null
            ? MessageStatus.error
            : result.isOfflineFallback
            ? MessageStatus.offlineFallback
            : MessageStatus.success,
        sources: result.sources,
        errorMessage: result.errorMessage,
      );
    }

    _isLoading = false;
    _isServerOnline = result.errorMessage == null && !result.isOfflineFallback;
    _lastError = result.errorMessage;
    notifyListeners();
    unawaited(_persistHistory());
  }

  Future<void> retryLastFailed({Map<String, dynamic>? studentContext}) async {
    if (_isLoading || !canRetryLastFailed) return;
    final user = _messages[_messages.length - 2];
    _messages.removeLast();
    _messages.removeLast();
    await sendPrompt(user.text, studentContext: studentContext);
  }

  Future<void> sendPromptWithImages(
    String text,
    List<ImageFile> images, {
    String? scope,
    String? id,
  }) async {
    final prompt = text.trim();
    if (prompt.isEmpty || images.isEmpty || _isLoading) return;

    final timestamp = DateTime.now();
    final userMsgId = 'user_${timestamp.millisecondsSinceEpoch}';
    final aiMsgId = 'ai_${timestamp.millisecondsSinceEpoch}';
    _messages.add(
      ChatMessage(
        id: userMsgId,
        text: '📎 ${images.length} ảnh\n$prompt',
        sender: ChatSender.user,
        timestamp: timestamp,
      ),
    );
    _messages.add(
      ChatMessage(
        id: aiMsgId,
        text: 'Đang đọc ảnh và xử lý prompt...',
        sender: ChatSender.ai,
        timestamp: DateTime.now(),
        status: MessageStatus.sending,
      ),
    );
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    final result = await _apiService.sendMessageWithImages(
      prompt,
      images,
      scope: scope ?? _currentScope,
      id: id ?? _currentScopeId,
      courseCode: scope == 'subject' ? (id ?? _currentScopeId) : null,
    );

    final index = _messages.indexWhere((message) => message.id == aiMsgId);
    if (index != -1) {
      _messages[index] = ChatMessage(
        id: aiMsgId,
        text: result.answer,
        sender: ChatSender.ai,
        timestamp: DateTime.now(),
        status: result.errorMessage == null
            ? MessageStatus.success
            : MessageStatus.error,
        sources: result.sources,
        errorMessage: result.errorMessage,
      );
    }
    _isLoading = false;
    _lastError = result.errorMessage;
    notifyListeners();
    unawaited(_persistHistory());
  }

  void clearHistory() {
    _messages.clear();
    _initWelcomeMessage();
    _scopeMessages.remove(_scopeKey);
    notifyListeners();
    unawaited(_persistHistory());
  }
}
