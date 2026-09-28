import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/graph_models.dart';

/// Nhóm node đang được làm nổi bật: hover một node, hoặc bật "Chuỗi tiên quyết".
class GraphHighlight {
  const GraphHighlight.none()
      : focusId = null,
        prerequisites = const {},
        dependents = const {},
        chain = const {};

  const GraphHighlight.focus(String this.focusId, {required this.prerequisites, required this.dependents})
      : chain = const {};

  const GraphHighlight.chain(String rootId, this.chain)
      : focusId = rootId,
        prerequisites = const {},
        dependents = const {};

  final String? focusId;
  final Set<String> prerequisites;
  final Set<String> dependents;

  /// Toàn bộ chuỗi tiên quyết (gồm cả node gốc) khi ở chế độ chuỗi.
  final Set<String> chain;

  bool get isActive => focusId != null;
  bool get isChain => chain.isNotEmpty;

  bool contains(String id) => id == focusId || prerequisites.contains(id) || dependents.contains(id) || chain.contains(id);
}

class GraphDisplaySettings {
  const GraphDisplaySettings({
    this.showLabels = true,
    this.showArrows = true,
    this.edgeWidth = 1.4,
    this.nodeScale = 1.0,
    this.colorByStatus = false,
  });

  final bool showLabels;
  final bool showArrows;
  final double edgeWidth;
  final double nodeScale;
  final bool colorByStatus;

  GraphDisplaySettings copyWith({
    bool? showLabels,
    bool? showArrows,
    double? edgeWidth,
    double? nodeScale,
    bool? colorByStatus,
  }) {
    return GraphDisplaySettings(
      showLabels: showLabels ?? this.showLabels,
      showArrows: showArrows ?? this.showArrows,
      edgeWidth: edgeWidth ?? this.edgeWidth,
      nodeScale: nodeScale ?? this.nodeScale,
      colorByStatus: colorByStatus ?? this.colorByStatus,
    );
  }
}

/// Vẽ đồ thị trong toạ độ world rồi biến đổi theo camera (zoom/pan).
/// Đọc trực tiếp vị trí node đang mô phỏng; [repaint] báo mỗi khung hình.
class GraphPainter extends CustomPainter {
  GraphPainter({
    required Listenable repaint,
    required this.nodes,
    required this.edges,
    required this.nodeById,
    required this.cameraScale,
    required this.cameraOffset,
    required this.highlight,
    required this.highlightProgress,
    required this.selectedId,
    required this.searchMatches,
    required this.display,
    required this.statuses,
    this.semesterColumns = const {},
  }) : super(repaint: repaint);

  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final Map<String, GraphNode> nodeById;
  final double Function() cameraScale;
  final Offset Function() cameraOffset;
  final GraphHighlight Function() highlight;
  final double Function() highlightProgress;
  final String? selectedId;
  final Set<String> searchMatches;
  final GraphDisplaySettings display;
  final Map<String, CourseProgressStatus> statuses;

  /// Học kỳ → toạ độ x của cột; khác rỗng khi bật "Sắp xếp theo học kỳ".
  final Map<int, double> semesterColumns;

  static const Color _edgeColor = Color(0xFFB8C2D1);
  static const Color _membershipEdgeColor = Color(0xFFD9DEE7);
  static const Color _labelColor = Color(0xFF334155);

  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _fill = Paint()..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = cameraScale();
    final hl = highlight();
    final t = hl.isActive ? highlightProgress() : 0.0;

    canvas.save();
    canvas.translate(cameraOffset().dx, cameraOffset().dy);
    canvas.scale(scale);

