import 'dart:collection';
import 'dart:math';
import 'dart:ui';

import '../../../models/course.dart';
import '../models/graph_models.dart';

/// Đồ thị tiên quyết sinh từ `prerequisites` của các Subject (Mục 2.1, 4.3).
class CourseGraph {
  CourseGraph._(this.courseNodes, this.prerequisiteEdges, this.prerequisitesOf, this.dependentsOf);

  final List<GraphNode> courseNodes;
  final List<GraphEdge> prerequisiteEdges;

  /// code → các môn tiên quyết trực tiếp của nó.
  final Map<String, Set<String>> prerequisitesOf;

  /// code → các môn nhận nó làm tiên quyết trực tiếp.
  final Map<String, Set<String>> dependentsOf;

  factory CourseGraph.fromCourses(List<Course> courses) {
    final nodes = <GraphNode>[];
    final known = <String>{};
    for (final course in courses) {
      final code = normalizeCode(course.code);
      if (!known.add(code)) continue;
      nodes.add(GraphNode(
        id: code,
        title: course.nameVi.isNotEmpty ? course.nameVi : course.name,
        semester: course.semester,
        credits: course.credits,
        countsInGpa: course.countsInGpa,
      ));
    }

    final edges = <GraphEdge>[];
    final prerequisitesOf = <String, Set<String>>{for (final n in nodes) n.id: <String>{}};
    final dependentsOf = <String, Set<String>>{for (final n in nodes) n.id: <String>{}};

    for (final course in courses) {
      final to = normalizeCode(course.code);
      final rawPrereqs = course.prerequisitesNorm.isNotEmpty ? course.prerequisitesNorm : course.prerequisites;
      for (final raw in rawPrereqs) {
        final from = normalizeCode(raw);
        // Chỉ nối các môn có trong curriculum đang xem.
        if (from == to || !known.contains(from)) continue;
        if (prerequisitesOf[to]!.add(from)) {
          dependentsOf[from]!.add(to);
          edges.add(GraphEdge(from, to));
        }
      }
    }

    for (final node in nodes) {
      node.degree = prerequisitesOf[node.id]!.length + dependentsOf[node.id]!.length;
    }

    return CourseGraph._(nodes, edges, prerequisitesOf, dependentsOf);
  }

  /// Chuẩn hoá mã môn theo Mục 2.3: viết hoa, bỏ khoảng trắng, gộp Ð (eth) về Đ.
  static String normalizeCode(String code) {
    return code.replaceAll(RegExp(r'\s+'), '').replaceAll('ð', 'đ').replaceAll('Ð', 'Đ').toUpperCase();
  }

  /// Toàn bộ chuỗi tiên quyết ngược về gốc (không gồm chính [code]).
  Set<String> ancestorsOf(String code) {
    final result = <String>{};
    final queue = Queue<String>()..add(code);
    while (queue.isNotEmpty) {
      for (final prereq in prerequisitesOf[queue.removeFirst()] ?? const <String>{}) {
        if (result.add(prereq)) queue.add(prereq);
      }
    }
    result.remove(code);
    return result;
  }

  /// Các môn cách [code] tối đa [depth] cấp (tính cả hai chiều liên kết).
  Set<String> neighborhood(String code, int depth) {
    final visited = <String>{code};
    var frontier = <String>{code};
    for (var level = 0; level < depth && frontier.isNotEmpty; level++) {
      final next = <String>{};
      for (final id in frontier) {
        for (final neighbor in [...?prerequisitesOf[id], ...?dependentsOf[id]]) {
          if (visited.add(neighbor)) next.add(neighbor);
        }
      }
      frontier = next;
    }
    return visited;
  }

  /// Kích thước node tỉ lệ số liên kết, [scale] do người dùng chỉnh.
  static double radiusFor(int degree, double scale) {
    return (9.0 + 3.2 * sqrt(degree.toDouble())) * scale;
  }

  /// Vị trí khởi tạo xác định (cùng dữ liệu → cùng bố cục) để nút Reset cho kết quả ổn định.
  static void seedPositions(List<GraphNode> nodes) {
    final random = Random(393);
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final angle = node.semester / 10 * 2 * pi + random.nextDouble() * 0.6;
      final distance = 120 + random.nextDouble() * 260;
      node
        ..position = Offset(cos(angle) * distance, sin(angle) * distance)
        ..velocity = Offset.zero
        ..pinnedAt = null;
    }
  }
}
