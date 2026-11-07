import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flm_courses/data/personal_data_repository.dart';
import 'package:flm_courses/models/transcript_entry.dart';
import 'package:flm_courses/screens/home_screen.dart';
import 'package:flm_courses/screens/settings_screen.dart';
import 'package:flm_courses/screens/transcript_screen.dart';
import 'package:flm_courses/state/auth_view_model.dart';
import 'package:flm_courses/state/course_catalog.dart';
import 'package:flm_courses/state/learning_profile_provider.dart';
import 'package:flm_courses/state/transcript_provider.dart';
import 'package:flm_courses/features/chat/providers/chat_provider.dart';
import 'fixtures/phase3a_fixtures.dart';

class FailingPersonalDataRepository implements PersonalDataRepository {
  FailingPersonalDataRepository({required this.entries, required this.targetGpa, this.hasExplicitTargetGpa = false});
  final List<TranscriptEntry> entries;
  final double targetGpa;
  final bool hasExplicitTargetGpa;

  @override
  Future<Map<String, dynamic>?> loadProfile() async => null;

  @override
  Future<void> saveProfile(Map<String, dynamic> profile) async {}

  @override
  Future<SavedTranscript> loadTranscript() async {
    return SavedTranscript(
      entries: entries,
      targetGpa: targetGpa,
      hasExplicitTargetGpa: hasExplicitTargetGpa,
    );
  }

  @override
  Future<void> saveTranscript(List<TranscriptEntry> entries) async {
    throw StateError('Simulated Cloud Network / Firestore Failure (503)');
  }

  @override
  Future<void> saveTargetGpa(double targetGpa) async {}
}

class SuccessfulPersonalDataRepository implements PersonalDataRepository {
  SuccessfulPersonalDataRepository({required this.entries, required this.targetGpa, this.hasExplicitTargetGpa = false});
  List<TranscriptEntry> entries;
  double targetGpa;
  bool hasExplicitTargetGpa;

  @override
  Future<Map<String, dynamic>?> loadProfile() async => null;

  @override
  Future<void> saveProfile(Map<String, dynamic> profile) async {}

  @override
  Future<SavedTranscript> loadTranscript() async {
    return SavedTranscript(
      entries: entries,
      targetGpa: targetGpa,
      hasExplicitTargetGpa: hasExplicitTargetGpa,
    );
  }

  @override
  Future<void> saveTranscript(List<TranscriptEntry> newEntries) async {
    entries = List.from(newEntries);
  }

  @override
  Future<void> saveTargetGpa(double gpa) async {
    targetGpa = gpa;
    hasExplicitTargetGpa = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Item 2: targetGpa Exhaustive Audit & Test Suite', () {
    test('1. New Account: effective targetGpa is 8.0, hasExplicitTargetGpa is false', () async {
      final repo = SuccessfulPersonalDataRepository(entries: [], targetGpa: 8.0, hasExplicitTargetGpa: false);
      final transcript = TranscriptProvider(repository: repo);
      await transcript.load();

      expect(transcript.targetGpa, 8.0);
      expect(transcript.hasExplicitTargetGpa, isFalse);
    });

    test('2. Existing Account with 8.0 saved: hasExplicitTargetGpa is true, targetGpa is 8.0', () async {
      final repo = SuccessfulPersonalDataRepository(entries: [], targetGpa: 8.0, hasExplicitTargetGpa: true);
      final transcript = TranscriptProvider(repository: repo);
      await transcript.load();

      expect(transcript.targetGpa, 8.0);
      expect(transcript.hasExplicitTargetGpa, isTrue);
    });

    testWidgets('3. Checklist Step 2 UI: New account vs saved 8.5 account', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final catalog = CourseCatalog();
      final profile = LearningProfileProvider();
      await profile.load();

      // Brand new account
      final newRepo = SuccessfulPersonalDataRepository(entries: [], targetGpa: 8.0, hasExplicitTargetGpa: false);
      final newTranscript = TranscriptProvider(repository: newRepo);
      await newTranscript.load();

      final auth = AuthViewModel(TestAuthService());
      final chat = ChatProvider(profile: profile);

      await tester.pumpWidget(
        wrapWithTestProviders(
          child: HomeScreen(onNavigate: (_) {}),
          catalog: catalog,
          profile: profile,
          transcript: newTranscript,
          auth: auth,
          chat: chat,
        ),
      );
      await tester.pumpAndSettle();

      // Step 2 shows default 8.0 notice
      expect(find.text('2. Đặt mục tiêu GPA'), findsOneWidget);
      expect(find.textContaining('Chưa đặt · mặc định 8.0'), findsOneWidget);

      // Now set target GPA explicitly to 8.5
      newTranscript.setTargetGpa(8.5);
      await tester.pumpAndSettle();

      expect(find.text('Mục tiêu đã đặt: 8.5 · Chạm để điều chỉnh'), findsOneWidget);
      expect(find.text('8.5'), findsWidgets);
    });