    _paintSemesterColumns(canvas, scale);
    for (final edge in edges) {
      _paintEdge(canvas, edge, hl, t, scale);
    }
    for (final node in nodes) {
      _paintNode(canvas, node, hl, t, scale);
    }
    canvas.restore();
  }

  void _paintSemesterColumns(Canvas canvas, double scale) {
    if (semesterColumns.isEmpty || nodes.isEmpty) return;
    final top = nodes.map((n) => n.position.dy - n.radius).reduce(min) - 44 / scale;
    final bottom = nodes.map((n) => n.position.dy + n.radius).reduce(max) + 30 / scale;
    for (final entry in semesterColumns.entries) {
      final color = semesterColor(entry.key);
      _stroke
        ..color = color.withValues(alpha: 0.18)
        ..strokeWidth = 1.2 / scale;
      canvas.drawLine(Offset(entry.value, top + 26 / scale), Offset(entry.value, bottom), _stroke);
      final painter = TextPainter(
        text: TextSpan(
          text: semesterLabel(entry.key),
          style: TextStyle(fontSize: 14 / scale, fontWeight: FontWeight.w800, color: color),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(entry.value - painter.width / 2, top));
    }
  }

  void _paintEdge(Canvas canvas, GraphEdge edge, GraphHighlight hl, double t, double scale) {
    final from = nodeById[edge.from];
    final to = nodeById[edge.to];
    if (from == null || to == null) return;

    Color color = edge.isPrerequisite ? _edgeColor : _membershipEdgeColor;
    double width = edge.isPrerequisite ? display.edgeWidth : display.edgeWidth * 0.6;
    double opacity = edge.isPrerequisite ? 0.85 : 0.6;

    if (hl.isActive) {
      final highlightColor = _edgeHighlightColor(edge, hl);
      if (highlightColor != null) {
        color = Color.lerp(color, highlightColor, t)!;
        width = lerpDouble(width, display.edgeWidth * 2.2, t)!;
        opacity = lerpDouble(opacity, 1.0, t)!;
      } else {
        opacity = lerpDouble(opacity, 0.06, t)!;
      }
    }
    if (opacity < 0.02) return;

    final direction = to.position - from.position;
    final distance = direction.distance;
    if (distance < 1) return;
    final unit = direction / distance;
    final start = from.position + unit * from.radius;
    final end = to.position - unit * (to.radius + 1.5);

    _stroke
      ..color = color.withValues(alpha: opacity)
      ..strokeWidth = width / sqrt(scale).clamp(0.7, 1.4);
    canvas.drawLine(start, end, _stroke);

    if (display.showArrows && edge.isPrerequisite) {
      final arrowSize = 5.5 + width * 1.6;
      final angle = atan2(unit.dy, unit.dx);
      final path = Path()
        ..moveTo(end.dx, end.dy)
        ..lineTo(end.dx - arrowSize * cos(angle - pi / 7), end.dy - arrowSize * sin(angle - pi / 7))
        ..lineTo(end.dx - arrowSize * cos(angle + pi / 7), end.dy - arrowSize * sin(angle + pi / 7))
        ..close();
      _fill.color = color.withValues(alpha: opacity);
      canvas.drawPath(path, _fill);
    }
  }

  Color? _edgeHighlightColor(GraphEdge edge, GraphHighlight hl) {
    if (!edge.isPrerequisite) return null;
    if (hl.isChain) {
      return hl.chain.contains(edge.from) && hl.chain.contains(edge.to) ? kPrerequisiteColor : null;
    }
    if (edge.to == hl.focusId) return kPrerequisiteColor;
    if (edge.from == hl.focusId) return kDependentColor;
    return null;
  }

  void _paintNode(Canvas canvas, GraphNode node, GraphHighlight hl, double t, double scale) {
    final isFocus = node.id == hl.focusId;
    final isRelated = hl.contains(node.id);
    final isSearched = searchMatches.contains(node.id);
    final isSelected = node.id == selectedId;
    final opacity = hl.isActive && !isRelated ? lerpDouble(1.0, 0.12, t)! : 1.0;

    final status = statuses[node.id];
    final baseColor = display.colorByStatus && status != null ? status.color : semesterColor(node.semester);
    final pos = node.position;

    // Vòng nhận diện: môn tiên quyết / phụ thuộc / tìm kiếm / đang chọn.
    Color? ringColor;
    if (isSearched) {
      ringColor = kSearchColor;
    } else if (isFocus) {
      ringColor = kSelectionColor;
    } else if (hl.prerequisites.contains(node.id) || hl.chain.contains(node.id)) {
      ringColor = kPrerequisiteColor;
    } else if (hl.dependents.contains(node.id)) {
      ringColor = kDependentColor;
    }
    if (ringColor != null) {
      final ringOpacity = isSearched ? 1.0 : t;
      _stroke
        ..color = ringColor.withValues(alpha: 0.85 * ringOpacity)
        ..strokeWidth = 4;
      canvas.drawCircle(pos, node.radius + 4.5, _stroke);
    }
    if (isSelected) {
      _stroke
        ..color = kSelectionColor.withValues(alpha: opacity)
        ..strokeWidth = 2.5;
      canvas.drawCircle(pos, node.radius + (ringColor != null ? 9 : 5), _stroke);
    }

    if (node.isSemesterNode) {
      final rect = RRect.fromRectAndRadius(Rect.fromCircle(center: pos, radius: node.radius), const Radius.circular(6));
      _fill.color = Colors.white.withValues(alpha: opacity);
      canvas.drawRRect(rect, _fill);
      _stroke
        ..color = baseColor.withValues(alpha: opacity)
        ..strokeWidth = 2.5;
      canvas.drawRRect(rect, _stroke);
    } else {
      _fill.color = baseColor.withValues(alpha: opacity);
      canvas.drawCircle(pos, node.radius, _fill);
      _stroke
        ..color = Colors.white.withValues(alpha: 0.9 * opacity)
        ..strokeWidth = 1.5;
      canvas.drawCircle(pos, node.radius, _stroke);
      if (!node.countsInGpa) {
        // Chấm rỗng giữa node: môn không tính GPA.
        _fill.color = Colors.white.withValues(alpha: 0.85 * opacity);
        canvas.drawCircle(pos, node.radius * 0.32, _fill);
      }
    }

    final emphasized = isFocus || isSearched || isSelected || (hl.isActive && isRelated);
    if (!_shouldShowLabel(node, scale, emphasized)) return;

    // Cỡ chữ quy về ~13px trên màn hình để luôn đọc được (Mục 8.4).
    final fontSize = ((emphasized ? 14.0 : 12.5) / scale).clamp(8.0, 30.0);
    final painter = TextPainter(
      text: TextSpan(
        text: node.isSemesterNode ? semesterLabel(node.semester) : node.id,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
          color: (emphasized ? const Color(0xFF0F172A) : _labelColor).withValues(alpha: opacity),
          shadows: [Shadow(color: Colors.white.withValues(alpha: opacity), blurRadius: 3 / scale)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(pos.dx - painter.width / 2, pos.dy + node.radius + 3));
  }

  /// Nhãn theo mức zoom: thu nhỏ chỉ hiện nhãn node lớn, phóng to hiện tất cả.
  bool _shouldShowLabel(GraphNode node, double scale, bool emphasized) {
    if (emphasized || node.isSemesterNode) return true;
    if (!display.showLabels) return false;
    // Đồ thị nhỏ (local graph, đã lọc) không lo chồng chữ nên luôn hiện nhãn.
    if (scale >= 0.9 || nodes.length <= 20) return true;
    if (scale >= 0.6) return node.degree >= 2;
    if (scale >= 0.4) return node.degree >= 4;
    return node.degree >= 7;
  }

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) => true;
}
