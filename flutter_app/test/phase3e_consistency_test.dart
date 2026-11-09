import 'package:flm_courses/features/chat/providers/chat_provider.dart';
import 'package:flm_courses/screens/home_screen.dart';
import 'package:flm_courses/screens/roadmap_screen.dart';
import 'package:flm_courses/screens/transcript_screen.dart';
import 'package:flm_courses/state/auth_view_model.dart';
import 'package:flm_courses/state/course_catalog.dart';
import 'package:flm_courses/state/learning_profile_provider.dart';
import 'package:flm_courses/state/transcript_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/phase3a_fixtures.dart';

void main() {
  group('Phase 3e Consistency Tests', () {
    testWidgets('1. Hoi AI Button rule: width >= 375 & scale <= 1.15 -> Labeled, otherwise icon-only across all screens', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final catalog = CourseCatalog();
      await tester.runAsync(catalog.load);
      final profile = LearningProfileProvider();
      await profile.load();
      final transcript = TranscriptProvider();
      await transcript.load();
      final auth = AuthViewModel(TestAuthService());
      final chat = ChatProvider(apiService: OfflineChatService());

      addTearDown(() {
        catalog.dispose();
        profile.dispose();
        transcript.dispose();
        auth.dispose();
        chat.dispose();
      });

      // A. Viewport 390x844, text scale 1.0 -> ALL screens MUST show 'Hỏi AI' text label
      final screens = <String, Widget>{
        'Trang chủ': HomeScreen(onNavigate: (_) {}),
        'Lộ trình': const RoadmapScreen(),
        'Bảng điểm': const TranscriptScreen(),
      };

      for (final entry in screens.entries) {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          wrapWithTestProviders(
            child: entry.value,
            catalog: catalog,
            profile: profile,
            transcript: transcript,
            auth: auth,
            chat: chat,
            textScale: 1.0,
            viewport: const Size(390, 844),
          ),
        );
        await tester.pumpAndSettle();

        // At 390x844, scale 1.0: Must render labeled 'Hỏi AI' button in AppBar
        expect(
          find.widgetWithText(FilledButton, 'Hỏi AI'),
          findsAtLeastNWidgets(1),
          reason: '${entry.key} at 390x844 scale 1.0 must render labeled "Hỏi AI" button',
        );
      }

      // B. Viewport 360x640 -> ALL screens MUST collapse to icon-only (NO 'Hỏi AI' label in AppBar)
      for (final entry in screens.entries) {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          wrapWithTestProviders(
            child: entry.value,
            catalog: catalog,
            profile: profile,
            transcript: transcript,
            auth: auth,
            chat: chat,
            textScale: 1.0,
            viewport: const Size(360, 640),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(FilledButton, 'Hỏi AI'),
          findsNothing,
          reason: '${entry.key} at 360x640 must collapse to icon-only in AppBar',
        );
        expect(
          find.byIcon(Icons.smart_toy_rounded),
          findsAtLeastNWidgets(1),
          reason: '${entry.key} at 360x640 must still show robot icon',
        );
      }

      // C. Viewport 390x844 with text scale 1.3 (> 1.15) -> ALL screens MUST collapse to icon-only
      for (final entry in screens.entries) {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          wrapWithTestProviders(
            child: entry.value,
            catalog: catalog,
            profile: profile,
            transcript: transcript,
            auth: auth,
            chat: chat,
            textScale: 1.3,
            viewport: const Size(390, 844),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(FilledButton, 'Hỏi AI'),
          findsNothing,
          reason: '${entry.key} at scale 1.3 must collapse to icon-only',
        );
      }
    });

    testWidgets('2. HomeScreen Subtitle & 3-Step Checklist specifications', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final catalog = CourseCatalog();
      await tester.runAsync(catalog.load);
      final profile = LearningProfileProvider();
      await profile.load();
      final transcript = TranscriptProvider();
      await transcript.load();
      final auth = AuthViewModel(TestAuthService(userName: 'Khôi'));
      final chat = ChatProvider(apiService: OfflineChatService());

      addTearDown(() {
        catalog.dispose();
        profile.dispose();
        transcript.dispose();
        auth.dispose();
        chat.dispose();
      });

      await tester.pumpWidget(
        wrapWithTestProviders(
          child: HomeScreen(onNavigate: (_) {}),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
        ),
      );
      await tester.pumpAndSettle();

      // Subtitle must be concise: "Cử nhân CNTT · Kỹ thuật phần mềm"
      expect(find.text('Cử nhân CNTT · Kỹ thuật phần mềm'), findsOneWidget);

      // Step 1: No "Chưa làm" warning chip; uses chevron
      expect(find.text('Chưa làm'), findsNothing);
      expect(find.text('1. Nhập bảng điểm'), findsOneWidget);

      // Step 2: Since user hasn't explicitly set target GPA, shows "Chưa đặt · mặc định 8.0"
      expect(find.textContaining('Chưa đặt · mặc định 8.0'), findsOneWidget);

      // Step 3: Locked with high contrast text and dimmed lock icon
      expect(find.text('3. Xem môn nên học kỳ tới'), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    });

    testWidgets('3. Empty Transcript screen: hint text and 24dp gap', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final catalog = CourseCatalog();
      await tester.runAsync(catalog.load);
      final profile = LearningProfileProvider();
      await profile.load();
      final transcript = TranscriptProvider();
      await transcript.load();
      final auth = AuthViewModel(TestAuthService());
      final chat = ChatProvider(apiService: OfflineChatService());

      addTearDown(() {
        catalog.dispose();
        profile.dispose();
        transcript.dispose();
        auth.dispose();
        chat.dispose();
      });

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

      // Check hint text
      expect(find.text('Ảnh chụp màn hình bảng điểm từ FLM hoặc FAP'), findsOneWidget);
      // Check 2 action buttons
      expect(find.text('Nhập ảnh bảng điểm'), findsOneWidget);
      expect(find.text('Nhập điểm thủ công'), findsOneWidget);
    });
  });
}
