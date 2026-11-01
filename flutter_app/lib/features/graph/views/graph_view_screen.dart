import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/course.dart';
import '../../../state/course_catalog.dart';
import '../../../state/transcript_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_ui.dart';
import '../../../widgets/course_visuals.dart';
import '../../../widgets/m3_components.dart';

const _canvasSize = Size(1600, 1100);

class _GraphNode {
  _GraphNode(this.course, this.position);
  final Course course;
  Offset position;
  Offset velocity = Offset.zero;
  double radius = 15;
}

class _GraphEdge {
  const _GraphEdge(this.from, this.to);
  final String from;
  final String to;
}

class GraphViewScreen extends StatefulWidget {
  const GraphViewScreen({
    super.key,
    this.selectedCode,
    this.onNodeSelected,
    this.onOpenDetail,
    this.onAdvisorRequested,
  });

  final String? selectedCode;
  final ValueChanged<String?>? onNodeSelected;
  final ValueChanged<String>? onOpenDetail;
  final ValueChanged<String>? onAdvisorRequested;

  @override
  State<GraphViewScreen> createState() => _GraphViewScreenState();
}

class _GraphViewScreenState extends State<GraphViewScreen>
    with SingleTickerProviderStateMixin {
  final TransformationController _transform = TransformationController();
  final Map<String, _GraphNode> _nodes = {};
  final List<_GraphEdge> _edges = [];
  late final AnimationController _ticker;
  String? _hovered;
  String? _selected;
  String? _dragging;
  String _search = '';
  int? _semesterFilter;
  String _statusFilter = 'all';
  bool? _gpaFilter;
  bool? _prerequisiteFilter;
  bool _hideIsolated = false;
  bool _semesterLayout = false;
  bool _localGraph = false;
  bool _showLabels = true;
  bool _showArrows = true;
  final bool _showSemesterNodes = false;
  final double _repulsion = 1800;
  final double _spring = 0.003;
  final double _linkLength = 135;
  final double _centerForce = 0.00025;
  final double _edgeWidth = 1.2;
  final double _nodeSize = 1;
  int _depth = 1;
  bool _initialFit = false;
  bool _controlsOpen = false;
  bool _showLegend = false;
  bool _useStatusColors = false;
  Size _viewport = Size.zero;
  int _frames = 0;
  bool _highlightAncestors = false;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_step);
    _loadLegendPreference();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadGraph();
    });
  }

  Future<void> _loadLegendPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool('flm_graph_legend_open');
      if (mounted) {
        setState(() {
          // Open by default on first visit (saved == null -> true)
          _showLegend = saved ?? true;
        });
      }
    } catch (_) {
      // Default to open
      if (mounted) setState(() => _showLegend = true);
    }
  }

  Future<void> _toggleLegend() async {
    final next = !_showLegend;
    setState(() => _showLegend = next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('flm_graph_legend_open', next);
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant GraphViewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedCode != oldWidget.selectedCode &&
        widget.selectedCode != null) {
      setState(() => _selected = widget.selectedCode);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _loadGraph() {
    final courses = context
        .read<CourseCatalog>()
        .courses
        .where((course) => course.inCurriculum)
        .toList();
    final random = Random(19);
    _nodes.clear();
    _edges.clear();
    for (final course in courses) {
      final angle = random.nextDouble() * 2 * pi;
      final distance = 180 + random.nextDouble() * 260;
      _nodes[course.code.toUpperCase()] = _GraphNode(
        course,
        Offset(800 + cos(angle) * distance, 550 + sin(angle) * distance),
      );
    }
    final seen = <String>{};
    for (final course in courses) {
      for (final raw in course.prerequisitesNorm.isNotEmpty
          ? course.prerequisitesNorm
          : course.prerequisites) {
        final prerequisite = raw.trim().toUpperCase().replaceAll('Ð', 'Đ');
        final dependent = course.code.toUpperCase();
        if (!_nodes.containsKey(prerequisite) || prerequisite == dependent) {
          continue;
        }
        if (seen.add('$prerequisite>$dependent')) {
          _edges.add(_GraphEdge(prerequisite, dependent));
        }
      }
    }
    for (final node in _nodes.values) {
      final degree = _edges
          .where(
            (edge) =>
                edge.from == node.course.code || edge.to == node.course.code,
          )
          .length;
      node.radius = 14 + min(13, degree * 3).toDouble();
    }
    _selected = widget.selectedCode;
    _startSimulation();
  }

  void _startSimulation() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _arrangeBySemester();
      return;
    }
    _frames = 0;
    _ticker.repeat();
    setState(() {});
  }

  void _step() {
    if (_semesterLayout || _nodes.isEmpty || _frames++ > 300) {
      _ticker.stop();
      return;
    }
    final nodes = _nodes.values.toList();
    final forces = {for (final node in nodes) node.course.code: Offset.zero};
    for (var i = 0; i < nodes.length; i++) {
      for (var j = i + 1; j < nodes.length; j++) {
        final delta = nodes[i].position - nodes[j].position;
        final distance = max(25.0, delta.distance);
        final push = delta / distance * (_repulsion / (distance * distance));
        forces[nodes[i].course.code] = forces[nodes[i].course.code]! + push;
        forces[nodes[j].course.code] = forces[nodes[j].course.code]! - push;
      }
    }
    for (final edge in _edges) {
      final first = _nodes[edge.from]!;
      final second = _nodes[edge.to]!;
      final delta = second.position - first.position;
      final distance = max(1.0, delta.distance);
      final pull = delta / distance * ((distance - _linkLength) * _spring);
      forces[edge.from] = forces[edge.from]! + pull;
      forces[edge.to] = forces[edge.to]! - pull;
    }
    for (final node in nodes) {
      if (node.course.code == _dragging) continue;
      final toCenter = const Offset(800, 550) - node.position;
      node.velocity =
          (node.velocity +
              forces[node.course.code]! +
              toCenter * _centerForce) *
          0.83;
      node.position = Offset(
        (node.position.dx + node.velocity.dx).clamp(60, 1540),
        (node.position.dy + node.velocity.dy).clamp(60, 1040),
      );
    }
    setState(() {});
  }

  void _arrangeBySemester() {
    _ticker.stop();
    final groups = <int, List<_GraphNode>>{};
    for (final node in _nodes.values) {
      groups.putIfAbsent(node.course.semester, () => []).add(node);
    }
    final semesters = groups.keys.toList()..sort();
    for (var column = 0; column < semesters.length; column++) {
      final group = groups[semesters[column]]!
        ..sort((a, b) => a.course.code.compareTo(b.course.code));
      for (var row = 0; row < group.length; row++) {
        group[row].position = Offset(
          90 + column * (1420 / max(1, semesters.length - 1)),
          110 + row * (860 / max(1, group.length - 1)),
        );
      }
    }
    setState(() => _semesterLayout = true);
  }

  void _reset() {
    _transform.value = Matrix4.identity();
    _initialFit = false;
    _semesterLayout = false;
    _localGraph = false;
    _semesterFilter = null;
    _statusFilter = 'all';
    _gpaFilter = null;
    _prerequisiteFilter = null;
    _hideIsolated = false;
    _loadGraph();
    _fit();
  }

  void _fit() {
    if (_viewport.isEmpty) return;
    final scale = min(
      _viewport.width / _canvasSize.width,
      _viewport.height / _canvasSize.height,
    ).clamp(0.35, 1.3);
    _transform.value = Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(0, 3, (_viewport.width - _canvasSize.width * scale) / 2)
      ..setEntry(1, 3, (_viewport.height - _canvasSize.height * scale) / 2);
  }

  void _centerOn(_GraphNode node) {
    if (_viewport.isEmpty) return;
    final scale = max(0.85, _transform.value.getMaxScaleOnAxis());
    _transform.value = Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(0, 3, _viewport.width / 2 - node.position.dx * scale)
      ..setEntry(1, 3, _viewport.height / 2 - node.position.dy * scale);
  }

  Set<String> _visibleIds(TranscriptProvider transcript) {
    final visible = _nodes.keys.toSet();
    final neighborMap = <String, Set<String>>{};
    for (final edge in _edges) {
      neighborMap.putIfAbsent(edge.from, () => {}).add(edge.to);
      neighborMap.putIfAbsent(edge.to, () => {}).add(edge.from);
    }
    if (_localGraph && _selected != null && _nodes.containsKey(_selected)) {
      final reached = <String>{_selected!};
      var frontier = <String>{_selected!};
      for (var i = 0; i < _depth; i++) {
        frontier = {for (final id in frontier) ...?neighborMap[id]};
        reached.addAll(frontier);
      }
      visible.retainAll(reached);
    }
    visible.removeWhere((id) {
      final course = _nodes[id]!.course;
      final entries = transcript.entries
          .where((e) => e.courseCode == id)
          .toList();
      final status = entries.isEmpty
          ? 'not_started'
          : entries.last.inProgress
          ? 'in_progress'
          : entries.last.isPassed
          ? 'passed'
          : 'failed';
      return (_semesterFilter != null && course.semester != _semesterFilter) ||
          (_gpaFilter != null && course.countsInGpa != _gpaFilter) ||
          (_prerequisiteFilter != null &&
              (neighborMap[id]?.isNotEmpty == true) != _prerequisiteFilter) ||
          (_hideIsolated && neighborMap[id]?.isNotEmpty != true) ||
          (_statusFilter != 'all' && status != _statusFilter);
    });
    return visible;
  }

  _GraphNode? _hit(Offset point, Set<String> visible) {
    final currentScale = max(0.1, _transform.value.getMaxScaleOnAxis());
    // 48dp diameter on screen translates to 24dp radius in canvas space
    final minTouchRadiusCanvas = 24.0 / currentScale;
    for (final id in visible) {
      final node = _nodes[id]!;
      final effectiveRadius = max(node.radius * _nodeSize + 12, minTouchRadiusCanvas);
      if ((point - node.position).distance <= effectiveRadius) {
        return node;
      }
    }
    return null;
  }

  Set<String> _ancestorIds(String id) {
    final result = <String>{id};
    var frontier = <String>{id};
    while (frontier.isNotEmpty) {
      frontier = {
        for (final edge in _edges)
          if (frontier.contains(edge.to) && !result.contains(edge.from))
            edge.from,
      };
      result.addAll(frontier);
    }
    return result;
  }

  Future<void> _showCourseList(Set<String> visible) async {
    final codes = visible.toList()..sort();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final transcript = context.read<TranscriptProvider>();

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.8,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Center(
                      child: Container(
                        width: 32,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                title: Text(
                  'Danh sách môn học trong sơ đồ (${codes.length})',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                ),
                subtitle: const Text('Chế độ xem trợ năng cho sơ đồ quan hệ'),
                trailing: IconButton(
                  tooltip: 'Đóng danh sách',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(sheetContext),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: codes.isEmpty
                    ? const Center(
                        child: EmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'Không có môn phù hợp',
                          description: 'Thử đặt lại bộ lọc để xem toàn bộ sơ đồ môn học.',
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: codes.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (_, index) {
                          final course = _nodes[codes[index]]!.course;
                          final palette = SemesterPalette.of(course.semester);
                          final prerequisites = _edges
                              .where((edge) => edge.to == course.code)
                              .map((edge) => edge.from)
                              .toList();

                          final entries = transcript.entries
                              .where((e) => e.courseCode == course.code)
                              .toList();
                          Widget? statusWidget;
                          if (entries.isNotEmpty) {
                            if (entries.last.inProgress) {
                              statusWidget = StatusChip.info(label: 'Đang học');
                            } else if (entries.last.isPassed) {
                              statusWidget = StatusChip.success(label: 'Đã đạt');
                            } else {
                              statusWidget = StatusChip.error(label: 'Chưa đạt');
                            }
                          }

                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                              side: BorderSide(
                                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                                width: 1,
                              ),
                            ),
                            child: ListTile(
                              leading: IconTile(
                                icon: courseIcon(course.code),
                                color: palette.fg,
                                background: palette.bg,
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    course.code,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ?statusWidget,
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    course.nameVi.isEmpty ? course.name : course.nameVi,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Học kỳ ${course.semester} · ${course.credits} tín chỉ${prerequisites.isNotEmpty ? " · Tiên quyết: ${prerequisites.join(', ')}" : ""}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => Navigator.pop(sheetContext, course.code),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted && selected != null && _nodes.containsKey(selected)) {
      _showCourse(_nodes[selected]!);
    }
  }

  void _showCourse(_GraphNode node) {
    setState(() => _selected = node.course.code);
    widget.onNodeSelected?.call(node.course.code);
    final prerequisites = _edges
        .where((e) => e.to == node.course.code)
        .map((e) => e.from)
        .toList();
    final dependents = _edges
        .where((e) => e.from == node.course.code)
        .map((e) => e.to)
        .toList();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = SemesterPalette.of(node.course.semester);
    final transcript = context.read<TranscriptProvider>();
    final entries = transcript.entries
        .where((e) => e.courseCode == node.course.code)
        .toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // M3 Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconTile(
                    icon: courseIcon(node.course.code),
                    color: palette.fg,
                    background: palette.bg,
                    size: 44,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              node.course.code,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (entries.isNotEmpty) ...[
                              if (entries.last.inProgress)
                                StatusChip.info(label: 'Đang học')
                              else if (entries.last.isPassed)
                                StatusChip.success(
                                  label: 'Đã đạt (${entries.last.score.toStringAsFixed(1)})',
                                )
                              else
                                StatusChip.error(
                                  label: 'Chưa đạt (${entries.last.score.toStringAsFixed(1)})',
                                ),
                            ] else
                              StatusChip(
                                label: 'Học kỳ ${node.course.semester}',
                                customColor: palette.fg,
                                icon: Icons.calendar_today_rounded,
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          node.course.nameVi.isEmpty
                              ? node.course.name
                              : node.course.nameVi,
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${node.course.credits} tín chỉ · Học kỳ ${node.course.semester}${node.course.countsInGpa ? " · Tính GPA" : " · Miễn GPA"}',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // Prerequisites & Dependents
              Text(
                'Môn tiên quyết:',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                prerequisites.isEmpty
                    ? 'Không có môn tiên quyết'
                    : prerequisites.join(' · '),
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Môn mở khóa sau đó (phụ thuộc):',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dependents.isEmpty
                    ? 'Không có môn phụ thuộc'
                    : dependents.join(' · '),
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons Row with "Hỏi AI"
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: widget.onAdvisorRequested == null
                          ? null
                          : () {
                              Navigator.pop(sheetContext);
                              widget.onAdvisorRequested?.call(node.course.code);
                            },
                      icon: const Icon(Icons.smart_toy_rounded, size: 18),
                      label: const Text('Hỏi AI'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onOpenDetail == null
                          ? null
                          : () {
                              Navigator.pop(sheetContext);
                              widget.onOpenDetail?.call(node.course.code);
                            },
                      icon: const Icon(Icons.info_outline_rounded, size: 18),
                      label: const Text('Chi tiết môn'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        setState(() => _localGraph = true);
                      },
                      child: const Text('Xem liên kết'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        setState(() => _selected = node.course.code);
                        _highlightAncestors = true;
                      },
                      child: const Text('Chuỗi tiên quyết'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final transcript = context.watch<TranscriptProvider>();
    final visible = _visibleIds(transcript);
    final focus = _hovered ?? _selected;
    final related = <String>{};
    final prerequisites = <String>{};
    final dependents = <String>{};
    if (focus != null) {
      related.add(focus);
      if (_highlightAncestors || _selected != null) {
        final ancestors = _ancestorIds(focus);
        related.addAll(ancestors);
        prerequisites.addAll(ancestors.where((id) => id != focus));
      }
      for (final edge in _edges) {
        if (edge.from == focus) {
          related.add(edge.to);
          dependents.add(edge.to);
        }
        if (!_highlightAncestors && _selected == null && edge.to == focus) {
          related.add(edge.from);
          prerequisites.add(edge.from);
        }
      }
    }

    return LayoutBuilder(
      builder: (context, limits) {
        _viewport = Size(limits.maxWidth, limits.maxHeight);
        if (!_initialFit && !_viewport.isEmpty) {
          _initialFit = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _fit();
          });
        }
        return Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _transform,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(600),
                minScale: 0.3,
                maxScale: 3,
                panEnabled: _dragging == null,
                child: SizedBox.fromSize(
                  size: _canvasSize,
                  child: MouseRegion(
                    onHover: (event) {
                      final id = _hit(
                        event.localPosition,
                        visible,
                      )?.course.code;
                      if (id != _hovered) setState(() => _hovered = id);
                    },
                    onExit: (_) => setState(() => _hovered = null),
                    child: Listener(
                      onPointerDown: (event) {
                        final id = _hit(
                          event.localPosition,
                          visible,
                        )?.course.code;
                        if (id != null) {
                          setState(() => _dragging = id);
                        }
                      },
                      onPointerMove: (event) {
                        final node = _nodes[_dragging];
                        if (node != null) {
                          setState(() => node.position = event.localPosition);
                        }
                      },
                      onPointerUp: (_) {
                        if (_dragging != null) {
                          setState(() => _dragging = null);
                          if (!_semesterLayout) _startSimulation();
                        }
                      },
                      onPointerCancel: (_) => setState(() => _dragging = null),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onLongPressStart: (details) {
                          final node = _hit(details.localPosition, visible);
                          if (node != null) _showCourse(node);
                        },
                        onTapUp: (details) {
                          final node = _hit(details.localPosition, visible);
                          if (node == null) {
                            setState(() {
                              _selected = null;
                              _highlightAncestors = false;
                            });
                            widget.onNodeSelected?.call(null);
                          } else {
                            _showCourse(node);
                          }
                        },
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: _GraphPainter(
                              nodes: _nodes,
                              edges: _edges,
                              visible: visible,
                              focus: focus,
                              related: related,
                              prerequisites: prerequisites,
                              dependents: dependents,
                              transcript: transcript,
                              statusColors: _useStatusColors,
                              labels: _showLabels,
                              arrows: _showArrows,
                              semesterNodes: _showSemesterNodes,
                              edgeWidth: _edgeWidth,
                              nodeSize: _nodeSize,
                              scale: _transform.value.getMaxScaleOnAxis(),
                              search: _search,
                              textColor: colorScheme.onSurface,
                              isDark: isDark,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Top Search & Quick Control Bar
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Material(
                elevation: 2,
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Tìm mã hoặc tên môn...',
                            prefixIcon: const Icon(Icons.search_rounded, size: 20),
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                            suffixIcon: _search.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18),
                                    onPressed: () => setState(() => _search = ''),
                                  )
                                : null,
                          ),
                          onChanged: (value) {
                            setState(
                              () => _search = value.trim().toLowerCase(),
                            );
                            final matches = _nodes.values.where(
                              (node) =>
                                  node.course.code.toLowerCase().contains(
                                    _search,
                                  ) ||
                                  node.course.name.toLowerCase().contains(
                                    _search,
                                  ),
                            );
                            if (_search.isNotEmpty && matches.isNotEmpty) {
                              _centerOn(matches.first);
                            }
                          },
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'Xem danh sách môn học cho trợ năng',
                        child: IconButton(
                          tooltip: 'Xem danh sách (Trợ năng)',
                          onPressed: () => _showCourseList(visible),
                          icon: const Icon(Icons.view_list_rounded),
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'Thu phóng vừa màn hình',
                        child: IconButton(
                          tooltip: 'Vừa màn hình',
                          onPressed: _fit,
                          icon: const Icon(Icons.fit_screen_rounded),
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'Bật tắt bảng chú thích màu sắc',
                        child: IconButton(
                          tooltip: 'Chú thích màu',
                          onPressed: _toggleLegend,
                          icon: Icon(
                            Icons.palette_outlined,
                            color: _showLegend ? colorScheme.primary : null,
                          ),
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'Bộ lọc và tùy chọn hiển thị sơ đồ',
                        child: IconButton(
                          tooltip: 'Bộ lọc & Tùy chọn',
                          onPressed: () =>
                              setState(() => _controlsOpen = !_controlsOpen),
                          icon: Icon(
                            Icons.tune_rounded,
                            color: _controlsOpen ? colorScheme.primary : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Filter & Settings Panel
            if (_controlsOpen)
              Positioned(
                top: 72,
                right: 12,
                child: Material(
                  elevation: 3,
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  child: SizedBox(
                    width: min(300, limits.maxWidth - 24),
                    height: min(520, max(120, limits.maxHeight - 88)),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Bộ lọc & Bố cục',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Đóng bảng lọc',
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => setState(() => _controlsOpen = false),
                                ),
                              ],
                            ),
                            const Divider(height: 8),
                            SwitchListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Bố cục theo học kỳ'),
                              value: _semesterLayout,
                              onChanged: (value) {
                                if (value) {
                                  _arrangeBySemester();
                                } else {
                                  setState(() => _semesterLayout = false);
                                  _startSimulation();
                                }
                              },
                            ),
                            SwitchListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Xem liên kết cục bộ'),
                              value: _localGraph && _selected != null,
                              onChanged: _selected == null
                                  ? null
                                  : (value) =>
                                        setState(() => _localGraph = value),
                            ),
                            if (_localGraph)
                              Row(
                                children: [
                                  const Text('Độ sâu:'),
                                  Expanded(
                                    child: Slider(
                                      min: 1,
                                      max: 3,
                                      divisions: 2,
                                      value: _depth.toDouble(),
                                      label: '$_depth',
                                      onChanged: (value) => setState(
                                        () => _depth = value.round(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            DropdownButtonFormField<int?>(
                              initialValue: _semesterFilter,
                              decoration: const InputDecoration(
                                labelText: 'Học kỳ',
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('Tất cả học kỳ'),
                                ),
                                for (final sem
                                    in _nodes.values
                                        .map((n) => n.course.semester)
                                        .toSet()
                                        .toList()
                                      ..sort())
                                  DropdownMenuItem<int?>(
                                    value: sem,
                                    child: Text('Học kỳ $sem'),
                                  ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _semesterFilter = value),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              initialValue: _statusFilter,
                              decoration: const InputDecoration(
                                labelText: 'Trạng thái môn',
                                isDense: true,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'all',
                                  child: Text('Tất cả trạng thái'),
                                ),
                                DropdownMenuItem(
                                  value: 'passed',
                                  child: Text('Đã đạt'),
                                ),
                                DropdownMenuItem(
                                  value: 'failed',
                                  child: Text('Chưa đạt'),
                                ),
                                DropdownMenuItem(
                                  value: 'in_progress',
                                  child: Text('Đang học'),
                                ),
                                DropdownMenuItem(
                                  value: 'not_started',
                                  child: Text('Chưa học'),
                                ),
                              ],
                              onChanged: (value) => setState(
                                () => _statusFilter = value ?? 'all',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                FilterChip(
                                  label: const Text('Màu điểm'),
                                  selected: _useStatusColors,
                                  onSelected: transcript.hasTranscript
                                      ? (v) =>
                                            setState(() => _useStatusColors = v)
                                      : null,
                                ),
                                FilterChip(
                                  label: const Text('Nhãn mã'),
                                  selected: _showLabels,
                                  onSelected: (v) =>
                                      setState(() => _showLabels = v),
                                ),
                                FilterChip(
                                  label: const Text('Mũi tên'),
                                  selected: _showArrows,
                                  onSelected: (v) =>
                                      setState(() => _showArrows = v),
                                ),
                                FilterChip(
                                  label: const Text('Ẩn node cô lập'),
                                  selected: _hideIsolated,
                                  onSelected: (value) =>
                                      setState(() => _hideIsolated = value),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _reset,
                              icon: const Icon(Icons.restart_alt_rounded, size: 16),
                              label: const Text('Đặt lại mặc định'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(36),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Bottom Legend Floating Card
            Positioned(
              left: 12,
              bottom: 12,
              child: Material(
                elevation: 2,
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: _toggleLegend,
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _useStatusColors && transcript.hasTranscript
                                    ? 'Chú giải: Màu trạng thái'
                                    : 'Chú giải: Màu học kỳ',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                _showLegend
                                    ? Icons.keyboard_arrow_down_rounded
                                    : Icons.keyboard_arrow_right_rounded,
                                size: 18,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_showLegend) ...[
                        const SizedBox(height: 6),
                        if (_useStatusColors && transcript.hasTranscript) ...[
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              StatusChip.success(label: 'Đã đạt'),
                              StatusChip.error(label: 'Chưa đạt'),
                              StatusChip.info(label: 'Đang học'),
                              const StatusChip(
                                label: 'Chưa học',
                                customColor: Color(0xFF94A3B8),
                              ),
                            ],
                          ),
                        ] else ...[
                          SizedBox(
                            width: min(280, limits.maxWidth - 48),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                for (final sem
                                    in _nodes.values
                                        .map((n) => n.course.semester)
                                        .toSet()
                                        .toList()
                                      ..sort())
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: SemesterPalette.of(sem).fg,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'HK$sem',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        const Divider(height: 8),
                        Text(
                          'Chạm môn để xem chi tiết & chuỗi tiên quyết:',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            Text('Tiên quyết', style: TextStyle(fontSize: 10.5, color: colorScheme.onSurfaceVariant)),
                            const SizedBox(width: 8),
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFEA580C), shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            Text('Mở khóa', style: TextStyle(fontSize: 10.5, color: colorScheme.onSurfaceVariant)),
                          ],
                        ),
                        if (transcript.hasTranscript) ...[
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () => setState(() => _useStatusColors = !_useStatusColors),
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.sync_alt_rounded, size: 13, color: colorScheme.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    _useStatusColors ? 'Đổi sang màu học kỳ' : 'Đổi sang màu trạng thái',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter({
    required this.nodes,
    required this.edges,
    required this.visible,
    required this.focus,
    required this.related,
    required this.prerequisites,
    required this.dependents,
    required this.transcript,
    required this.statusColors,
    required this.labels,
    required this.arrows,
    required this.semesterNodes,
    required this.edgeWidth,
    required this.nodeSize,
    required this.scale,
    required this.search,
    required this.textColor,
    required this.isDark,
  });

  final Map<String, _GraphNode> nodes;
  final List<_GraphEdge> edges;
  final Set<String> visible;
  final String? focus;
  final Set<String> related;
  final Set<String> prerequisites;
  final Set<String> dependents;
  final TranscriptProvider transcript;
  final bool statusColors;
  final bool labels;
  final bool arrows;
  final bool semesterNodes;
  final double edgeWidth;
  final double nodeSize;
  final double scale;
  final String search;
  final Color textColor;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (semesterNodes) {
      final groups = <int, List<_GraphNode>>{};
      for (final id in visible) {
        final node = nodes[id]!;
        groups.putIfAbsent(node.course.semester, () => []).add(node);
      }
      for (final entry in groups.entries) {
        final group = entry.value;
        final center = Offset(
          group.map((n) => n.position.dx).reduce((a, b) => a + b) /
              group.length,
          group.map((n) => n.position.dy).reduce((a, b) => a + b) /
                  group.length -
              95,
        );
        final color = SemesterPalette.of(entry.key).fg;
        for (final node in group) {
          canvas.drawLine(
            center,
            node.position,
            Paint()
              ..color = color.withValues(alpha: 0.14)
              ..strokeWidth = 0.8,
          );
        }
        canvas.drawCircle(center, 29, Paint()..color = color);
        final title = TextPainter(
          text: TextSpan(
            text: 'HK${entry.key}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        title.paint(canvas, center - Offset(title.width / 2, title.height / 2));
      }
    }

    for (final edge in edges) {
      if (!visible.contains(edge.from) || !visible.contains(edge.to)) continue;
      final from = nodes[edge.from]!;
      final to = nodes[edge.to]!;
      final active = focus == edge.from || focus == edge.to;
      final dim = focus != null && !active;
      final color = active
          ? edge.to == focus
              ? const Color(0xFF16A34A)
              : const Color(0xFFEA580C)
          : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))
              .withValues(alpha: dim ? 0.09 : 0.48);
      canvas.drawLine(
        from.position,
        to.position,
        Paint()
          ..color = color
          ..strokeWidth = edgeWidth * (active ? 2.3 : 1),
      );
      if (arrows) {
        final delta = to.position - from.position;
        if (delta.distance < 1) continue;
        final direction = delta / delta.distance;
        final tip = to.position - direction * (to.radius * nodeSize + 2);
        final side = Offset(-direction.dy, direction.dx);
        final path = Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(
            (tip - direction * 8 + side * 4).dx,
            (tip - direction * 8 + side * 4).dy,
          )
          ..lineTo(
            (tip - direction * 8 - side * 4).dx,
            (tip - direction * 8 - side * 4).dy,
          )
          ..close();
        canvas.drawPath(path, Paint()..color = color);
      }
    }

    for (final id in visible) {
      final node = nodes[id]!;
      final radius = node.radius * nodeSize;
      final dim = focus != null && !related.contains(id);
      Color color = SemesterPalette.of(node.course.semester).fg;
      if (statusColors && transcript.hasTranscript) {
        final entries = transcript.entries
            .where((e) => e.courseCode == id)
            .toList();
        color = entries.isEmpty
            ? (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))
            : entries.last.inProgress
            ? const Color(0xFF2563EB)
            : entries.last.isPassed
            ? const Color(0xFF16A34A)
            : const Color(0xFFDC2626);
      }
      if (prerequisites.contains(id)) color = const Color(0xFF16A34A);
      if (dependents.contains(id)) color = const Color(0xFFEA580C);
      if (search.isNotEmpty &&
          (id.toLowerCase().contains(search) ||
              node.course.name.toLowerCase().contains(search))) {
        canvas.drawCircle(
          node.position,
          radius + 6,
          Paint()..color = const Color(0xFFFACC15),
        );
      }
      canvas.drawCircle(
        node.position,
        radius,
        Paint()..color = color.withValues(alpha: dim ? 0.13 : 1),
      );
      if (focus == id) {
        canvas.drawCircle(
          node.position,
          radius + 3,
          Paint()
            ..color = const Color(0xFF312E81)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }
      final isRelatedOrFocused = focus == id || related.contains(id);
      final shouldShowLabel = labels && (isRelatedOrFocused || scale >= 0.55);
      if (shouldShowLabel) {
        // Enforce font size >= 11sp on screen at default/any scale
        final effectiveFontSize = max(13.0, 11.0 / max(0.2, scale));
        final painter = TextPainter(
          text: TextSpan(
            text: id,
            style: TextStyle(
              color: textColor.withValues(alpha: dim ? 0.2 : 1),
              fontSize: effectiveFontSize,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(
          canvas,
          Offset(
            node.position.dx - painter.width / 2,
            node.position.dy + radius + 4,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) => true;
}
