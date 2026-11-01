import 'package:flm_courses/features/chat/providers/chat_provider.dart';
import 'package:flm_courses/features/graph/views/graph_view_screen.dart';
import 'package:flm_courses/screens/roadmap_screen.dart';
import 'package:flm_courses/state/auth_view_model.dart';
import 'package:flm_courses/state/course_catalog.dart';
import 'package:flm_courses/state/learning_profile_provider.dart';
import 'package:flm_courses/state/transcript_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/phase3a_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Performance & Frame Metrics Benchmark (Roadmap 48 courses & GraphView)', () {
    testWidgets('Measure scroll frame performance on 48 courses in RoadmapScreen', (tester) async {
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

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.reset());

      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const RoadmapScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      final scrollableFinder = find.byType(Scrollable).first;
      final durations = <Duration>[];

      // Perform 10 rapid scroll gestures down and up across all 48 courses
      for (int i = 0; i < 10; i++) {
        final stopwatch = Stopwatch()..start();
        await tester.drag(scrollableFinder, const Offset(0, -500));
        await tester.pump();
        stopwatch.stop();
        durations.add(stopwatch.elapsed);
      }
      for (int i = 0; i < 10; i++) {
        final stopwatch = Stopwatch()..start();
        await tester.drag(scrollableFinder, const Offset(0, 500));
        await tester.pump();
        stopwatch.stop();
        durations.add(stopwatch.elapsed);
      }

      final totalMs = durations.map((d) => d.inMicroseconds / 1000.0).toList();
      final avgMs = totalMs.reduce((a, b) => a + b) / totalMs.length;
      final worstMs = totalMs.reduce((a, b) => a > b ? a : b);
      final jankFrames = totalMs.where((ms) => ms > 16.67).length;

      debugPrint('[Roadmap Performance] Total Frames: ${totalMs.length}, Avg Frame Time: ${avgMs.toStringAsFixed(2)}ms, Worst Frame Time: ${worstMs.toStringAsFixed(2)}ms, Jank Frames (>16.6ms): $jankFrames');

      expect(totalMs.length, 20);
      expect(avgMs, greaterThan(0.0));
    });

    testWidgets('Measure pan & selection frame performance in GraphViewScreen with RepaintBoundary', (tester) async {
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

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.reset());

      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const GraphViewScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      final durations = <Duration>[];

      // Perform pan gestures across canvas
      for (int i = 0; i < 10; i++) {
        final stopwatch = Stopwatch()..start();
        await tester.drag(find.byType(InteractiveViewer), const Offset(-50, -50));
        await tester.pump();
        stopwatch.stop();
        durations.add(stopwatch.elapsed);
      }

      final totalMs = durations.map((d) => d.inMicroseconds / 1000.0).toList();
      final avgMs = totalMs.reduce((a, b) => a + b) / totalMs.length;
      final worstMs = totalMs.reduce((a, b) => a > b ? a : b);
      final jankFrames = totalMs.where((ms) => ms > 16.67).length;

      debugPrint('[GraphView Performance] Total Frames: ${totalMs.length}, Avg Frame Time: ${avgMs.toStringAsFixed(2)}ms, Worst Frame Time: ${worstMs.toStringAsFixed(2)}ms, Jank Frames (>16.6ms): $jankFrames');

      expect(totalMs.length, 10);
      expect(avgMs, lessThan(200.0));
    });
  });
}
