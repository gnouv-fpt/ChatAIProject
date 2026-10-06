import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flm_courses/features/graph/logic/course_graph.dart';
import 'package:flm_courses/features/graph/logic/force_simulation.dart';
import 'package:flm_courses/features/graph/models/graph_models.dart';
import 'package:flm_courses/models/course.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flm_courses/features/graph/views/graph_view_screen.dart';
import 'package:flm_courses/features/graph/views/widgets/graph_control_panel.dart';
import 'package:flm_courses/state/course_catalog.dart';

List<Course> _loadCourses() {
  final json = jsonDecode(File('assets/courses_data.json').readAsStringSync()) as Map<String, dynamic>;
  return (json['courses'] as List).cast<Map<String, dynamic>>().map(Course.fromJson).toList();
}

void _run(ForceSimulation sim, CourseGraph graph, {required bool semesterLayout, int steps = 400}) {
  final byId = {for (final n in graph.courseNodes) n.id: n};
  for (var i = 0; i < steps; i++) {
    sim.step(
      nodes: graph.courseNodes,
      edges: graph.prerequisiteEdges,
      nodeById: byId,
      settings: const ForceSettings(),
      semesterLayout: semesterLayout,
      minSemester: 0,
      maxSemester: 9,
    );
  }
}

void main() {
  testWidgets('Obsidian graph gộp bảng bộ lọc & lộ trình', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final catalog = CourseCatalog()..courses = _loadCourses();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: catalog,
        child: const MaterialApp(home: Scaffold(body: GraphViewScreen())),
      ),
    );
    await tester.pump();
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('Obsidian Graph'), findsNothing);
    expect(find.byType(GraphControlPanel), findsOneWidget);
    expect(find.text('Bộ lọc'), findsOneWidget);

    // Lọc học kỳ & đổi bố cục theo học kỳ không gây lỗi.
    await tester.tap(find.widgetWithText(FilterChip, 'HK1'));
    await tester.pump();
    await tester.tap(find.byTooltip('Sắp xếp theo học kỳ'));
    await tester.pumpAndSettle();

    // Kéo thả trên canvas.
    await tester.drag(find.byType(GestureDetector).first, const Offset(60, 40));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Đặt lại bố cục & bộ lọc'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    catalog.dispose();
  });

  late CourseGraph graph;

  setUp(() {
    graph = CourseGraph.fromCourses(_loadCourses());
    for (final node in graph.courseNodes) {
      node.radius = CourseGraph.radiusFor(node.degree, 1);
    }
    CourseGraph.seedPositions(graph.courseNodes);
  });

  test('cạnh tiên quyết có hướng: môn tiên quyết → môn học sau', () {
    expect(graph.prerequisitesOf['PRO192'], contains('PRF192'));
    expect(graph.dependentsOf['PRF192'], contains('PRO192'));
    expect(
      graph.prerequisiteEdges.any((e) => e.from == 'PRF192' && e.to == 'PRO192'),
      isTrue,
    );
    // Không có cạnh ngược.
    expect(graph.prerequisiteEdges.any((e) => e.from == 'PRO192' && e.to == 'PRF192'), isFalse);
  });

  test('kích thước node tỉ lệ theo số liên kết', () {
    final pro192 = graph.courseNodes.firstWhere((n) => n.id == 'PRO192');
    final otp101 = graph.courseNodes.firstWhere((n) => n.id == 'OTP101');
    expect(pro192.degree, greaterThan(5));
    expect(otp101.degree, 0);
    expect(pro192.radius, greaterThan(otp101.radius));
  });

  test('chuỗi tiên quyết truy ngược về gốc', () {
    // SEP490 ← SWP391 ← PRJ301 ← PRO192 ← PRF192
    final chain = graph.ancestorsOf('SEP490');
    expect(chain, containsAll(['SWP391', 'PRJ301', 'PRO192', 'PRF192', 'DBI202']));
    expect(chain, isNot(contains('SEP490')));
  });

  test('local graph lấy đúng số cấp liên kết', () {
    final depth1 = graph.neighborhood('PRJ301', 1);
    expect(depth1, containsAll(['PRJ301', 'PRO192', 'DBI202', 'SWP391']));
    expect(depth1, isNot(contains('PRF192')));
    expect(graph.neighborhood('PRJ301', 2), contains('PRF192'));
  });

  test('bố cục lực ổn định và gọn quanh tâm', () {
    final sim = ForceSimulation();
    _run(sim, graph, semesterLayout: false);
    expect(sim.isActive, isFalse, reason: 'mô phỏng phải tự dừng khi đã ổn định');
    for (final node in graph.courseNodes) {
      expect(node.position.distance, lessThan(900), reason: '${node.id} trôi quá xa');
    }
  });

  test('"Sắp xếp theo học kỳ" đưa node về đúng cột', () {
    final sim = ForceSimulation();
    _run(sim, graph, semesterLayout: false);
    sim.reheat(1.0);
    _run(sim, graph, semesterLayout: true);
    for (final node in graph.courseNodes) {
      final columnX = ForceSimulation.semesterColumnX(node.semester, 0, 9);
      expect((node.position.dx - columnX).abs(), lessThan(40), reason: '${node.id} lệch cột HK${node.semester}');
    }
  });

  test('node đang kéo được giữ tại vị trí con trỏ', () {
    final sim = ForceSimulation();
    final node = graph.courseNodes.firstWhere((n) => n.id == 'PRO192');
    node.pinnedAt = const Offset(500, -300);
    sim.alphaTarget = 0.3;
    _run(sim, graph, semesterLayout: false, steps: 50);
    expect(node.position, const Offset(500, -300));
    // Môn liên kết bị kéo theo về phía node đang kéo.
    final prf192 = graph.courseNodes.firstWhere((n) => n.id == 'PRF192');
    expect((prf192.position - node.position).distance, lessThan(max(300, sqrt(500 * 500 + 300 * 300) / 2)));
  });
}
