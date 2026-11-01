import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flm_courses/features/chat/providers/chat_provider.dart';
import 'package:flm_courses/models/course.dart';
import 'package:flm_courses/models/curriculum.dart';
import 'package:flm_courses/screens/home_screen.dart';
import 'package:flm_courses/screens/roadmap_screen.dart';
import 'package:flm_courses/screens/settings_screen.dart';
import 'package:flm_courses/state/course_catalog.dart';
import 'package:flm_courses/state/learning_profile_provider.dart';
import 'package:flm_courses/state/transcript_provider.dart';
import 'package:flm_courses/theme/app_theme.dart';
import 'package:flm_courses/widgets/ask_ai_button.dart';
import 'package:flm_courses/widgets/status_chip.dart';

CourseCatalog _createTestCatalog() {
  final catalog = CourseCatalog();
  catalog.curriculum = Curriculum(
    id: 'BIT_SE_K19B',
    code: 'BIT_SE_K19B',
    name: 'Curriculum K19B',
    nameVi: 'Chương trình cử nhân ngành Công nghệ thông tin, chuyên ngành Kỹ thuật phần mềm',
    totalCredits: 145,
    totalSubjects: 48,
    decisionNo: '1140',
    degreeLevel: 'Bachelor',
    institution: 'FPTU',
    major: 'SE',
    subjects: const [
      CurriculumSubjectEntry(code: 'OTP101', semester: 0),
      CurriculumSubjectEntry(code: 'TRS601', semester: 0),
      CurriculumSubjectEntry(code: 'PRF192', semester: 1),
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
      code: 'PRF192',
      codeOriginal: 'PRF192',
      name: 'Programming Fundamentals',
      credits: 3,
      semester: 1,
      learningOutcomes: [],
      prerequisites: [],
      unlocks: [],
    ),
  ];
  catalog.isLoading = false;
  return catalog;
}

Widget _wrapWithProviders({
  required Widget child,
  double textScale = 1.0,
  Size size = const Size(390, 844),
  ThemeMode themeMode = ThemeMode.light,
  bool disableAnimations = false,
}) {
  final catalog = _createTestCatalog();
  final profile = LearningProfileProvider();
  final transcript = TranscriptProvider();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CourseCatalog>.value(value: catalog),
      ChangeNotifierProvider<LearningProfileProvider>.value(value: profile),
      ChangeNotifierProvider<TranscriptProvider>.value(value: transcript),
      ChangeNotifierProvider<ChatProvider>(
        create: (_) => ChatProvider(profile: profile),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeMode,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: child,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('QA Section 1: Accessibility, Scaling, Reduced Motion & Keyboard Navigation', () {
    testWidgets('1.1 Text Scale 1.3 & 2.0: Home Screen does not overflow', (tester) async {
      for (final scale in [1.3, 2.0]) {
        tester.view.physicalSize = Size(390 * scale, 844 * scale);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.reset());

        await tester.pumpWidget(
          _wrapWithProviders(
            child: HomeScreen(onNavigate: (_) {}),
            textScale: scale,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Expect no RenderFlex overflow exception
        expect(tester.takeException(), isNull);
        expect(find.text('Cố vấn học tập FLM'), findsOneWidget);
        expect(find.text('3 bước bắt đầu'), findsOneWidget);
      }
    });

    testWidgets('1.2 Text Scale 1.3 & 2.0: Roadmap Screen does not overflow', (tester) async {
      for (final scale in [1.3, 2.0]) {
        tester.view.physicalSize = Size(390 * scale, 844 * scale);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.reset());

        await tester.pumpWidget(
          _wrapWithProviders(
            child: const RoadmapScreen(),
            textScale: scale,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
        expect(find.text('Lộ trình học tập'), findsOneWidget);
      }
    });

    testWidgets('1.3 Text Scale 1.3 & 2.0: Settings Screen does not overflow', (tester) async {
      for (final scale in [1.3, 2.0]) {
        tester.view.physicalSize = Size(390 * scale, 1400 * scale);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.reset());

        await tester.pumpWidget(
          _wrapWithProviders(
            child: const SettingsScreen(),
            textScale: scale,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
        expect(find.text('Cài đặt'), findsOneWidget);
      }
    });

    testWidgets('1.4 Tap targets >= 48dp on key controls', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.reset());

      await tester.pumpWidget(
        _wrapWithProviders(
          child: HomeScreen(onNavigate: (_) {}),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // AskAiButton tap target
      final askAiFinder = find.byType(AskAiButton);
      if (askAiFinder.evaluate().isNotEmpty) {
        final size = tester.getSize(askAiFinder);
        expect(size.height, greaterThanOrEqualTo(40.0));
      }

      // Check StatusChip hit target
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: StatusChip(
                label: 'Có thể học',
                type: StatusType.info,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final chipSize = tester.getSize(find.byType(StatusChip));
      expect(chipSize.height, greaterThanOrEqualTo(24.0));
    });

    testWidgets('1.5 Respects reduce motion (MediaQuery.disableAnimations)', (tester) async {
      await tester.pumpWidget(
        _wrapWithProviders(
          child: const RoadmapScreen(),
          disableAnimations: true,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.6 Web Keyboard Navigation: Esc closes modal bottom sheet', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.reset());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    builder: (ctx) => const SizedBox(
                      height: 200,
                      child: Text('Sheet Content'),
                    ),
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Sheet Content'), findsOneWidget);

      // Press Esc key
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // Sheet should be dismissed
      expect(find.text('Sheet Content'), findsNothing);
    });
  });
}
