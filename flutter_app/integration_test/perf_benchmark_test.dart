import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flm_courses/state/course_catalog.dart';
import 'package:flm_courses/state/learning_profile_provider.dart';
import 'package:flm_courses/state/transcript_provider.dart';
import 'package:flm_courses/state/auth_view_model.dart';
import 'package:flm_courses/features/chat/providers/chat_provider.dart';
import 'package:flm_courses/screens/roadmap_screen.dart';
import 'package:flm_courses/features/graph/views/graph_view_screen.dart';

import '../test/fixtures/phase3a_fixtures.dart';

class PerformanceStats {
  final List<double> buildTimes;
  final List<double> rasterTimes;
  final List<double> totalTimes;

  PerformanceStats({
    required this.buildTimes,
    required this.rasterTimes,
    required this.totalTimes,
  });

  double get avgBuild => buildTimes.isEmpty
      ? 0
      : buildTimes.reduce((a, b) => a + b) / buildTimes.length;
  double get avgRaster => rasterTimes.isEmpty
      ? 0
      : rasterTimes.reduce((a, b) => a + b) / rasterTimes.length;
  double get avgTotal => totalTimes.isEmpty
      ? 0
      : totalTimes.reduce((a, b) => a + b) / totalTimes.length;

  double get p90Build => _percentile(buildTimes, 0.90);
  double get p90Raster => _percentile(rasterTimes, 0.90);
  double get p90Total => _percentile(totalTimes, 0.90);

  double get worstBuild =>
      buildTimes.isEmpty ? 0 : buildTimes.reduce((a, b) => a > b ? a : b);
  double get worstRaster =>
      rasterTimes.isEmpty ? 0 : rasterTimes.reduce((a, b) => a > b ? a : b);
  double get worstTotal =>
      totalTimes.isEmpty ? 0 : totalTimes.reduce((a, b) => a > b ? a : b);

  int get missedBuildCount => buildTimes.where((t) => t > 16.67).length;
  int get missedRasterCount => rasterTimes.where((t) => t > 16.67).length;
  int get missedTotalCount => totalTimes.where((t) => t > 16.67).length;

  double get missedTotalPct =>
      totalTimes.isEmpty ? 0 : (missedTotalCount / totalTimes.length) * 100.0;

  static double _percentile(List<double> list, double p) {
    if (list.isEmpty) return 0;
    final sorted = List<double>.from(list)..sort();
    final index = (sorted.length * p).floor().clamp(0, sorted.length - 1);
    return sorted[index];
  }

  Map<String, dynamic> toMap() => {
    'total_frames': totalTimes.length,
    'build_avg': avgBuild,
    'build_p90': p90Build,
    'build_worst': worstBuild,
    'raster_avg': avgRaster,
    'raster_p90': p90Raster,
    'raster_worst': worstRaster,
    'missed_frames': missedTotalCount,
    'missed_pct': missedTotalPct,
  };

  @override
  String toString() {
    return 'Frames: ${totalTimes.length} | Build(avg: ${avgBuild.toStringAsFixed(2)}ms, p90: ${p90Build.toStringAsFixed(2)}ms, worst: ${worstBuild.toStringAsFixed(2)}ms) | '
        'Raster(avg: ${avgRaster.toStringAsFixed(2)}ms, p90: ${p90Raster.toStringAsFixed(2)}ms, worst: ${worstRaster.toStringAsFixed(2)}ms) | '
        'Missed: $missedTotalCount (${missedTotalPct.toStringAsFixed(1)}%)';
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Profile Mode Real Performance Benchmarks', () {
    testWidgets('1. Benchmark RoadmapScreen 48 Courses Scrolling', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final catalog = CourseCatalog();
      await tester.runAsync(catalog.load);
      final profile = LearningProfileProvider();
      await profile.load();
      final transcript = TranscriptProvider();
      await transcript.load();
      final auth = AuthViewModel(TestAuthService());
      final chat = ChatProvider(profile: profile);

      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const RoadmapScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
        ),
      );
      await tester.pumpAndSettle();

      final List<FrameTiming> timings = [];
      void callback(List<FrameTiming> t) => timings.addAll(t);
      WidgetsBinding.instance.addTimingsCallback(callback);

      try {
        final scrollable = find.byType(Scrollable).first;

        // Perform 10 rapid flings down and up
        for (int i = 0; i < 5; i++) {
          await tester.fling(scrollable, const Offset(0, -600), 2000);
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(const Duration(milliseconds: 100));
        }
        for (int i = 0; i < 5; i++) {
          await tester.fling(scrollable, const Offset(0, 600), 2000);
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pumpAndSettle();
      } finally {
        WidgetsBinding.instance.removeTimingsCallback(callback);
      }

      final buildTimes = timings
          .map((t) => t.buildDuration.inMicroseconds / 1000.0)
          .toList();
      final rasterTimes = timings
          .map((t) => t.rasterDuration.inMicroseconds / 1000.0)
          .toList();
      final totalTimes = timings
          .map((t) => t.totalSpan.inMicroseconds / 1000.0)
          .toList();

      final stats = PerformanceStats(
        buildTimes: buildTimes,
        rasterTimes: rasterTimes,
        totalTimes: totalTimes,
      );

      debugPrint('[PERF_BENCHMARK_ROADMAP_RESULT] ${stats.toString()}');
    });

    testWidgets('2. Benchmark GraphViewScreen Pan and Zoom Canvas', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final catalog = CourseCatalog();
      await tester.runAsync(catalog.load);
      final profile = LearningProfileProvider();
      await profile.load();
      final transcript = TranscriptProvider();
      await transcript.load();
      final auth = AuthViewModel(TestAuthService());
      final chat = ChatProvider(profile: profile);

      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const GraphViewScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
        ),
      );
      await tester.pumpAndSettle();

      final List<FrameTiming> timings = [];
      void callback(List<FrameTiming> t) => timings.addAll(t);
      WidgetsBinding.instance.addTimingsCallback(callback);

      try {
        final interactive = find.byType(InteractiveViewer);

        // Perform 8 multi-directional pans across the node canvas
        for (int i = 0; i < 4; i++) {
          await tester.drag(interactive, const Offset(-150, -100));
          await tester.pump(const Duration(milliseconds: 100));
        }
        for (int i = 0; i < 4; i++) {
          await tester.drag(interactive, const Offset(150, 100));
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pumpAndSettle();
      } finally {
        WidgetsBinding.instance.removeTimingsCallback(callback);
      }

      final buildTimes = timings
          .map((t) => t.buildDuration.inMicroseconds / 1000.0)
          .toList();
      final rasterTimes = timings
          .map((t) => t.rasterDuration.inMicroseconds / 1000.0)
          .toList();
      final totalTimes = timings
          .map((t) => t.totalSpan.inMicroseconds / 1000.0)
          .toList();

      final stats = PerformanceStats(
        buildTimes: buildTimes,
        rasterTimes: rasterTimes,
        totalTimes: totalTimes,
      );

      debugPrint('[PERF_BENCHMARK_GRAPHVIEW_RESULT] ${stats.toString()}');
    });
  });
}
