import 'package:flutter_test/flutter_test.dart';
import 'package:flm_courses/features/chat/models/chat_message.dart';
import 'package:flm_courses/features/chat/services/chat_api_service.dart';
import 'package:flm_courses/features/chat/providers/chat_provider.dart';

void main() {
  group('ChatMessage Model Tests', () {
    test('ChatMessage json serialization & copyWith', () {
      final msg = ChatMessage(
        id: 'msg_1',
        text: 'Môn PRM392 thi PE không?',
        sender: ChatSender.user,
        timestamp: DateTime(2026, 9, 15, 14, 0),
        status: MessageStatus.success,
      );

      final json = msg.toJson();
      expect(json['id'], equals('msg_1'));
      expect(json['sender'], equals('user'));

      final restored = ChatMessage.fromJson(json);
      expect(restored.text, equals(msg.text));
      expect(restored.sender, equals(ChatSender.user));
    });
  });

  group('ChatApiService Error Handling Tests', () {
    test('sendMessage returns clear error message when server is unreachable', () async {
      final service = ChatApiService(baseUrl: 'http://invalid-unreachable-host:9999');
      final result = await service.sendMessage('Môn PRM392 có thi PE hay không?');

      expect(result.isOfflineFallback, isFalse);
      expect(result.answer, contains('Không thể kết nối đến AI Server Backend'));
      expect(result.errorMessage, isNotNull);
    });
  });

  group('ChatProvider State Tests', () {
    test('ChatProvider initializes with welcome message', () {
      final provider = ChatProvider();
      expect(provider.messages.isNotEmpty, isTrue);
      expect(provider.messages.first.sender, equals(ChatSender.ai));
    });

    test('ChatProvider sendPrompt adds user message and AI response', () async {
      final provider = ChatProvider(
        apiService: ChatApiService(baseUrl: 'http://invalid-unreachable-host:9999'),
      );

      await provider.sendPrompt('Môn PRM392 thi PE không?');
      expect(provider.messages.length, greaterThanOrEqualTo(3));
      
      final lastMsg = provider.messages.last;
      expect(lastMsg.sender, equals(ChatSender.ai));
    });
  });
}
