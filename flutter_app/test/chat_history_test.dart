import 'package:flm_courses/features/chat/providers/chat_provider.dart';
import 'package:flm_courses/features/chat/services/chat_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeChatApiService extends ChatApiService {
  _FakeChatApiService() : super(baseUrl: 'http://localhost:8000');

  @override
  Future<bool> checkHealth() async => true;

  @override
  Future<ChatResponseResult> sendMessage(
    String prompt, {
    String? scope,
    String? id,
    String? courseCode,
    Map<String, dynamic>? studentContext,
    List<Map<String, String>> history = const [],
  }) async => ChatResponseResult(
    answer: 'Trả lời cho $id',
    sources: const [],
    isOfflineFallback: false,
  );
}

void main() {
  test('advice history is saved and separated by course scope', () async {
    SharedPreferences.setMockInitialValues({});
    final first = ChatProvider(apiService: _FakeChatApiService());
    await Future<void>.delayed(Duration.zero);
    first.updateScope(scope: 'subject', id: 'PRM393');
    await first.sendPrompt('Cách học PRM393?');
    expect(first.messages.last.text, 'Trả lời cho PRM393');

    first.updateScope(scope: 'subject', id: 'PRO192');
    expect(first.messages.length, 1);
    await first.sendPrompt('Cách học PRO192?');
    expect(first.messages.last.text, 'Trả lời cho PRO192');

    first.updateScope(scope: 'subject', id: 'PRM393');
    expect(first.messages.last.text, 'Trả lời cho PRM393');
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final reopened = ChatProvider(apiService: _FakeChatApiService());
    await Future<void>.delayed(const Duration(milliseconds: 10));
    reopened.updateScope(scope: 'subject', id: 'PRO192');
    expect(reopened.messages.last.text, 'Trả lời cho PRO192');
  });

  test('new advice session preserves and restores the previous conversation', () async {
    SharedPreferences.setMockInitialValues({});
    final chat = ChatProvider(apiService: _FakeChatApiService());
    await Future<void>.delayed(Duration.zero);
    chat.updateScope(scope: 'subject', id: 'PRM393');
    await chat.sendPrompt('Cách học PRM393?');
    final firstId = chat.sessions.single.id;
    expect(chat.sessions.single.category, 'Chiến lược học');

    chat.startNewSession();
    expect(chat.messages.length, 1);
    await chat.sendPrompt('Điều kiện học PRM393?');
    expect(chat.sessions.length, 2);
    chat.openSession(firstId);
    expect(chat.messages.any((message) => message.text == 'Cách học PRM393?'), isTrue);
    expect(chat.messages.any((message) => message.text == 'Điều kiện học PRM393?'), isFalse);

    await Future<void>.delayed(const Duration(milliseconds: 10));
    final reopened = ChatProvider(apiService: _FakeChatApiService());
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(reopened.sessions.length, 2);
  });

  test('opening archived subject session keeps another active subject session', () async {
    SharedPreferences.setMockInitialValues({});
    final chat = ChatProvider(apiService: _FakeChatApiService());
    await Future<void>.delayed(Duration.zero);
    chat.updateScope(scope: 'subject', id: 'PRM393');
    await chat.sendPrompt('Cách học phiên đầu?');
    final oldId = chat.sessions.single.id;
    chat.startNewSession();
    await chat.sendPrompt('Cách học phiên mới?');
    chat.updateScope(scope: 'curriculum', id: 'BIT_SE_K19B');
    await chat.sendPrompt('Tổng quan?');
    chat.openSession(oldId);
    expect(chat.sessions.length, 3);
    expect(chat.messages.any((m) => m.text == 'Cách học phiên đầu?'), isTrue);
    expect(chat.sessions.any((s) => s.title == 'Cách học phiên mới?'), isTrue);
  });
}
