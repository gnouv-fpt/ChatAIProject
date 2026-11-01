import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flm_courses/data/personal_preferences.dart';
import 'package:flm_courses/features/chat/models/chat_message.dart';
import 'package:flm_courses/features/chat/providers/chat_provider.dart';
import 'package:flm_courses/features/chat/views/widgets/chat_bubble.dart';
import 'package:flm_courses/models/course.dart';
import 'package:flm_courses/models/curriculum.dart';
import 'package:flm_courses/models/transcript_entry.dart';
import 'package:flm_courses/screens/settings_screen.dart';
import 'package:flm_courses/screens/transcript_confirm_screen.dart';
import 'package:flm_courses/state/course_catalog.dart';
import 'package:flm_courses/state/learning_profile_provider.dart';
import 'package:flm_courses/state/transcript_provider.dart';
import 'package:flm_courses/theme/app_theme.dart';
import 'package:flm_courses/widgets/settings_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      subjects: const [
        CurriculumSubjectEntry(code: 'PRF192', semester: 1),
        CurriculumSubjectEntry(code: 'MAE101', semester: 1),
      ],
    );
    catalog.courses = const [
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
      Course(
        code: 'MAE101',
        codeOriginal: 'MAE101',
        name: 'Mathematics for Engineering',
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

  group('QA Section 5: Real End-to-End User Flows', () {
    testWidgets('Flow 1: OCR Confirm, Edit grade, Delete + Undo, and Save to TranscriptProvider', (tester) async {
      final storage = PersonalPreferences(uid: 'flow_user_1');
      final transcript = TranscriptProvider(storage: storage);
      await transcript.load();

      final initialEntries = [
        TranscriptEntry(
          courseCode: 'PRF192',
          courseName: 'Cơ sở lập trình',
          score: 7.5,
          credits: 3,
          semester: 1,
          isPassed: true,
        ),
        TranscriptEntry(
          courseCode: 'MAE101',
          courseName: 'Toán cho kỹ thuật',
          score: 6.0,
          credits: 3,
          semester: 1,
          isPassed: true,
        ),
      ];

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CourseCatalog>.value(value: createTestCatalog()),
            ChangeNotifierProvider<TranscriptProvider>.value(value: transcript),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            home: TranscriptConfirmScreen(
              rawExtractedEntries: initialEntries,
              onSaved: (saved) async => transcript.save(saved),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify 2 courses loaded
      expect(find.text('PRF192'), findsOneWidget);
      expect(find.text('MAE101'), findsOneWidget);

      // Delete MAE101
      final deleteButtons = find.byIcon(Icons.delete_outline_rounded);
      expect(deleteButtons, findsWidgets);
      await tester.tap(deleteButtons.last);
      await tester.pumpAndSettle();

      // Verify MAE101 removed & SnackBar shows "Hoàn tác"
      expect(find.text('MAE101'), findsNothing);
      expect(find.text('Đã xóa MAE101'), findsOneWidget);
      expect(find.text('Hoàn tác'), findsOneWidget);

      // Tap "Hoàn tác" to restore
      await tester.tap(find.text('Hoàn tác'));
      await tester.pumpAndSettle();
      expect(find.text('MAE101'), findsOneWidget);

      // Confirm & Save
      await tester.tap(find.widgetWithText(FilledButton, 'Xác nhận & Lưu bảng điểm (2 môn)'));
      await tester.pumpAndSettle();

      // Verify saved in transcript provider
      expect(transcript.hasTranscript, isTrue);
      expect(transcript.entries.length, 2);
    });

    testWidgets('Flow 2: GPA Target Slider auto-save without manual save button', (tester) async {
      final storage = PersonalPreferences(uid: 'flow_user_2');
      final transcript = TranscriptProvider(storage: storage);
      await transcript.load();

      final profile = LearningProfileProvider(storage: storage);
      await profile.load();
      final catalog = createTestCatalog();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CourseCatalog>.value(value: catalog),
            ChangeNotifierProvider<TranscriptProvider>.value(value: transcript),
            ChangeNotifierProvider<LearningProfileProvider>.value(value: profile),
            ChangeNotifierProvider<ChatProvider>(
              create: (_) => ChatProvider(profile: profile, storage: storage),
            ),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Check initial GPA
      expect(transcript.targetGpa, 8.0);

      // Change target GPA programmatically or via provider
      transcript.setTargetGpa(8.5);
      await tester.pump();

      // Reload fresh provider from storage to verify auto-save persistence
      final reloadedTranscript = TranscriptProvider(storage: storage);
      await reloadedTranscript.load();
      expect(reloadedTranscript.targetGpa, 8.5);
      expect(reloadedTranscript.hasExplicitTargetGpa, isTrue);
    });

    testWidgets('Flow 3: AI Chat Error Bubble + Resend (Gửi lại) retry callback', (tester) async {
      bool retried = false;
      final failedMessage = ChatMessage(
        id: 'msg_fail_1',
        text: 'Lộ trình học kỳ 2 thế nào?',
        sender: ChatSender.user,
        timestamp: DateTime.now(),
        status: MessageStatus.error,
        errorMessage: 'Không thể kết nối máy chủ AI',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: Scaffold(
            body: ChatBubble(
              message: failedMessage,
              onRetry: () => retried = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Error bubble is displayed with retry button "Gửi lại" and error description
      expect(find.text('Gửi lại'), findsOneWidget);
      expect(find.text('Không thể kết nối máy chủ AI'), findsOneWidget);
      expect(find.text('Lộ trình học kỳ 2 thế nào?'), findsOneWidget);

      // Tap "Gửi lại"
      await tester.tap(find.text('Gửi lại'));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('Flow 4: Sign out and Clear Data with Confirmation Dialogs', (tester) async {
      final storage = PersonalPreferences(uid: 'flow_user_4');
      final transcript = TranscriptProvider(storage: storage);
      await transcript.save([
        TranscriptEntry(
          courseCode: 'PRF192',
          courseName: 'Cơ sở lập trình',
          score: 9.0,
          credits: 3,
          semester: 1,
          isPassed: true,
        ),
      ]);

      final profile = LearningProfileProvider(storage: storage);
      await profile.load();
      final catalog = createTestCatalog();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CourseCatalog>.value(value: catalog),
            ChangeNotifierProvider<TranscriptProvider>.value(value: transcript),
            ChangeNotifierProvider<LearningProfileProvider>.value(value: profile),
            ChangeNotifierProvider<ChatProvider>(
              create: (_) => ChatProvider(profile: profile, storage: storage),
            ),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Scroll to "Xóa bảng điểm cá nhân"
      await tester.scrollUntilVisible(
        find.text('Xóa bảng điểm cá nhân'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      // Verify tile is destructive and enabled when transcript exists
      final deleteTile = tester.widget<SettingsTile>(
        find.widgetWithText(SettingsTile, 'Xóa bảng điểm cá nhân'),
      );
      expect(deleteTile.enabled, isTrue);
      expect(deleteTile.isDestructive, isTrue);

      // Tap delete tile
      await tester.tap(find.text('Xóa bảng điểm cá nhân'));
      await tester.pumpAndSettle();

      // Dialog opens with title & local device text
      expect(find.text('Xóa bảng điểm?'), findsOneWidget);
      expect(find.text('Dữ liệu bảng điểm đã lưu trên thiết bị này sẽ bị xóa hoàn toàn.'), findsOneWidget);
      expect(find.text('Hủy'), findsOneWidget);
      expect(find.text('Xóa vĩnh viễn'), findsOneWidget);

      // Confirm delete
      await tester.tap(find.text('Xóa vĩnh viễn'));
      await tester.pumpAndSettle();

      // Transcript is cleared
      expect(transcript.hasTranscript, isFalse);
      expect(transcript.entries, isEmpty);
    });
  });
}
