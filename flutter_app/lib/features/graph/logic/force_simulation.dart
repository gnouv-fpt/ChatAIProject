import 'dart:math';
import 'dart:ui';

import '../models/graph_models.dart';

/// Mô phỏng lực kiểu d3-force: node đẩy nhau, cạnh kéo nhau, lực hút về tâm.
/// `alpha` giảm dần mỗi bước nên đồ thị chuyển động mượt rồi dừng hẳn.
class ForceSimulation {
  static const double _alphaMin = 0.002;
  static const double _alphaDecay = 0.025;
  static const double _velocityDecay = 0.42;
  static const double _semesterColumnGap = 190;

  /// Bỏ qua lực đẩy ở khoảng cách xa để các cụm/môn cô lập không trôi quá xa.
  static const double _repulsionRange = 320;

  double alpha = 1.0;

  /// Giữ alpha ở mức này khi đang kéo node để các node liên kết đi theo.
  double alphaTarget = 0.0;

  bool get isActive => alpha > _alphaMin || alphaTarget > 0;

  /// Toạ độ x của cột học kỳ trong bố cục "Sắp xếp theo học kỳ".
  static double semesterColumnX(int semester, int minSemester, int maxSemester) {
    return (semester - (minSemester + maxSemester) / 2) * _semesterColumnGap;
  }

  void reheat([double value = 0.8]) => alpha = max(alpha, value);

  /// Chạy một bước mô phỏng trên các node/cạnh đang hiển thị.
  void step({
    required List<GraphNode> nodes,
    required List<GraphEdge> edges,
    required Map<String, GraphNode> nodeById,
    required ForceSettings settings,
    required bool semesterLayout,
    required int minSemester,
    required int maxSemester,
  }) {
    alpha += (alphaTarget - alpha) * _alphaDecay;
    final a = alpha;

    // 1. Lực đẩy giữa mọi cặp node (vài chục node nên O(n²) vẫn nhẹ) + chống chồng lấn.
    for (var i = 0; i < nodes.length; i++) {
      final ni = nodes[i];
      for (var j = i + 1; j < nodes.length; j++) {
        final nj = nodes[j];
        var d = nj.position - ni.position;
        var dist2 = d.distanceSquared;
        if (dist2 < 1) {
          d = Offset(cos(i + j.toDouble()), sin(i + j.toDouble()));
          dist2 = 1;
        }
        if (dist2 > _repulsionRange * _repulsionRange) continue;
        final dist = sqrt(dist2);
        var push = settings.repulsion * a / dist2;
        final minGap = ni.radius + nj.radius + 14;
        if (dist < minGap) push += (minGap - dist) / dist * 0.5;
        final f = d * push;
        ni.velocity -= f;
        nj.velocity += f;
      }
    }

    // 2. Lực lò xo dọc theo cạnh.
    for (final edge in edges) {
      final source = nodeById[edge.from];
      final target = nodeById[edge.to];
      if (source == null || target == null) continue;
      final d = target.position - source.position;
      final dist = max(d.distance, 1.0);
      final restLength = edge.isPrerequisite ? settings.linkDistance : settings.linkDistance * 0.8;
      // Chế độ học kỳ: giảm lò xo để cạnh không kéo node lệch khỏi cột.
      final strength = (edge.isPrerequisite ? 0.35 : 0.12) * (semesterLayout ? 0.25 : 1.0);
      final f = d * ((dist - restLength) / dist * strength * a * 0.5);
      target.velocity -= f;
      source.velocity += f;
    }

    // 3. Lực hút về tâm, hoặc kéo về cột học kỳ khi bật "Sắp xếp theo học kỳ".
    for (final node in nodes) {
      if (semesterLayout) {
        final targetX = semesterColumnX(node.semester, minSemester, maxSemester);
        // Lực kéo về cột không giảm theo alpha để các cột luôn thẳng hàng HK1 → HKn.
        node.velocity += Offset((targetX - node.position.dx) * 0.12, -node.position.dy * settings.centerGravity * a);
      } else {
        // Môn cô lập được hút mạnh hơn để bám quanh cụm chính như Obsidian.
        final gravity = node.degree == 0 && !node.isSemesterNode ? settings.centerGravity * 2.5 : settings.centerGravity;
        node.velocity -= node.position * (gravity * a);
      }
    }

    // 4. Tích phân vị trí; node đang kéo bị giữ tại con trỏ.
    for (final node in nodes) {
      final pinned = node.pinnedAt;
      if (pinned != null) {
        node
          ..position = pinned
          ..velocity = Offset.zero;
        continue;
      }
      node.velocity *= 1 - _velocityDecay;
      final speed = node.velocity.distance;
      if (speed > 60) node.velocity = node.velocity * (60 / speed);
      node.position += node.velocity;
    }
  }
}
