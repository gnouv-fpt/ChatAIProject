import 'package:flm_courses/features/chat/providers/chat_provider.dart';
import 'package:flm_courses/features/chat/services/chat_api_service.dart';
import 'package:flm_courses/features/chat/views/widgets/contextual_chat_panel.dart';
import 'package:flm_courses/models/course.dart';
import 'package:flm_courses/models/curriculum.dart';
import 'package:flm_courses/pages/curriculum_detail_page.dart';
import 'package:flm_courses/state/course_catalog.dart';
import 'package:flm_courses/state/learning_profile_provider.dart';
import 'package:flm_courses/state/transcript_provider.dart';
import 'package:flm_courses/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _OfflineChat extends ChatApiService {
  _OfflineChat() : super(baseUrl: 'http://localhost:8000');
  @override
  Future<bool> checkHealth() async => false;
}

CourseCatalog fixtureCatalog() => CourseCatalog()
  ..curriculum = Curriculum.fromJson({
    'id': 'TEST',
    'code': 'TEST',
    'name': 'Test',
    'name_vi': 'Chương trình kiểm thử',
    'total_credits': 3,
    'total_subjects': 1,
  })
  ..courses = [
    Course.fromJson({
      'code': 'PRF192',
      'name': 'Programming Fundamentals',
      'name_vi': 'Cơ sở lập trình',
      'credits': 3,
      'semester': 1,
    }),
  ];

Future<void> openCurriculum(
  WidgetTester tester, {
  required double width,
  CourseCatalog? catalog,
  double scale = 1,
  TranscriptProvider? transcript,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final profile = LearningProfileProvider();
  await profile.load();
  final data = transcript ?? TranscriptProvider();
  if (transcript == null) await data.load();
  final chat = ChatProvider(apiService: _OfflineChat(), profile: profile);
  addTearDown(chat.dispose);
  addTearDown(profile.dispose);
  if (transcript == null) addTearDown(data.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: catalog ?? fixtureCatalog()),
        ChangeNotifierProvider.value(value: data),
        ChangeNotifierProvider.value(value: profile),
        ChangeNotifierProvider.value(value: chat),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const CurriculumDetailPage(curriculumId: 'TEST'),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  for (final width in [360.0, 412.0]) {
    testWidgets(
      'F02 mobile advisor opens, closes and keeps course context at $width',
      (tester) async {
        await openCurriculum(tester, width: width);
        await tester.tap(find.text('Học kỳ 1'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Hỏi Trợ lý AI'));
        await tester.pumpAndSettle();
        expect(find.byType(ContextualChatPanel), findsOneWidget);
        expect(
          tester
              .widget<ContextualChatPanel>(find.byType(ContextualChatPanel))
              .scopeId,
          'TEST',
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(ContextualChatPanel), findsNothing);
        expect(find.text('Cơ sở lập trình'), findsOneWidget);
        await tester.tap(find.byTooltip('Tư vấn học kỳ'));
        await tester.pumpAndSettle();
        final panel = tester.widget<ContextualChatPanel>(
          find.byType(ContextualChatPanel),
        );
        expect(panel.semesterNumber, 1);
        expect(panel.suggestedQuestions!.single, contains('Học kỳ 1'));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
