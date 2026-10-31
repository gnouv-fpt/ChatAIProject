import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../data/personal_preferences.dart';
import '../../../data/activity_repository.dart';
import '../../../services/app_telemetry.dart';

import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../services/chat_api_service.dart';
import '../../../services/grade_import_service.dart';
import '../../../state/learning_profile_provider.dart';

class ChatProvider extends ChangeNotifier {
  static const _historyKey = 'flm_chat_history_v1';
  static const _sessionsKey = 'flm_chat_sessions_v1';
  static const _maxTurnsPerSession = 20;
  static const _idleSessionLimit = Duration(hours: 6);
  static const _newDayIdleLimit = Duration(hours: 1);
  late ChatApiService _apiService;
  final PersonalPreferences _storage;
  final LearningProfileProvider? profile;
  final ActivityRepository? historyRepository;
  final AppTelemetry? telemetry;
  final DateTime Function() _clock;
  late final Future<void> historyReady;
  String? historyError;
  bool _cloudLoaded = false;
  bool _disposed = false;
  Future<void> _cloudWrites = Future.value();
  final Map<String, String> _synced = {};

  final List<ChatMessage> _messages = [];
  final Map<String, List<ChatMessage>> _scopeMessages = {};
  final Map<String, String> _activeSessionIds = {};
  final List<ChatSession> _archivedSessions = [];
  int _sessionSequence = 0;
  String? _manuallyOpenedSessionId;
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
  bool get historyAvailable => historyRepository == null || _cloudLoaded;
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
  String _apiScopeId(String scope, String id) =>
      scope == 'curriculum' ? id.split(':').first : id;
  int? _viewedSemester(String scope, String id) {
    if (scope != 'curriculum') return null;
    final match = RegExp(r':semester-(\d+)$').firstMatch(id);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  String _newSessionId() =>
      '${_clock().microsecondsSinceEpoch}_${++_sessionSequence}';

  bool _needsFreshSession(List<ChatMessage> messages) {
    final userTurns = messages.where((m) => m.sender == ChatSender.user).length;
    if (userTurns == 0) return false;
    if (userTurns >= _maxTurnsPerSession) return true;
    final last = messages.last.timestamp.toLocal();
    final now = _clock().toLocal();
    final idle = now.difference(last);
    if (idle >= _idleSessionLimit) return true;
    return (last.year != now.year ||
            last.month != now.month ||
            last.day != now.day) &&
        idle >= _newDayIdleLimit;
  }

  void _refreshSessionForScope(String key) {
    final messages = key == _scopeKey ? _messages : _scopeMessages[key];
    if (messages == null ||
        (_manuallyOpenedSessionId != null &&
            _manuallyOpenedSessionId == _activeSessionIds[key]) ||
        !_needsFreshSession(messages)) {
      return;
    }
    _archiveScope(key, messages: messages);
    _activeSessionIds[key] = _newSessionId();
    if (key == _scopeKey) {
      _messages.clear();
      _initWelcomeMessage();
      _scopeMessages[key] = List.of(_messages);
    }
  }

  List<ChatSession> get sessions {
    final active = _scopeMessages.entries
        .map((entry) {
          final separator = entry.key.indexOf(':');
          return ChatSession(
            id: _activeSessionIds.putIfAbsent(entry.key, _newSessionId),
            scope: entry.key.substring(0, separator),
            scopeId: entry.key.substring(separator + 1),
            messages: entry.key == _scopeKey ? List.of(_messages) : entry.value,
          );
        })
        .where(
          (session) => session.messages.any((m) => m.sender == ChatSender.user),
        );
    final current = ChatSession(
      id: _activeSessionIds.putIfAbsent(_scopeKey, _newSessionId),
      scope: _currentScope,
      scopeId: _currentScopeId,
      messages: List.of(_messages),
    );
    final items = <ChatSession>[
      if (!_scopeMessages.containsKey(_scopeKey) &&
          current.messages.any((m) => m.sender == ChatSender.user))
        current,
      ...active,
      ..._archivedSessions,
    ];
    items.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
    return List.unmodifiable(items);
  }

  void startNewSession() {
    if (_isLoading) return;
    _manuallyOpenedSessionId = null;
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
    final archivedIndex = _archivedSessions.indexWhere(
      (s) => s.id == sessionId,
    );
    if (archivedIndex >= 0) {
      final selected = _archivedSessions.removeAt(archivedIndex);
      _archiveCurrent();
      final targetKey = '${selected.scope}:${selected.scopeId}';
      if (targetKey != _scopeKey) _archiveScope(targetKey);
      _currentScope = selected.scope;
      _currentScopeId = selected.scopeId;
      _activeSessionIds[_scopeKey] = selected.id;
      _messages
        ..clear()
        ..addAll(selected.messages);
      _scopeMessages[_scopeKey] = List.of(_messages);
    } else {
      final scopeKey = _activeSessionIds.entries
          .where((entry) => entry.value == sessionId)
          .map((entry) => entry.key)
          .firstOrNull;
      if (scopeKey == null) return;
      if (scopeKey == _scopeKey) {
        _manuallyOpenedSessionId = sessionId;
        return;
      }
      _scopeMessages[_scopeKey] = List.of(_messages);
      final separator = scopeKey.indexOf(':');
      _currentScope = scopeKey.substring(0, separator);
      _currentScopeId = scopeKey.substring(separator + 1);
      _messages
        ..clear()
        ..addAll(_scopeMessages[scopeKey] ?? []);
    }
    _lastError = null;
    _manuallyOpenedSessionId = sessionId;
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
    _archivedSessions.add(
      ChatSession(
        id: id,
        scope: key.substring(0, separator),
        scopeId: key.substring(separator + 1),
        messages: List.of(saved),
      ),
    );
    _scopeMessages.remove(key);
    _activeSessionIds.remove(key);
  }

  ChatProvider({
    ChatApiService? apiService,
    this.profile,
    this.historyRepository,
    this.telemetry,
    PersonalPreferences? storage,
    DateTime Function()? clock,
  }) : _storage = storage ?? PersonalPreferences(),
       _clock = clock ?? DateTime.now {
    _apiService = apiService ?? ChatApiService(baseUrl: _baseUrl);
    _initWelcomeMessage();
    historyReady = _loadHistory();
    checkServerHealth();
  }

  void updateScope({required String scope, required String id}) {
    if (_currentScope == scope && _currentScopeId == id) {
      _refreshSessionForScope(_scopeKey);
      notifyListeners();
      unawaited(_persistHistory());
      return;
    }
    _scopeMessages[_scopeKey] = List<ChatMessage>.from(_messages);
    _manuallyOpenedSessionId = null;
    _refreshSessionForScope('$scope:$id');
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
      if (historyRepository != null) {
        final saved = await historyRepository!.loadSessions();
        if (_disposed) return;
        for (final session in saved) {
          final key = '${session.scope}:${session.scopeId}';
          _activeSessionIds.putIfAbsent(key, () => session.id);
          if (_activeSessionIds[key] == session.id) {
            _scopeMessages[key] = List.of(session.messages);
          } else {
            _archivedSessions.add(session);
          }
          _synced[session.id] = jsonEncode(session.toJson());
        }
        if (_scopeMessages.containsKey(_scopeKey)) {
          _messages
            ..clear()
            ..addAll(_scopeMessages[_scopeKey]!);
        }
        _cloudLoaded = true;
        historyError = null;
        notifyListeners();
        return;
      }
      final prefs = await _storage.open();
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
        _activeSessionIds.addAll(
          Map<String, String>.from(decoded['active_ids'] as Map),
        );
        _archivedSessions.addAll(
          (decoded['archived'] as List<dynamic>).map(
            (row) => ChatSession.fromJson(row as Map<String, dynamic>),
          ),
        );
      }
      if (_messages.length == 1 && _scopeMessages.containsKey(_scopeKey)) {
        _messages
          ..clear()
          ..addAll(_scopeMessages[_scopeKey]!);
        notifyListeners();
      }
    } catch (error) {
      historyError =
          'Chưa tải được lịch sử. Kiểm tra mạng và thử lại trước khi chat.';
      if (!_disposed) notifyListeners();
      debugPrint('[ChatProvider] History load: ${error.runtimeType}');
    }
  }

  Future<void> _persistHistory() async {
    try {
      _scopeMessages[_scopeKey] = _messages
          .where((message) => message.status != MessageStatus.sending)
          .toList();
      if (historyRepository != null) {
        if (!_cloudLoaded || _disposed) return;
        final snapshot = sessions
            .where((s) => s.messages.any((m) => m.sender == ChatSender.user))
            .toList();
        final write = _cloudWrites.then((_) async {
          if (_disposed) return;
          for (final session in snapshot) {
            if (_disposed) return;
            final signature = jsonEncode(session.toJson());
            if (_synced[session.id] == signature) continue;
            await historyRepository!.saveSession(session);
            _synced[session.id] = signature;
          }
        });
        _cloudWrites = write.catchError((Object _) {});
        await write;
        historyError = null;
        if (!_disposed) notifyListeners();
        return;
      }
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
      final prefs = await _storage.open();
      await prefs.setString(_historyKey, encoded);
      await prefs.setString(
        _sessionsKey,
        jsonEncode({
          'active_ids': _activeSessionIds,
          'archived': _archivedSessions
              .map((session) => session.toJson())
              .toList(),
        }),
      );
    } catch (error) {
      historyError = 'Chưa đồng bộ lịch sử. Tin nhắn vẫn còn trong phiên; thử đồng bộ lại.';
      if (!_disposed) notifyListeners();
      debugPrint('[ChatProvider] History save: ${error.runtimeType}');
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
        timestamp: _clock(),
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
    String? backendId,
    String? contextHint,
    Map<String, dynamic>? studentContext,
  }) async {
    final prompt = text.trim();
    if (prompt.isEmpty || _isLoading) return;
    await historyReady;
    if (_disposed || (historyRepository != null && !_cloudLoaded)) return;
    if (profile != null && !profile!.isLoaded) await profile!.load();

    final activeScope = scope ?? _currentScope;
    final activeId = id ?? _currentScopeId;
    final viewedSemester = _viewedSemester(activeScope, activeId);
    final effectiveHint =
        contextHint ??
        (viewedSemester == null ? null : 'Học kỳ $viewedSemester');
    final targetScopeKey = '$activeScope:$activeId';
    _refreshSessionForScope(targetScopeKey);

    final timestamp = _clock();
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
    final loadingAiMessage = ChatMessage(
      id: aiMsgId,
      text: 'Đang tra cứu dữ liệu FLM...',
      sender: ChatSender.ai,
      timestamp: _clock(),
      status: MessageStatus.sending,
    );

    if (_scopeKey == targetScopeKey) {
      _messages.add(userMessage);
      _messages.add(loadingAiMessage);
    }
    final targetList = _scopeMessages.putIfAbsent(targetScopeKey, () => []);
    if (!targetList.any((m) => m.id == userMsgId)) {
      targetList.add(userMessage);
    }
    if (!targetList.any((m) => m.id == aiMsgId)) {
      targetList.add(loadingAiMessage);
    }

    _isLoading = true;
    unawaited(
      telemetry?.event('advising_request', {
            'scope': activeScope,
            'has_profile': profile?.chatContext.isNotEmpty == true ? 1 : 0,
          }) ??
          Future.value(),
    );
    _lastError = null;
    notifyListeners();

    // Call API Service with scope, id, and student_context facts (Mục 7.4)
    final historyMessages = _scopeKey == targetScopeKey
        ? _messages
        : targetList;
    final contextFacts = {...?profile?.chatContext, ...?studentContext};
    if (viewedSemester != null) {
      contextFacts['target_semester'] = viewedSemester;
    }
    final result = await _apiService.sendMessage(
      effectiveHint == null
          ? prompt
          : 'Ngữ cảnh đang xem: $effectiveHint. Câu hỏi: $prompt',
      scope: activeScope,
      id: backendId ?? _apiScopeId(activeScope, activeId),
      studentContext: contextFacts,
      history: historyMessages
          .where((message) =>
              message.status != MessageStatus.sending &&
              message.id != 'welcome_msg')
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
    if (_disposed) return;

    final finalAiMessage = ChatMessage(
      id: aiMsgId,
      text: result.answer,
      sender: ChatSender.ai,
      timestamp: _clock(),
      status: result.errorMessage != null
          ? MessageStatus.error
          : result.isOfflineFallback
          ? MessageStatus.offlineFallback
          : MessageStatus.success,
      sources: result.sources,
      errorMessage: result.errorMessage,
    );

    // Update AI Message
    if (_scopeKey == targetScopeKey) {
      final index = _messages.indexWhere((m) => m.id == aiMsgId);
      if (index != -1) {
        _messages[index] = finalAiMessage;
      } else {
        _messages.add(finalAiMessage);
      }
    }

    final currentTargetList = _scopeMessages[targetScopeKey];
    if (currentTargetList != null) {
      final targetIdx = currentTargetList.indexWhere((m) => m.id == aiMsgId);
      if (targetIdx != -1) {
        currentTargetList[targetIdx] = finalAiMessage;
      } else {
        currentTargetList.add(finalAiMessage);
      }
    } else {
      _scopeMessages[targetScopeKey] = [userMessage, finalAiMessage];
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
    String? backendId,
    String? contextHint,
    Map<String, dynamic>? studentContext,
  }) async {
    final prompt = text.trim();
    if (prompt.isEmpty || images.isEmpty || _isLoading) return;
    await historyReady;
    if (_disposed || (historyRepository != null && !_cloudLoaded)) return;

    final activeScope = scope ?? _currentScope;
    final activeId = id ?? _currentScopeId;
    final viewedSemester = _viewedSemester(activeScope, activeId);
    final effectiveHint =
        contextHint ??
        (viewedSemester == null ? null : 'Học kỳ $viewedSemester');
    final targetScopeKey = '$activeScope:$activeId';
    _refreshSessionForScope(targetScopeKey);

    final timestamp = _clock();
    final userMsgId = 'user_${timestamp.millisecondsSinceEpoch}';
    final aiMsgId = 'ai_${timestamp.millisecondsSinceEpoch}';

    final userMessage = ChatMessage(
      id: userMsgId,
      text: '📎 ${images.length} ảnh\n$prompt',
      sender: ChatSender.user,
      timestamp: timestamp,
    );
    final loadingAiMessage = ChatMessage(
      id: aiMsgId,
      text: 'Đang đọc ảnh và xử lý prompt...',
      sender: ChatSender.ai,
      timestamp: _clock(),
      status: MessageStatus.sending,
    );

    if (_scopeKey == targetScopeKey) {
      _messages.add(userMessage);
      _messages.add(loadingAiMessage);
    }
    final targetList = _scopeMessages.putIfAbsent(targetScopeKey, () => []);
    if (!targetList.any((m) => m.id == userMsgId)) {
      targetList.add(userMessage);
    }
    if (!targetList.any((m) => m.id == aiMsgId)) {
      targetList.add(loadingAiMessage);
    }

    _isLoading = true;
    _lastError = null;
    notifyListeners();

    final result = await _apiService.sendMessageWithImages(
      effectiveHint == null
          ? prompt
          : 'Ngữ cảnh đang xem: $effectiveHint. Câu hỏi: $prompt',
      images,
      scope: activeScope,
      id: backendId ?? _apiScopeId(activeScope, activeId),
      courseCode: activeScope == 'subject' ? backendId ?? activeId : null,
      studentContext: {
        ...?profile?.chatContext,
        ...?studentContext,
        ...?(viewedSemester == null
            ? null
            : {'target_semester': viewedSemester}),
      },
    );
    if (_disposed) return;

    final finalAiMessage = ChatMessage(
      id: aiMsgId,
      text: result.answer,
      sender: ChatSender.ai,
      timestamp: _clock(),
      status: result.errorMessage == null
          ? MessageStatus.success
          : MessageStatus.error,
      sources: result.sources,
      errorMessage: result.errorMessage,
    );

    if (_scopeKey == targetScopeKey) {
      final index = _messages.indexWhere((message) => message.id == aiMsgId);
      if (index != -1) {
        _messages[index] = finalAiMessage;
      } else {
        _messages.add(finalAiMessage);
      }
    }

    final currentTargetList = _scopeMessages[targetScopeKey];
    if (currentTargetList != null) {
      final targetIdx = currentTargetList.indexWhere((m) => m.id == aiMsgId);
      if (targetIdx != -1) {
        currentTargetList[targetIdx] = finalAiMessage;
      } else {
        currentTargetList.add(finalAiMessage);
      }
    } else {
      _scopeMessages[targetScopeKey] = [userMessage, finalAiMessage];
    }

    _isLoading = false;
    _lastError = result.errorMessage;
    notifyListeners();
    unawaited(_persistHistory());
  }

  Future<void> clearHistory() async {
    if (_isLoading) return;
    await historyReady;
    if (historyRepository != null && !_cloudLoaded) return;
    final previousId = _activeSessionIds[_scopeKey];
    if (historyRepository != null && previousId != null) {
      try {
        await _cloudWrites;
        if (_disposed) return;
        await historyRepository!.deleteSession(previousId);
      } catch (_) {
        historyError = 'Chưa xóa được lịch sử trên cloud. Vui lòng thử lại.';
        notifyListeners();
        return;
      }
      _synced.remove(previousId);
      _activeSessionIds[_scopeKey] = _newSessionId();
    }
    if (_disposed) return;
    _messages.clear();
    _initWelcomeMessage();
    _scopeMessages.remove(_scopeKey);
    notifyListeners();
    unawaited(_persistHistory());
  }

  Future<void> retryHistorySync() async {
    if (!_cloudLoaded && historyRepository != null) {
      await _loadHistory();
    } else {
      await _persistHistory();
    }
  }

  void _notify() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void notifyListeners() => _notify();
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
