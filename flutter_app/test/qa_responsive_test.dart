import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flm_courses/features/chat/providers/chat_provider.dart';
import 'package:flm_courses/models/course.dart';
import 'package:flm_courses/models/curriculum.dart';
import 'package:flm_courses/screens/home_screen.dart';
import 'package:flm_courses/screens/roadmap_screen.dart';
import 'package:flm_courses/screens/settings_screen.dart';
import 'package:flm_courses/screens/transcript_screen.dart';
import 'package:flm_courses/services/grade_import_service.dart';
import 'package:flm_courses/services/transcript_image_picker.dart';
import 'package:flm_courses/state/course_catalog.dart';
import 'package:flm_courses/state/learning_profile_provider.dart';
import 'package:flm_courses/state/transcript_import_view_model.dart';
import 'package:flm_courses/state/transcript_provider.dart';
import 'package:flm_courses/theme/app_theme.dart';

CourseCatalog _createTestCatalog() {
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

Widget _buildAppForScreen(Widget screen, Size size) {
  final catalog = _createTestCatalog();
  final profile = LearningProfileProvider();
  final transcript = TranscriptProvider();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CourseCatalog>.value(value: catalog),
      ChangeNotifierProvider<LearningProfileProvider>.value(value: profile),
      ChangeNotifierProvider<TranscriptProvider>.value(value: transcript),
      ChangeNotifierProvider<TranscriptImportViewModel>(
        create: (_) => TranscriptImportViewModel(
          picker: FileTranscriptImagePicker(),
          service: () => GradeImportService(baseUrl: 'https://flm-api.example.com'),
        ),
      ),
      ChangeNotifierProvider<ChatProvider>(
        create: (_) => ChatProvider(profile: profile),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme(),
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: screen,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final viewports = <String, Size>{
    '320x568 (Ultra Compact)': const Size(320, 568),
    '360x640 (Compact)': const Size(360, 640),
    '390x844 (Standard Mobile)': const Size(390, 844),
    '430x932 (Large Mobile)': const Size(430, 932),
    '630x900 (Wide / Web)': const Size(630, 900),
    '768x1024 (Tablet)': const Size(768, 1024),
    '640x360 (Landscape Compact)': const Size(640, 360),
    '844x390 (Landscape Standard)': const Size(844, 390),
  };

  group('QA Section 2: Responsive Matrix Across All 8 Viewports', () {
    for (final entry in viewports.entries) {
      testWidgets('HomeScreen on ${entry.key} - no crash or overflow', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.reset());

        await tester.pumpWidget(_buildAppForScreen(HomeScreen(onNavigate: (_) {}), entry.value));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
      });

      testWidgets('RoadmapScreen on ${entry.key} - no crash or overflow', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.reset());

        await tester.pumpWidget(_buildAppForScreen(const RoadmapScreen(), entry.value));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
      });

      testWidgets('TranscriptScreen on ${entry.key} - no crash or overflow', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.reset());

        await tester.pumpWidget(_buildAppForScreen(const TranscriptScreen(), entry.value));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
      });

      testWidgets('SettingsScreen on ${entry.key} - no crash or overflow', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.reset());

        await tester.pumpWidget(_buildAppForScreen(const SettingsScreen(), entry.value));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
      });
    }
  });
}