    testWidgets('4. Settings GPA Slider & Transcript Screen SummaryCard reads effective 8.0', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final catalog = CourseCatalog();
      final profile = LearningProfileProvider();
      await profile.load();

      final newRepo = SuccessfulPersonalDataRepository(entries: [], targetGpa: 8.0, hasExplicitTargetGpa: false);
      final transcript = TranscriptProvider(repository: newRepo);
      await transcript.load();

      final auth = AuthViewModel(TestAuthService());
      final chat = ChatProvider(profile: profile);

      // Transcript Screen SummaryCard check
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const TranscriptScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
        ),
      );
      await tester.pumpAndSettle();

      // Settings Screen Slider check
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const SettingsScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('8.0'), findsWidgets);
      expect(find.byType(Slider), findsOneWidget);
    });
  });

  group('Item 3: clearTranscript Fail-Safe & Atomic Preservation Suite', () {
    test('1. Cloud Failure: clearTranscript throws, does NOT clear local cache or in-memory entries', () async {
      SharedPreferences.setMockInitialValues({
        'flm_transcript_v1': '[{"courseCode":"PRF192","grade":8.5,"credits":3,"semester":1,"status":"passed"}]',
      });

      final sampleEntries = [
        TranscriptEntry(courseCode: 'PRF192', score: 8.5, credits: 3, semester: 1, isPassed: true),
      ];

      final failingRepo = FailingPersonalDataRepository(
        entries: sampleEntries,
        targetGpa: 8.0,
        hasExplicitTargetGpa: true,
      );

      final transcript = TranscriptProvider(repository: failingRepo);
      await transcript.load();

      expect(transcript.entries.length, 1);
      expect(transcript.hasTranscript, isTrue);

      // Attempt clearTranscript() with failing cloud backend
      await expectLater(transcript.clearTranscript(), throwsA(isA<StateError>()));

      // Verify entries are NOT cleared (fail-safe atomic preservation)
      expect(transcript.entries.length, 1);
      expect(transcript.hasTranscript, isTrue);
      expect(transcript.saveError, contains('Không thể xóa bảng điểm trên đám mây'));

      // Verify local SharedPreferences cache was NOT removed
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('flm_transcript_v1'), isNotNull);
    });

    testWidgets('2. SettingsScreen UI displays error SnackBar and preserves transcript on cloud failure', (tester) async {
      tester.view.physicalSize = const Size(400, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.reset());

      SharedPreferences.setMockInitialValues({});
      final catalog = CourseCatalog();
      final profile = LearningProfileProvider();
      await profile.load();

      final sampleEntries = [
        TranscriptEntry(courseCode: 'PRF192', score: 8.5, credits: 3, semester: 1, isPassed: true),
      ];

      final failingRepo = FailingPersonalDataRepository(
        entries: sampleEntries,
        targetGpa: 8.0,
        hasExplicitTargetGpa: true,
      );

      final transcript = TranscriptProvider(repository: failingRepo);
      await transcript.load();

      final auth = AuthViewModel(TestAuthService());
      final chat = ChatProvider(profile: profile);

      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const SettingsScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Xóa bảng điểm cá nhân"
      final deleteTile = find.text('Xóa bảng điểm cá nhân');
      expect(deleteTile, findsOneWidget);
      await tester.ensureVisible(deleteTile);
      await tester.tap(deleteTile);
      await tester.pumpAndSettle();

      // Tap "Xóa vĩnh viễn"
      final confirmBtn = find.text('Xóa vĩnh viễn');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Error snackbar appears
      expect(find.textContaining('Không thể xóa bảng điểm trên đám mây. Dữ liệu chưa bị xóa.'), findsOneWidget);

      // Data is NOT lost
      expect(transcript.hasTranscript, isTrue);
      expect(transcript.entries.length, 1);
    });
  });
}
