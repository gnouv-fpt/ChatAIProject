import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'feedback_ui_test.dart' show loadEvidenceFont;

import 'dart:typed_data';

import 'package:flm_courses/features/chat/providers/chat_provider.dart';
import 'package:flm_courses/features/chat/services/chat_api_service.dart';
import 'package:flm_courses/features/chat/views/widgets/contextual_chat_panel.dart';
import 'package:flm_courses/models/course.dart';
import 'package:flm_courses/screens/transcript_screen.dart';
import 'package:flm_courses/services/grade_import_service.dart';
import 'package:flm_courses/services/transcript_image_picker.dart';
import 'package:flm_courses/state/transcript_import_view_model.dart';
import 'package:flm_courses/models/transcript_entry.dart';
import 'package:flm_courses/models/curriculum.dart';
import 'package:flm_courses/pages/curriculum_detail_page.dart';
import 'package:flm_courses/pages/course_detail_page.dart';
import 'package:flm_courses/state/course_catalog.dart';
import 'package:flm_courses/state/learning_profile_provider.dart';
import 'package:flm_courses/state/transcript_provider.dart';
import 'package:flm_courses/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const captureUx = bool.fromEnvironment('UX_REVIEW_EVIDENCE');
Future<void> screenshot(WidgetTester tester, String name) async {
  if (!captureUx) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('ux-capture')),
    );
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('../evidence/ux/2026-10-28/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

class _OfflineChat extends ChatApiService {
  _OfflineChat() : super(baseUrl: 'http://localhost:8000');
  @override
  Future<bool> checkHealth() async => false;
}

class _Picker implements TranscriptImagePicker {
  @override
  Future<List<ImageFile>?> pick() async => [
    ImageFile(
      filename: 'fixture.png',
      bytes: Uint8List(1),
      mimeType: 'image/png',
    ),
  ];
}

class _FailedOcr extends GradeImportService {
  _FailedOcr() : super(baseUrl: 'http://unused.test');
  @override
  Future<GradeImportResult> importFromImages(List<ImageFile> images) async =>
      throw GradeImportException(
        'Không thể kết nối máy chủ. Thử lại hoặc nhập tay.',
      );
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
  Widget? home,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  if (captureUx) await tester.runAsync(loadEvidenceFont);
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
        ChangeNotifierProvider(
          create: (_) => TranscriptImportViewModel(
            picker: _Picker(),
            service: _FailedOcr.new,
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: RepaintBoundary(key: const Key('ux-capture'), child: child!),
        ),
        home: home ?? const CurriculumDetailPage(curriculumId: 'TEST'),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('course detail stays at the same top position across tabs', (tester) async {
    await openCurriculum(
      tester,
      width: 360,
      home: const CourseDetailPage(code: 'PRF192'),
    );
    await tester.pumpAndSettle();
    final header = find.text('Cơ sở lập trình');
    final initialTop = tester.getTopLeft(header).dy;
    for (final tab in ['Tiên quyết', 'Đánh giá', 'Chuẩn đầu ra']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(header).dy, closeTo(initialTop, 1), reason: tab);
    }
  });

  testWidgets(
    'missing or mismatched curriculum shows recovery without invented totals',
    (tester) async {
      for (final catalog in [
        CourseCatalog(),
        fixtureCatalog()..curriculum = Curriculum.fromJson({'id': 'OTHER'}),
      ]) {
        await openCurriculum(tester, width: 360, catalog: catalog);
        expect(
          find.text('Chưa có dữ liệu cho chương trình này.'),
          findsOneWidget,
        );
        expect(find.text('Thử lại'), findsOneWidget);
        expect(find.byType(TabBar), findsNothing);
        expect(find.textContaining('145'), findsNothing);
      }
    },
  );

  testWidgets(
    'passed attempt stays passed regardless of import order and status filter',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final transcript = TranscriptProvider();
      await transcript.load();
      addTearDown(transcript.dispose);
      await transcript.save([
        TranscriptEntry(
          courseCode: 'PRF192',
          score: 8,
          credits: 3,
          semester: 2,
          isPassed: true,
        ),
        TranscriptEntry(
          courseCode: 'PRF192',
          score: 3,
          credits: 3,
          semester: 1,
          isPassed: false,
        ),
      ]);
      await openCurriculum(tester, width: 412, transcript: transcript);
      expect(find.text('Chưa đạt / học lại'), findsNothing);
      expect(find.widgetWithText(Chip, 'Đã đạt'), findsOneWidget);
      await tester.tap(find.text('Mọi trạng thái'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đã đạt').last);
      await tester.pumpAndSettle();
      expect(find.text('Cơ sở lập trình'), findsOneWidget);
    },
  );

  testWidgets(
    'F03 OCR network failure recovers through manual entry and saved GPA',
    (tester) async {
      await openCurriculum(tester, width: 412, home: const TranscriptScreen());
      await tester.tap(find.text('Nhập ảnh bảng điểm'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Không thể kết nối máy chủ'), findsOneWidget);
      await tester.tap(find.text('Nhập hoặc sửa điểm thủ công'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thêm môn thủ công'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'PRF192');
      await tester.enterText(fields.at(1), '8.5');
      await tester.enterText(fields.at(2), '1');
      await tester.tap(find.text('Áp dụng'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Lưu bảng điểm'));
      await tester.pumpAndSettle();
      expect(find.byType(TranscriptScreen), findsOneWidget);
      expect(find.text('8.50'), findsOneWidget);
      final saved = TranscriptProvider();
      await saved.load();
      expect(saved.entries.single.courseCode, 'PRF192');
      expect(saved.entries.single.score, 8.5);
      saved.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [360.0, 412.0, 1280.0]) {
    testWidgets('curriculum controls fit $width dp at text scale 1.3', (
      tester,
    ) async {
      await openCurriculum(tester, width: width, scale: 1.3);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Tổng quan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tổng quan'));
      await tester.pumpAndSettle();
      expect(find.text('Quyết định đào tạo'), findsOneWidget);
      await screenshot(tester, 'curriculum-${width.toInt()}-scale130');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (width >= 960) {
        expect(find.byType(ContextualChatPanel), findsOneWidget);
        await tester.tap(find.byTooltip('Đóng Trợ lý AI'));
        await tester.pumpAndSettle();
        expect(find.byType(ContextualChatPanel), findsNothing);
        await tester.tap(find.byTooltip('Hỏi Trợ lý AI'));
        await tester.pumpAndSettle();
        expect(find.byType(ContextualChatPanel), findsOneWidget);
      }
    });
  }

  for (final width in [360.0, 412.0]) {
    testWidgets(
      'F02 mobile advisor opens, closes and keeps course context at $width',
      (tester) async {
        await openCurriculum(tester, width: width);
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
        expect(panel.scopeId, 'TEST:semester-1');
        expect(panel.backendScopeId, 'TEST');
        expect(panel.suggestedQuestions!.single, contains('Học kỳ 1'));
        await screenshot(tester, 'advisor-${width.toInt()}');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('asking from a course card keeps that course as the chat scope', (
    tester,
  ) async {
    await openCurriculum(tester, width: 360);
    final course = find.text('Cơ sở lập trình').first;
    await tester.ensureVisible(course);
    await tester.tap(course);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tư vấn'));
    await tester.pumpAndSettle();

    final panel = tester.widget<ContextualChatPanel>(
      find.byType(ContextualChatPanel),
    );
    expect(panel.scope, 'subject');
    expect(panel.scopeId, 'PRF192');
  });

  testWidgets(
    'multi-semester curriculum starts with all cards collapsed and scrolls selected semester to top',
    (tester) async {
      final multiCatalog = CourseCatalog()
        ..curriculum = Curriculum.fromJson({
          'id': 'MULTI_TEST',
          'code': 'MULTI_TEST',
          'name': 'Multi-Semester Test',
          'name_vi': 'Chương trình đa học kỳ',
          'total_credits': 30,
          'total_subjects': 10,
        })
        ..courses = [
          for (int s = 0; s <= 6; s++)
            Course.fromJson({
              'code': 'SUBJ_' + s.toString(),
              'name': 'Subject Semester ' + s.toString(),
              'name_vi': 'Môn học kỳ ' + s.toString(),
              'credits': 3,
              'semester': s,
            }),
        ];

      await openCurriculum(tester, width: 412, catalog: multiCatalog, home: const CurriculumDetailPage(curriculumId: 'MULTI_TEST'));
      await tester.pumpAndSettle();

      // 1. Initial state: All semester cards collapsed, no subjects visible initially
      expect(find.text('Học kỳ 0'), findsOneWidget);
      expect(find.text('Học kỳ 4'), findsOneWidget);
      expect(find.text('Môn học kỳ 0'), findsNothing);
      expect(find.text('Môn học kỳ 4'), findsNothing);

      // 2. Tap HK4 chip on the horizontal bar
      final hk4Chip = find.widgetWithText(ActionChip, 'HK4');
      expect(hk4Chip, findsOneWidget);
      await tester.ensureVisible(hk4Chip);
      await tester.tap(hk4Chip);
      await tester.pumpAndSettle();

      // 3. HK4 expands and subject inside HK4 is visible
      expect(find.text('Môn học kỳ 4'), findsOneWidget);

      // 4. Verify HK4 card is at the top of the scrollable list viewport
      final hk4Card = find.text('Học kỳ 4');
      final hk4Position = tester.getTopLeft(hk4Card);
      expect(hk4Position.dy, closeTo(393.6, 5));
    },
  );
}
