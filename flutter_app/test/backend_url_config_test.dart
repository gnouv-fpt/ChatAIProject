import 'package:flm_courses/features/chat/providers/chat_provider.dart';
import 'package:flm_courses/features/chat/services/chat_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeChatApi extends Fake implements ChatApiService {
  @override
  Future<bool> checkHealth() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Backend URL configuration & precedence tests', () {
    test('Default URL in debug mode is localhost or 10.0.2.2', () {
      SharedPreferences.setMockInitialValues({});
      final chat = ChatProvider(apiService: _FakeChatApi());
      addTearDown(chat.dispose);

      expect(chat.baseUrl, isNotEmpty);
      expect(
        chat.baseUrl.contains('localhost') || chat.baseUrl.contains('10.0.2.2'),
        isTrue,
      );
    });

    test('updateBaseUrl saves custom URL in debug mode', () async {
      SharedPreferences.setMockInitialValues({});
      final chat = ChatProvider(apiService: _FakeChatApi());
      addTearDown(chat.dispose);

      chat.updateBaseUrl('http://192.168.1.50:8000');
      expect(chat.baseUrl, 'http://192.168.1.50:8000');

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('flm_custom_base_url'), 'http://192.168.1.50:8000');
    });

    test('ChatProvider restores custom URL from SharedPreferences in debug mode', () async {
      SharedPreferences.setMockInitialValues({
        'flm_custom_base_url': 'http://192.168.1.99:8000',
      });

      final chat = ChatProvider(apiService: _FakeChatApi());
      addTearDown(chat.dispose);

      // Allow async _initBaseUrl to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(chat.baseUrl, 'http://192.168.1.99:8000');
    });
  });
}
