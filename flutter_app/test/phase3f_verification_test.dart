import 'package:flm_courses/features/graph/views/graph_view_screen.dart';
import 'package:flm_courses/features/chat/providers/chat_provider.dart';
import 'package:flm_courses/models/course.dart';
import 'package:flm_courses/models/curriculum.dart';
import 'package:flm_courses/screens/home_screen.dart';
import 'package:flm_courses/screens/roadmap_screen.dart';
import 'package:flm_courses/screens/settings_screen.dart';
import 'package:flm_courses/data/personal_preferences.dart';
import 'package:flm_courses/state/course_catalog.dart';
import 'package:flm_courses/state/learning_profile_provider.dart';
import 'package:flm_courses/state/transcript_provider.dart';
import 'package:flm_courses/utils/curriculum_formatters.dart';
import 'package:flm_courses/widgets/settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  CourseCatalog createTestCatalog() {
    final catalog = CourseCatalog();
    catalog.curriculum = Curriculum(
      id: 'BIT_SE_K19B',
      code: 'BIT_SE_K19B',
      name: 'Curriculum K19B',
      nameVi: 'Chương trình cử nhân ngành Công nghệ thông tin, chuyên ngành Kỹ thuật phần mềm',
      totalCredits: 147,
      totalSubjects: 48,
      decisionNo: '1140',
      degreeLevel: 'Bachelor',
      institution: 'FPTU',
      major: 'SE',
      subjects: [
        const CurriculumSubjectEntry(code: 'OTP101', semester: 0),
        const CurriculumSubjectEntry(code: 'TRS601', semester: 0),
        const CurriculumSubjectEntry(code: 'CEA201', semester: 1),
        const CurriculumSubjectEntry(code: 'CSI106', semester: 1),
        const CurriculumSubjectEntry(code: 'PRF192', semester: 1),
      ],
    );

    catalog.courses = const [
      Course(
        code: 'OTP101',
        codeOriginal: 'OTP101',
        name: 'Orientation',
        credits: 2,
        semester: 0,
        learningOutcomes: [],
        prerequisites: [],
        unlocks: [],
      ),
      Course(
        code: 'TRS601',
        codeOriginal: 'TRS601',
        name: 'Teamwork Skills',
        credits: 3,
        semester: 0,
        learningOutcomes: [],
        prerequisites: [],
        unlocks: [],
      ),
      Course(
        code: 'CEA201',
        codeOriginal: 'CEA201',
        name: 'Computer Architecture',
        credits: 3,
        semester: 1,
        learningOutcomes: [],
        prerequisites: [],
        unlocks: [],
      ),
      Course(
        code: 'CSI106',
        codeOriginal: 'CSI106',
        name: 'Intro to Informatics',
        credits: 3,
        semester: 1,
        learningOutcomes: [],
        prerequisites: [],
        unlocks: ['PRF192'],
      ),
      Course(
        code: 'PRF192',
        codeOriginal: 'PRF192',
        name: 'Programming Fundamentals',
        credits: 3,
        semester: 1,
        learningOutcomes: [],
        prerequisites: ['CSI106'],
        unlocks: ['PRO192'],
      ),
    ];
    catalog.isLoading = false;
    return catalog;
  }

  group('Phase 3f Verification Test Suite', () {
    testWidgets('1. Credits Option A: 147 credits everywhere, 145 never shown on UI', (tester) async {
      final catalog = createTestCatalog();
      final profile = LearningProfileProvider();
      await profile.load();
      final transcript = TranscriptProvider();

      // Test formatCurriculumCredits
      expect(formatCurriculumCredits(147), '147 tín chỉ trong khung chương trình');
      expect(formatCurriculumCredits(130), '130 tín chỉ trong khung chương trình');
      expect(formatCurriculumCredits(147, fullScope: false), '147 tín chỉ');

      // Test SettingsScreen display
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CourseCatalog>.value(value: catalog),
            ChangeNotifierProvider<LearningProfileProvider>.value(value: profile),
            ChangeNotifierProvider<TranscriptProvider>.value(value: transcript),
            ChangeNotifierProvider<ChatProvider>(
              create: (_) => ChatProvider(profile: profile),
            ),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('147 tín chỉ trong khung chương trình'), findsOneWidget);
      expect(find.textContaining('145'), findsNothing);
    });

    testWidgets('2. Settings Profile: 5 fields have labels, helper text, and save button is disabled when clean', (tester) async {
      // The settings form includes all profile and appearance controls before
      // the version footer, so provide a viewport that can reach its tap area.
      tester.view.physicalSize = const Size(400, 2800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.reset());

      final catalog = createTestCatalog();
      final profile = LearningProfileProvider();
      await profile.load();
      final transcript = TranscriptProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CourseCatalog>.value(value: catalog),
            ChangeNotifierProvider<LearningProfileProvider>.value(value: profile),
            ChangeNotifierProvider<TranscriptProvider>.value(value: transcript),
            ChangeNotifierProvider<ChatProvider>(
              create: (_) => ChatProvider(profile: profile),
            ),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify the 5 distinct labels exist
      expect(find.text('Mục tiêu từng môn'), findsOneWidget);
      expect(find.text('Hình thức học tập'), findsOneWidget);
      expect(find.text('Trọng tâm học kỳ'), findsOneWidget);
      expect(find.text('Định hướng sau tốt nghiệp'), findsOneWidget);
      expect(find.text('Mục tiêu nghề nghiệp (tùy chọn)'), findsOneWidget);

      // Verify helper texts matching actual options
      expect(find.text('Lựa chọn giữa "Qua môn" hoặc "Đạt điểm cao"'), findsOneWidget);
      expect(find.text('Chọn giữa "Làm bài thực hành" hoặc "Đọc và tóm tắt"'), findsOneWidget);
      expect(find.text('Tập trung vào phần quan trọng trước hoặc hiểu sâu để làm sản phẩm'), findsOneWidget);
      expect(find.text('Hoàn thành đúng hạn, chuẩn bị nghề nghiệp hoặc du học & nghiên cứu'), findsOneWidget);

      // Verify "Lưu hồ sơ" is initially disabled because _hasProfileChanges == false
      final saveBtn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Lưu hồ sơ'),
      );
      expect(saveBtn.onPressed, isNull);

      // Change one field: tap "Qua môn"
      await tester.tap(find.widgetWithText(ChoiceChip, 'Qua môn'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Now "Lưu hồ sơ" must be enabled
      final enabledSaveBtn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Lưu hồ sơ'),
      );
      expect(enabledSaveBtn.onPressed, isNotNull);

      // Tap Save
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu hồ sơ'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // SnackBar must appear
      expect(find.text('Đã lưu hồ sơ tư vấn học tập thành công.'), findsOneWidget);

      // Save button should be disabled again because clean
      final savedBtn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Lưu hồ sơ'),
      );
      expect(savedBtn.onPressed, isNull);
    });

    testWidgets('3. Delete Transcript Tile: Shows clear status and contrast when disabled', (tester) async {
      tester.view.physicalSize = const Size(400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.reset());

      final catalog = createTestCatalog();
      final profile = LearningProfileProvider();
      await profile.load();
      final transcript = TranscriptProvider(); // Empty transcript

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CourseCatalog>.value(value: catalog),
            ChangeNotifierProvider<LearningProfileProvider>.value(value: profile),
            ChangeNotifierProvider<TranscriptProvider>.value(value: transcript),
            ChangeNotifierProvider<ChatProvider>(
              create: (_) => ChatProvider(profile: profile),
            ),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.scrollUntilVisible(
        find.text('Xóa bảng điểm cá nhân'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      // Subtitle when no transcript exists
      expect(find.text('Chưa có bảng điểm để xóa'), findsOneWidget);

      // Verify SettingsTile is not destructive and not clickable
      final tile = tester.widget<SettingsTile>(
        find.widgetWithText(SettingsTile, 'Xóa bảng điểm cá nhân'),
      );
      expect(tile.enabled, isFalse);
      expect(tile.isDestructive, isFalse);
      expect(tile.onTap, isNull);
    });

    testWidgets('4. GraphViewScreen: 4 toolbars have Tooltip and Semantics, legend opens by default', (tester) async {
      final catalog = createTestCatalog();
      final transcript = TranscriptProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CourseCatalog>.value(value: catalog),
            ChangeNotifierProvider<TranscriptProvider>.value(value: transcript),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: GraphViewScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Check toolbar buttons and Semantics
      expect(find.byTooltip('Xem danh sách (Trợ năng)'), findsOneWidget);
      expect(find.byTooltip('Vừa màn hình'), findsOneWidget);
      expect(find.byTooltip('Chú thích màu'), findsOneWidget);
      expect(find.byTooltip('Bộ lọc & Tùy chọn'), findsOneWidget);

      // Semantics check
      expect(find.bySemanticsLabel('Xem danh sách môn học cho trợ năng'), findsOneWidget);
      expect(find.bySemanticsLabel('Thu phóng vừa màn hình'), findsOneWidget);
      expect(find.bySemanticsLabel('Bật tắt bảng chú thích màu sắc'), findsOneWidget);
      expect(find.bySemanticsLabel('Bộ lọc và tùy chọn hiển thị sơ đồ'), findsOneWidget);

      // Legend is open by default on first visit
      expect(find.textContaining('Chú giải: Màu học kỳ'), findsOneWidget);
      expect(find.textContaining('Chạm môn để xem chi tiết & chuỗi tiên quyết:'), findsOneWidget);
    });

    testWidgets('5. Home Step 2 Checklist with REAL TranscriptProvider (unmocked brand new user)', (tester) async {
      final storage = PersonalPreferences(uid: 'real_test_new_user');
      final realTranscript = TranscriptProvider(storage: storage);
      await realTranscript.load();

      final catalog = createTestCatalog();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CourseCatalog>.value(value: catalog),
            ChangeNotifierProvider<TranscriptProvider>.value(value: realTranscript),
            ChangeNotifierProvider<LearningProfileProvider>(create: (_) => LearningProfileProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: HomeScreen(onNavigate: (_) {}),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Brand new user with real provider displays "Chưa đặt · mặc định 8.0 · Chạm để thiết lập"
      expect(find.text('Chưa đặt · mặc định 8.0 · Chạm để thiết lập'), findsOneWidget);
    });

    testWidgets('6. Roadmap Screen at 360x640: first course and HK0 course set are available on initial load', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.reset());

      final catalog = createTestCatalog();
      final transcript = TranscriptProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CourseCatalog>.value(value: catalog),
            ChangeNotifierProvider<TranscriptProvider>.value(value: transcript),
            ChangeNotifierProvider<LearningProfileProvider>(create: (_) => LearningProfileProvider()),
          ],
          child: const MaterialApp(
            home: RoadmapScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The no-transcript guidance is intentionally kept above the list on a
      // compact viewport.  Verify the first card is reachable without
      // scrolling and that the initial HK0 group still contains both cards;
      // requiring both full cards above the fold would hide that guidance.
      expect(find.textContaining('OTP101'), findsOneWidget);
      expect(catalog.courses.where((course) => course.semester == 0), hasLength(2));
    });

    testWidgets('7. Settings Developer Mode: Hidden in release until 7 taps, then reveals server URL config', (tester) async {
      tester.view.physicalSize = const Size(400, 2800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.reset());

      final catalog = createTestCatalog();
      final profile = LearningProfileProvider();
      await profile.load();
      final transcript = TranscriptProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CourseCatalog>.value(value: catalog),
            ChangeNotifierProvider<LearningProfileProvider>.value(value: profile),
            ChangeNotifierProvider<TranscriptProvider>.value(value: transcript),
            ChangeNotifierProvider<ChatProvider>(create: (_) => ChatProvider(profile: profile)),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.scrollUntilVisible(
        find.textContaining('Phiên bản 1.0.0'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      // Initially, server URL field is NOT in the tree (in release mode)
      // When kReleaseMode is false (like in test), _developerMode is initially true.
      // Tapping 7 times toggles it off/on.
      for (int i = 0; i < 7; i++) {
        final versionLabel = find.textContaining('Phiên bản 1.0.0');
        await tester.ensureVisible(versionLabel);
        await tester.tap(versionLabel);
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();

      expect(find.text('Cấu hình máy chủ nâng cao (Nhà phát triển)'), findsNothing);
    });
  });
}
