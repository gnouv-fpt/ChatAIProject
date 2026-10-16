import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flm_courses/features/chat/services/chat_api_service.dart';
import 'package:flm_courses/features/chat/providers/chat_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RealHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context);
  }
}

void main() {
  HttpOverrides.global = RealHttpOverrides();
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Live Flutter-to-Backend Integration Test', () {
    late ChatApiService apiService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      apiService = ChatApiService(baseUrl: 'http://127.0.0.1:8000');
    });

    test('1. Backend health check from Flutter', () async {
      final isHealthy = await apiService.checkHealth();
      print('[Flutter Test] Backend Health: $isHealthy');
      expect(isHealthy, isTrue, reason: 'Backend must be running at http://127.0.0.1:8000');
    });

    test('2. Live Query with Student Context & Groq RAG from Flutter ChatApiService', () async {
      print('\n[Flutter Test] Sending Question 1 from Flutter...');
      final stopwatch = Stopwatch()..start();

      final result = await apiService.sendMessage(
        'GPA hiện tại của tôi là 7.4, muốn ra trường 8.0 loại Giỏi thì kỳ 5 này có môn SWP391 và PRN212 tôi nên phân bổ chiến lược ra sao?',
        scope: 'curriculum',
        id: 'BIT_SE_K19B',
        studentContext: {
          'current_gpa': 7.4,
          'target_gpa': 8.0,
          'required_avg_mark': 8.45,
          'retake_count': 1,
          'current_semester': 5,
        },
      );

      stopwatch.stop();
      print('[Flutter Test] Response received in ${stopwatch.elapsedMilliseconds}ms');
      print('[Flutter Test] Error Message: ${result.errorMessage}');
      print('[Flutter Test] Sources: ${result.sources}');
      print('[Flutter Test] Answer Length: ${result.answer.length}');
      print('[Flutter Test] Answer Preview: ${result.answer.substring(0, result.answer.length > 300 ? 300 : result.answer.length)}...\n');

      expect(result.errorMessage, isNull);
      expect(result.answer, isNotEmpty);
      expect(result.sources, isNotEmpty);
      expect(result.answer, contains('7.4'));
      expect(result.answer, contains('8.0'));

      // Write evidence
      final file = File('test_flutter_live_evidence.txt');
      await file.writeAsString(
        '=== FLUTTER CHAT SERVICE LIVE EVIDENCE ===\n'
        'Timestamp: ${DateTime.now()}\n'
        'Latency: ${stopwatch.elapsedMilliseconds}ms\n'
        'Sources: ${result.sources.join(", ")}\n'
        'Answer:\n${result.answer}\n'
      );
      print('[Flutter Test] Evidence written to: ${file.path}');
    });

    test('3. Live ChatProvider State Flow (Flutter UI state test)', () async {
      print('\n[Flutter Test] Testing ChatProvider state flow...');
      final provider = ChatProvider(apiService: apiService);
      provider.updateScope(scope: 'subject', id: 'CSD201');

      final promptFuture = provider.sendPrompt(
        'Tôi chỉ cần qua môn CSD201, hãy chỉ cho tôi những đầu điểm cần chú ý nhất.',
      );

      // Verify sending state
      expect(provider.isLoading, isTrue);
      await promptFuture;
      expect(provider.isLoading, isFalse);

      final lastMessage = provider.messages.last;
      print('[Flutter Test] Last Message Status: ${lastMessage.status}');
      print('[Flutter Test] Last Message Text Length: ${lastMessage.text.length}');
      print('[Flutter Test] Last Message Sources: ${lastMessage.sources}');
      expect(lastMessage.status.toString(), contains('success'));
      expect(lastMessage.text, isNotEmpty);
    });
  });
}
