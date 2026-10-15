import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/course.dart';
import '../../../state/course_catalog.dart';
import '../../../state/transcript_provider.dart';

const _canvasSize = Size(1600, 1100);
const _semesterColors = <Color>[
  Color(0xFF64748B),
  Color(0xFF2563EB),
  Color(0xFF0891B2),
  Color(0xFF0D9488),
  Color(0xFF16A34A),
  Color(0xFFCA8A04),
  Color(0xFFEA580C),
  Color(0xFFDC2626),
  Color(0xFF9333EA),
  Color(0xFF4F46E5),
];

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
  bool _showSemesterNodes = false;
  double _repulsion = 1800;
  double _spring = 0.003;
  double _linkLength = 135;
  double _centerForce = 0.00025;
  double _edgeWidth = 1.2;
  double _nodeSize = 1;
  int _depth = 1;
  bool _initialFit = false;
  bool _controlsOpen = false;
  bool _showLegend = false;
  bool _useStatusColors = false;
  Size _viewport = Size.zero;
  int _frames = 0;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_step);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadGraph();
    });
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
      for (final raw
          in course.prerequisitesNorm.isNotEmpty
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
          (node.velocity + forces[node.course.code]! + toCenter * _centerForce) *
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
    for (final id in visible) {
      final node = _nodes[id]!;
      if ((point - node.position).distance <= node.radius * _nodeSize + 12) {
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
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${node.course.code} · ${node.course.credits} tín chỉ',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 5),
              Text(
                node.course.nameVi.isEmpty
                    ? node.course.name
                    : node.course.nameVi,
              ),
              const SizedBox(height: 12),
              Text(
                'Tiên quyết: ${prerequisites.isEmpty ? "Không có" : prerequisites.join(", ")}',
              ),
              Text(
                'Môn phụ thuộc: ${dependents.isEmpty ? "Không có" : dependents.join(", ")}',
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      setState(() => _localGraph = true);
                    },
                    child: const Text('Xem liên kết'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      setState(() => _selected = node.course.code);
                      _highlightAncestors = true;
                    },
                    child: const Text('Chuỗi tiên quyết'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      widget.onAdvisorRequested?.call(node.course.code);
                    },
                    child: const Text('Tư vấn môn này'),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      widget.onOpenDetail?.call(node.course.code);
                    },
                    child: const Text('Xem chi tiết'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _highlightAncestors = false;

  @override
  Widget build(BuildContext context) {
    final transcript = context.watch<TranscriptProvider>();
    final visible = _visibleIds(transcript);
    final focus = _hovered ?? _selected;
    final related = <String>{};
    final prerequisites = <String>{};
    final dependents = <String>{};
    if (focus != null) {
      related.add(focus);
      for (final edge in _edges) {
        if (edge.from == focus) {
          related.add(edge.to);
          dependents.add(edge.to);
        }
        if (edge.to == focus) {
          related.add(edge.from);
          prerequisites.add(edge.from);
        }
      }
      if (_highlightAncestors) related.addAll(_ancestorIds(focus));
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
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Material(
                elevation: 3,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Tìm môn theo mã hoặc tên',
                            isDense: true,
                            border: OutlineInputBorder(),
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
                      IconButton(
                        tooltip: 'Vừa màn hình',
                        onPressed: _fit,
                        icon: const Icon(Icons.fit_screen),
                      ),
                      IconButton(
                        tooltip: 'Reset',
                        onPressed: _reset,
                        icon: const Icon(Icons.restart_alt),
                      ),
                      IconButton(
                        tooltip: 'Bộ lọc',
                        onPressed: () =>
                            setState(() => _controlsOpen = !_controlsOpen),
                        icon: const Icon(Icons.tune),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_controlsOpen)
              Positioned(
                top: 80,
                right: 12,
                child: Material(
                  elevation: 3,
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: min(290, limits.maxWidth - 24),
                    height: min(530, max(120, limits.maxHeight - 96)),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SwitchListTile(
                              dense: true,
                              title: const Text('Theo học kỳ'),
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
                              title: const Text('Xem liên kết'),
                              value: _localGraph && _selected != null,
                              onChanged: _selected == null
                                  ? null
                                  : (value) =>
                                        setState(() => _localGraph = value),
                            ),
                            if (_localGraph)
                              Row(
                                children: [
                                  const Text('Độ sâu'),
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
                              ),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('Tất cả'),
                                ),
                                for (final sem
                                    in _nodes.values
                                        .map((n) => n.course.semester)
                                        .toSet()
                                        .toList()
                                      ..sort())
                                  DropdownMenuItem<int?>(
                                    value: sem,
                                    child: Text('HK$sem'),
                                  ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _semesterFilter = value),
                            ),
                            DropdownButtonFormField<String>(
                              initialValue: _statusFilter,
                              decoration: const InputDecoration(
                                labelText: 'Trạng thái',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'all',
                                  child: Text('Tất cả'),
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
                            Wrap(
                              spacing: 4,
                              runSpacing: 0,
                              children: [
                                FilterChip(
                                  label: const Text('Tính GPA'),
                                  selected: _gpaFilter == true,
                                  onSelected: (value) => setState(
                                    () => _gpaFilter = value ? true : null,
                                  ),
                                ),
                                FilterChip(
                                  label: const Text('Không tính GPA'),
                                  selected: _gpaFilter == false,
                                  onSelected: (value) => setState(
                                    () => _gpaFilter = value ? false : null,
                                  ),
                                ),
                                FilterChip(
                                  label: const Text('Có tiên quyết'),
                                  selected: _prerequisiteFilter == true,
                                  onSelected: (value) => setState(
                                    () => _prerequisiteFilter = value
                                        ? true
                                        : null,
                                  ),
                                ),
                                FilterChip(
                                  label: const Text('Ẩn node cô lập'),
                                  selected: _hideIsolated,
                                  onSelected: (value) =>
                                      setState(() => _hideIsolated = value),
                                ),
                              ],
                            ),
                            Wrap(
                              spacing: 4,
                              children: [
                                FilterChip(
                                  label: const Text('Nhãn'),
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
                                  label: const Text('Node học kỳ'),
                                  selected: _showSemesterNodes,
                                  onSelected: (v) =>
                                      setState(() => _showSemesterNodes = v),
                                ),
                                FilterChip(
                                  label: const Text('Màu điểm'),
                                  selected: _useStatusColors,
                                  onSelected: transcript.hasTranscript
                                      ? (v) =>
                                            setState(() => _useStatusColors = v)
                                      : null,
                                ),
                              ],
                            ),
                            const Divider(),
                            const Text('Mô phỏng và hiển thị'),
                            _GraphControlSlider(
                              label: 'Lực đẩy',
                              value: _repulsion,
                              min: 500,
                              max: 5000,
                              onChanged: (value) {
                                setState(() => _repulsion = value);
                                if (!_semesterLayout) _startSimulation();
                              },
                            ),
                            _GraphControlSlider(
                              label: 'Lực kéo',
                              value: _spring,
                              min: 0.001,
                              max: 0.01,
                              onChanged: (value) {
                                setState(() => _spring = value);
                                if (!_semesterLayout) _startSimulation();
                              },
                            ),
                            _GraphControlSlider(
                              label: 'Độ dài nối',
                              value: _linkLength,
                              min: 80,
                              max: 260,
                              onChanged: (value) {
                                setState(() => _linkLength = value);
                                if (!_semesterLayout) _startSimulation();
                              },
                            ),
                            _GraphControlSlider(
                              label: 'Hút về tâm',
                              value: _centerForce,
                              min: 0,
                              max: 0.001,
                              onChanged: (value) {
                                setState(() => _centerForce = value);
                                if (!_semesterLayout) _startSimulation();
                              },
                            ),
                            _GraphControlSlider(
                              label: 'Độ dày cạnh',
                              value: _edgeWidth,
                              min: 0.5,
                              max: 4,
                              onChanged: (value) =>
                                  setState(() => _edgeWidth = value),
                            ),
                            _GraphControlSlider(
                              label: 'Kích thước node',
                              value: _nodeSize,
                              min: 0.65,
                              max: 1.8,
                              onChanged: (value) =>
                                  setState(() => _nodeSize = value),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 12,
              bottom: 12,
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => setState(() => _showLegend = !_showLegend),
                        child: Text(
                          'Chú giải màu ${_showLegend ? "▾" : "▸"}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (!_showLegend)
                        SizedBox(
                          width: min(270, limits.maxWidth - 48),
                          child: Wrap(
                            spacing: 8,
                            children: [
                              if (_useStatusColors && transcript.hasTranscript)
                                const Text(
                                  'Lục: đạt · Đỏ: chưa đạt · Lam: đang học · Xám: chưa học',
                                  style: TextStyle(fontSize: 10),
                                )
                              else
                                for (final sem in _nodes.values
                                  .map((n) => n.course.semester)
                                  .toSet()
                                  .toList()
                                ..sort())
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.circle,
                                        color: _semesterColors[sem.clamp(0, 9)],
                                        size: 9),
                                    Text(' HK$sem',
                                        style: const TextStyle(fontSize: 10)),
                                  ],
                                ),
                              if (focus != null) ...[
                                const Text('Lục: tiên quyết',
                                    style: TextStyle(
                                        color: Color(0xFF16A34A),
                                        fontSize: 10)),
                                const Text('Cam: phụ thuộc',
                                    style: TextStyle(
                                        color: Color(0xFFEA580C),
                                        fontSize: 10)),
                              ],
                            ],
                          ),
                        ),
                      if (_showLegend &&
                          !(_useStatusColors && transcript.hasTranscript))
                        for (final sem
                            in _nodes.values
                                .map((n) => n.course.semester)
                                .toSet()
                                .toList()
                              ..sort())
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.circle,
                                color: _semesterColors[sem.clamp(0, 9)],
                                size: 12,
                              ),
                              Text(
                                '  HK$sem',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                      if (_showLegend &&
                          _useStatusColors &&
                          transcript.hasTranscript)
                        const Text(
                          'Lục: đạt · Đỏ: chưa đạt · Lam: đang học · Xám: chưa học',
                          style: TextStyle(fontSize: 11),
                        ),
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

class _GraphControlSlider extends StatelessWidget {
  const _GraphControlSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(width: 100, child: Text(label)),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      );
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
        final color = _semesterColors[entry.key.clamp(0, 9)];
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
                color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        title.paint(canvas,
            center - Offset(title.width / 2, title.height / 2));
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
          : const Color(0xFF94A3B8).withValues(alpha: dim ? 0.09 : 0.48);
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
      Color color = _semesterColors[node.course.semester.clamp(0, 9)];
      if (statusColors && transcript.hasTranscript) {
        final entries = transcript.entries
            .where((e) => e.courseCode == id)
            .toList();
        color = entries.isEmpty
            ? const Color(0xFF94A3B8)
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
      if (labels &&
          (scale > 0.65 || radius >= 20 || related.contains(id))) {
        final painter = TextPainter(
          text: TextSpan(
            text: id,
            style: TextStyle(
              color: const Color(0xFF0F172A).withValues(alpha: dim ? 0.2 : 1),
              fontSize: 13,
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
