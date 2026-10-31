import 'package:flm_courses/features/chat/providers/chat_provider.dart';
import 'package:flm_courses/features/chat/services/chat_api_service.dart';
import 'package:flm_courses/models/course.dart';
import 'package:flm_courses/models/curriculum.dart';
import 'package:flm_courses/screens/roadmap_screen.dart';
import 'package:flm_courses/state/course_catalog.dart';
import 'package:flm_courses/state/learning_profile_provider.dart';
import 'package:flm_courses/state/transcript_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingChat extends ChatApiService {
  _RecordingChat() : super(baseUrl: 'http://localhost:8000');

  String? question;
  String? scopeId;
  Map<String, dynamic>? facts;

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
  }) async {
    question = prompt;
    scopeId = id;
    facts = studentContext;
    return ChatResponseResult(
      answer: 'Câu trả lời thử nghiệm',
      sources: const [],
      isOfflineFallback: false,
    );
  }
}

void main() {
  testWidgets('semester question carries the viewed semester to the backend', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});

    final catalog = CourseCatalog()
      ..curriculum = Curriculum.fromJson({
        'id': 'TEST',
        'code': 'TEST',
        'name': 'Test',
        'name_vi': 'Chương trình thử nghiệm',
        'total_credits': 6,
        'total_subjects': 2,
      })
      ..courses = [
        Course.fromJson({
          'code': 'PRF192',
          'name': 'Programming Fundamentals',
          'name_vi': 'Nhập môn lập trình',
          'credits': 3,
          'semester': 1,
        }),
        Course.fromJson({
          'code': 'PRO192',
          'name': 'Object Oriented Programming',
          'name_vi': 'Lập trình hướng đối tượng',
          'credits': 3,
          'semester': 2,
        }),
      ];
    final transcript = TranscriptProvider();
    await transcript.load();
    final profile = LearningProfileProvider();
    await profile.load();
    final api = _RecordingChat();
    final chat = ChatProvider(apiService: api, profile: profile);
    await chat.historyReady;
    addTearDown(chat.dispose);
    addTearDown(transcript.dispose);
    addTearDown(profile.dispose);
    addTearDown(catalog.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: catalog),
          ChangeNotifierProvider.value(value: transcript),
          ChangeNotifierProvider.value(value: profile),
          ChangeNotifierProvider.value(value: chat),
        ],
        child: const MaterialApp(home: RoadmapScreen()),
      ),
    );
    await tester.pump();

    final askSemester = find.byTooltip('Hỏi Trợ lý về học kỳ 1');
    await tester.ensureVisible(askSemester);
    await tester.tap(askSemester);
    await tester.pumpAndSettle();
    expect(find.text('học kỳ 1', findRichText: true), findsWidgets);

    await tester.enterText(find.byType(TextField).last, 'Tôi nên chuẩn bị gì?');
    await tester.tap(find.byTooltip('Gửi câu hỏi'));
    await tester.pumpAndSettle();

    expect(api.scopeId, 'TEST');
    expect(api.facts?['target_semester'], 1);
    expect(api.question, contains('Học kỳ 1'));
    expect(api.question, contains('Tôi nên chuẩn bị gì?'));
    expect(
      chat.messages.any((message) => message.text == 'Tôi nên chuẩn bị gì?'),
      isTrue,
    );

    await tester.tap(find.byTooltip('Đóng Trợ lý AI'));
    await tester.pumpAndSettle();
    final askNextSemester = find.byTooltip('Hỏi Trợ lý về học kỳ 2');
    await tester.ensureVisible(askNextSemester);
    await tester.tap(askNextSemester);
    await tester.pumpAndSettle();
    expect(chat.currentScopeId, 'TEST:semester-2');
    expect(
      chat.messages.any((message) => message.text == 'Tôi nên chuẩn bị gì?'),
      isFalse,
    );
    await tester.enterText(find.byType(TextField).last, 'Kỳ này có gì quan trọng?');
    await tester.tap(find.byTooltip('Gửi câu hỏi'));
    await tester.pumpAndSettle();
    expect(api.scopeId, 'TEST');
    expect(api.facts?['target_semester'], 2);
    expect(api.question, contains('Học kỳ 2'));
    expect(api.question, isNot(contains('Học kỳ 1')));
  });
}
