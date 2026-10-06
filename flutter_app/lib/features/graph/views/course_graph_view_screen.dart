import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../../models/course.dart';
import '../../../pages/course_detail_page.dart';
import '../../../state/course_catalog.dart';
import '../../../theme/app_theme.dart';
import '../logic/course_graph.dart';
import '../logic/force_simulation.dart';
import '../models/graph_models.dart';
import 'graph_painter.dart';
import 'widgets/graph_control_panel.dart';
import 'widgets/graph_node_dialog.dart';

/// Tab Map: Graph View động kiểu Obsidian (Mục 4.3).
///
/// Node/cạnh sinh từ `prerequisites` của các môn trong [CourseCatalog].
/// Trạng thái zoom/pan, bộ lọc, bố cục được giữ nguyên khi chuyển tab hoặc
/// mở Màn 3 rồi quay lại (widget nằm trong IndexedStack của Màn 2).
class CourseGraphViewScreen extends StatefulWidget {
  const CourseGraphViewScreen({
    super.key,
    this.selectedCode,
    this.onNodeSelected,
    this.onOpenDetail,
    this.onAdvisorRequested,
    this.statuses = const {},
  });

  /// Môn đang được chọn ở tab "Danh sách môn" (đồng bộ hai chiều).
  final String? selectedCode;
  final ValueChanged<String?>? onNodeSelected;
  final ValueChanged<String>? onOpenDetail;
  final ValueChanged<String>? onAdvisorRequested;

  /// Trạng thái học từng môn, do Khối E cung cấp sau khi import bảng điểm.
  final Map<String, CourseProgressStatus> statuses;

  @override
  State<CourseGraphViewScreen> createState() => _CourseGraphViewScreenState();
}

class _CourseGraphViewScreenState extends State<CourseGraphViewScreen> with TickerProviderStateMixin {
  static const double _minScale = 0.2;
  static const double _maxScale = 3.0;
  static const double _panelWidth = 320;

  // Dữ liệu đồ thị.
  List<Course>? _sourceCourses;
  CourseGraph? _graph;
  final List<GraphNode> _semesterNodes = [];
  final Map<String, GraphNode> _nodeById = {};
  List<GraphNode> _visibleNodes = [];
  List<GraphEdge> _visibleEdges = [];

  // Mô phỏng lực.
  final ForceSimulation _simulation = ForceSimulation();
  late final Ticker _ticker;
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);
  int _pendingFitFrames = 0;
  bool _userMovedCamera = false;

  // Camera: screen = world * scale + offset.
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  Size _viewport = Size.zero;
  late final AnimationController _cameraController;
  double _cameraFromScale = 1, _cameraToScale = 1;
  Offset _cameraFromOffset = Offset.zero, _cameraToOffset = Offset.zero;

  // Làm nổi bật (hover / chuỗi tiên quyết).
  late final AnimationController _highlightController;
  GraphHighlight _highlight = const GraphHighlight.none();
  String? _hoveredId;
  String? _chainRootId;
  String? _selectedId;
  MouseCursor _cursor = SystemMouseCursors.basic;

  // Tương tác kéo.
  String? _draggingId;
  double _scaleAtGestureStart = 1;

  /// Vị trí nhấn chuột/ngón tay; dùng để chọn node kéo đúng chỗ bắt đầu
  /// (focal point của scale gesture đã lệch đi một đoạn slop).
  Offset? _pointerDownPosition;

  // Tuỳ chọn người dùng.
  bool _semesterLayout = false;
  bool _showSemesterNodes = false;
  bool _panelOpen = true;
  String? _localRootId;
  int _localDepth = 1;
  GraphFilters _filters = const GraphFilters();
  GraphDisplaySettings _display = const GraphDisplaySettings();
  ForceSettings _forces = const ForceSettings();
  final TextEditingController _searchController = TextEditingController();
  Set<String> _searchMatches = {};
  String? _lastCenteredMatch;

  bool get _hasStatuses => widget.statuses.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.selectedCode;
    _ticker = createTicker(_onTick);
    _cameraController = AnimationController(vsync: this, duration: const Duration(milliseconds: 450))
      ..addListener(_onCameraAnimate);
    _highlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
    )..addStatusListener((status) {
        if (status == AnimationStatus.dismissed && !_targetHighlight().isActive) {
          _highlight = const GraphHighlight.none();
        }
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final courses = context.watch<CourseCatalog>().courses;
    if (!identical(courses, _sourceCourses) && courses.isNotEmpty) {
      _sourceCourses = courses;
      _buildGraph(courses);
    }
  }

  @override
  void didUpdateWidget(covariant CourseGraphViewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedCode != oldWidget.selectedCode && widget.selectedCode != _selectedId) {
      _selectedId = widget.selectedCode;
      final node = _selectedId == null ? null : _nodeById[_selectedId];
      if (node != null && _visibleNodes.contains(node)) _centerOn(node);
    }
    if (!identical(widget.statuses, oldWidget.statuses)) _recomputeVisibility();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _cameraController.dispose();
    _highlightController.dispose();
    _frame.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Dữ liệu & hiển thị
  // ---------------------------------------------------------------------------

  void _buildGraph(List<Course> courses) {
    final graph = CourseGraph.fromCourses(courses);
    _graph = graph;
    CourseGraph.seedPositions(graph.courseNodes);

    _semesterNodes
      ..clear()
      ..addAll({for (final n in graph.courseNodes) n.semester}.map(
        (sem) => GraphNode(id: 'HK#$sem', title: semesterLabel(sem), semester: sem, credits: 0, isSemesterNode: true),
      ));

    _nodeById
      ..clear()
      ..addEntries([...graph.courseNodes, ..._semesterNodes].map((n) => MapEntry(n.id, n)));

    _applyNodeSizes();
    _recomputeVisibility(reheat: false);
    _restartSimulation(fitAfterFrames: 70);
  }

  void _applyNodeSizes() {
    for (final node in _nodeById.values) {
      node.radius = node.isSemesterNode ? 16 * _display.nodeScale : CourseGraph.radiusFor(node.degree, _display.nodeScale);
    }
  }

  bool _passesFilters(GraphNode node) {
    final graph = _graph!;
    if (_filters.semesters.isNotEmpty && !_filters.semesters.contains(node.semester)) return false;
    if (_hasStatuses && _filters.statuses.isNotEmpty) {
      final status = widget.statuses[node.id] ?? CourseProgressStatus.notStarted;
      if (!_filters.statuses.contains(status)) return false;
    }
    if (_filters.gpa == TriFilter.yes && !node.countsInGpa) return false;
    if (_filters.gpa == TriFilter.no && node.countsInGpa) return false;
    final hasPrereq = graph.prerequisitesOf[node.id]!.isNotEmpty;
    if (_filters.prerequisite == TriFilter.yes && !hasPrereq) return false;
    if (_filters.prerequisite == TriFilter.no && hasPrereq) return false;
    if (!_filters.showIsolated && node.isIsolated) return false;
    return true;
  }

  void _recomputeVisibility({bool reheat = true}) {
    final graph = _graph;
    if (graph == null) return;

    final local = _localRootId == null ? null : graph.neighborhood(_localRootId!, _localDepth);
    final visibleCourses = graph.courseNodes
        .where((n) => n.id == _localRootId || ((local == null || local.contains(n.id)) && _passesFilters(n)))
        .toList();
    final visibleIds = {for (final n in visibleCourses) n.id};

    final edges = graph.prerequisiteEdges.where((e) => visibleIds.contains(e.from) && visibleIds.contains(e.to)).toList();
    final nodes = <GraphNode>[...visibleCourses];

    if (_showSemesterNodes) {
      for (final semNode in _semesterNodes) {
        final members = visibleCourses.where((n) => n.semester == semNode.semester).toList();
        if (members.isEmpty) continue;
        if (!_visibleNodes.contains(semNode)) {
          // Đặt node học kỳ vào giữa các môn của nó để không bị giật khi bật.
          semNode.position = members.fold<Offset>(Offset.zero, (sum, n) => sum + n.position) / members.length.toDouble();
          semNode.velocity = Offset.zero;
        }
        nodes.add(semNode);
        edges.addAll(members.map((m) => GraphEdge(semNode.id, m.id, kind: GraphEdgeKind.semesterMembership)));
      }
    }

    _visibleNodes = nodes;
    _visibleEdges = edges;
    _searchMatches = _computeSearchMatches(_searchController.text);
    if (_hoveredId != null && !visibleIds.contains(_hoveredId)) _hoveredId = null;
    if (_chainRootId != null && !visibleIds.contains(_chainRootId)) _chainRootId = null;
    _syncHighlight();

    if (reheat) {
      _simulation.reheat(0.7);
      _startTicker();
    }
    _frame.value++;
  }

  void _restartSimulation({int fitAfterFrames = 0}) {
    _simulation.alpha = 1.0;
    // Chạy trước vài bước cho bố cục đỡ rối, phần còn lại diễn ra có animation.
    for (var i = 0; i < 60; i++) {
      _stepSimulation();
    }
    _pendingFitFrames = fitAfterFrames;
    _userMovedCamera = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitToScreen(animate: false);
    });
    _startTicker();
  }

  void _stepSimulation() {
    final semesters = _visibleNodes.map((n) => n.semester);
    _simulation.step(
      nodes: _visibleNodes,
      edges: _visibleEdges,
      nodeById: _nodeById,
      settings: _forces,
      semesterLayout: _semesterLayout,
      minSemester: semesters.isEmpty ? 0 : semesters.reduce(min),
      maxSemester: semesters.isEmpty ? 0 : semesters.reduce(max),
    );
  }

  void _startTicker() {
    if (!_ticker.isActive) _ticker.start();
  }

  void _onTick(Duration _) {
    if (_simulation.isActive) {
      _stepSimulation();
      _frame.value++;
    }
    if (_pendingFitFrames > 0 && --_pendingFitFrames == 0 && !_userMovedCamera) {
      _fitToScreen();
    }
    if (!_simulation.isActive && _pendingFitFrames == 0) _ticker.stop();
  }

  // ---------------------------------------------------------------------------
  // Camera
  // ---------------------------------------------------------------------------

  Offset _toWorld(Offset screen) => (screen - _offset) / _scale;

  void _zoomAt(Offset focal, double factor) {
    final newScale = (_scale * factor).clamp(_minScale, _maxScale);
    final world = _toWorld(focal);
    _scale = newScale;
    _offset = focal - world * _scale;
    _frame.value++;
  }

  void _animateCamera(double scale, Offset offset) {
    _cameraFromScale = _scale;
    _cameraFromOffset = _offset;
    _cameraToScale = scale;
    _cameraToOffset = offset;
    _cameraController.forward(from: 0);
  }

  void _onCameraAnimate() {
    final t = Curves.easeInOutCubic.transform(_cameraController.value);
    _scale = _cameraFromScale + (_cameraToScale - _cameraFromScale) * t;
    _offset = Offset.lerp(_cameraFromOffset, _cameraToOffset, t)!;
    _frame.value++;
  }

  /// Vùng nhìn thấy thực tế (trừ bảng điều khiển khi đang mở trên màn rộng).
  Rect get _usableViewport {
    final reserveRight = _panelOpen && _viewport.width > 760 ? _panelWidth + 24 : 0.0;
    return Rect.fromLTWH(0, 56, max(_viewport.width - reserveRight, 200), max(_viewport.height - 56 - 110, 200));
  }

  void _fitToScreen({bool animate = true}) {
    if (_visibleNodes.isEmpty || _viewport.isEmpty) return;
    var bounds = Rect.fromCircle(center: _visibleNodes.first.position, radius: _visibleNodes.first.radius);
    for (final node in _visibleNodes) {
      bounds = bounds.expandToInclude(Rect.fromCircle(center: node.position, radius: node.radius + 26));
    }
    final area = _usableViewport.deflate(24);
    final scale = min(area.width / max(bounds.width, 1), area.height / max(bounds.height, 1)).clamp(_minScale, 1.6);
    final offset = area.center - bounds.center * scale;
    animate ? _animateCamera(scale, offset) : _setCamera(scale, offset);
  }

  void _setCamera(double scale, Offset offset) {
    _scale = scale;
    _offset = offset;
    _frame.value++;
  }

  void _centerOn(GraphNode node) {
    final scale = max(_scale, 0.9).clamp(_minScale, _maxScale);
    _animateCamera(scale, _usableViewport.center - node.position * scale);
  }

  // ---------------------------------------------------------------------------
  // Làm nổi bật
  // ---------------------------------------------------------------------------

  GraphHighlight _targetHighlight() {
    final graph = _graph;
    if (graph == null) return const GraphHighlight.none();
    final focus = _hoveredId ?? _draggingId;
    if (focus != null && _nodeById[focus]?.isSemesterNode == false) {
      return GraphHighlight.focus(
        focus,
        prerequisites: graph.prerequisitesOf[focus] ?? const {},
        dependents: graph.dependentsOf[focus] ?? const {},
      );
    }
    if (_chainRootId != null) {
      return GraphHighlight.chain(_chainRootId!, {_chainRootId!, ...graph.ancestorsOf(_chainRootId!)});
    }
    return const GraphHighlight.none();
  }

  void _syncHighlight() {
    final target = _targetHighlight();
    if (target.isActive) {
      _highlight = target;
      _highlightController.forward();
    } else {
      _highlightController.reverse();
    }
  }

  void _setHovered(String? id) {
    if (_hoveredId == id) return;
    _hoveredId = id;
    _syncHighlight();
  }

  // ---------------------------------------------------------------------------
  // Tương tác
  // ---------------------------------------------------------------------------

  GraphNode? _hitTest(Offset screen) {
    final world = _toWorld(screen);
    // Vùng bấm tối thiểu ~14px trên màn hình để dễ trúng khi thu nhỏ (Mục 8.4).
    final tolerance = 14 / _scale;
    GraphNode? best;
    var bestDistance = double.infinity;
    for (final node in _visibleNodes.reversed) {
      final distance = (node.position - world).distance;
      if (distance <= max(node.radius + 4, tolerance) && distance < bestDistance) {
        best = node;
        bestDistance = distance;
      }
    }
    return best;
  }

  void _setCursor(MouseCursor cursor) {
    if (_cursor != cursor) setState(() => _cursor = cursor);
  }

  void _onHover(PointerHoverEvent event) {
    final hit = _hitTest(event.localPosition);
    _setHovered(hit?.id);
    _setCursor(hit == null ? SystemMouseCursors.basic : SystemMouseCursors.click);
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      _cameraController.stop();
      _userMovedCamera = true;
      _zoomAt(event.localPosition, exp(-event.scrollDelta.dy / 500));
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    _cameraController.stop();
    _userMovedCamera = true;
    final hit = details.pointerCount == 1 ? _hitTest(_pointerDownPosition ?? details.localFocalPoint) : null;
    if (hit != null) {
      _draggingId = hit.id;
      hit.pinnedAt = hit.position;
      _simulation
        ..alphaTarget = 0.3
        ..reheat(0.3);
      _startTicker();
      _setCursor(SystemMouseCursors.grabbing);
      _syncHighlight();
    } else {
      _scaleAtGestureStart = _scale;
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final dragged = _draggingId == null ? null : _nodeById[_draggingId];
    if (dragged != null) {
      final world = _toWorld(details.localFocalPoint);
      dragged
        ..pinnedAt = world
        ..position = world;
      _frame.value++;
      return;
    }
    _offset += details.focalPointDelta;
    if (details.scale != 1.0) {
      _zoomAt(details.localFocalPoint, _scaleAtGestureStart * details.scale / _scale);
    } else {
      _frame.value++;
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    final dragged = _draggingId == null ? null : _nodeById[_draggingId];
    if (dragged == null) return;
    dragged.pinnedAt = null;
    _draggingId = null;
    _simulation.alphaTarget = 0;
    _startTicker();
    _setCursor(SystemMouseCursors.click);
    _syncHighlight();
  }

  void _onTapUp(TapUpDetails details) {
    final hit = _hitTest(details.localPosition);
    if (hit == null) {
      // Bấm nền: bỏ làm nổi bật cố định (chuỗi tiên quyết / chạm giữ trên mobile).
      if (_chainRootId != null || _hoveredId != null) {
        _chainRootId = null;
        _setHovered(null);
        setState(() {});
      }
      return;
    }
    if (hit.isSemesterNode) return;
    _selectNode(hit.id);
    _openNodeDialog(hit);
  }

  /// Chạm giữ trên màn cảm ứng tương đương hover trên desktop (Mục 4.3.d).
  void _onLongPressStart(LongPressStartDetails details) {
    _setHovered(_hitTest(details.localPosition)?.id);
  }

  void _selectNode(String? id) {
    if (_selectedId == id) return;
    setState(() => _selectedId = id);
    widget.onNodeSelected?.call(id);
  }

  Future<void> _openNodeDialog(GraphNode node) async {
    final graph = _graph!;
    final action = await GraphNodeDialog.show(
      context,
      node: node,
      prerequisites: (graph.prerequisitesOf[node.id] ?? const <String>{}).toList()..sort(),
      dependents: (graph.dependentsOf[node.id] ?? const <String>{}).toList()..sort(),
      status: widget.statuses[node.id],
    );
    if (!mounted || action == null) return;

    switch (action) {
      case GraphNodeAction.openDetail:
        if (widget.onOpenDetail != null) {
          widget.onOpenDetail!(node.id);
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (_) => CourseDetailPage(code: node.id)));
        }
      case GraphNodeAction.showLinks:
        _enterLocalGraph(node.id);
      case GraphNodeAction.showPrerequisiteChain:
        setState(() => _chainRootId = node.id);
        _syncHighlight();
      case GraphNodeAction.advise:
        if (widget.onAdvisorRequested != null) {
          widget.onAdvisorRequested!(node.id);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Chưa kết nối được chức năng tư vấn cho môn ${node.id}.')),
          );
        }
    }
  }

  void _enterLocalGraph(String id) {
    setState(() => _localRootId = id);
    _recomputeVisibility();
    _pendingFitFrames = 45;
    _userMovedCamera = false;
    _startTicker();
  }

  void _exitLocalGraph() {
    setState(() => _localRootId = null);
    _recomputeVisibility();
    _pendingFitFrames = 45;
    _userMovedCamera = false;
    _startTicker();
  }

  void _toggleSemesterLayout() {
    setState(() => _semesterLayout = !_semesterLayout);
    _simulation.reheat(1.0);
    _pendingFitFrames = 70;
    _userMovedCamera = false;
    _startTicker();
  }

  void _reset() {
    setState(() {
      _semesterLayout = false;
      _showSemesterNodes = false;
      _localRootId = null;
      _localDepth = 1;
      _chainRootId = null;
      _hoveredId = null;
      _filters = const GraphFilters();
      _display = const GraphDisplaySettings();
      _forces = const ForceSettings();
      _searchController.clear();
      _lastCenteredMatch = null;
    });
    _selectNode(null);
    final graph = _graph;
    if (graph == null) return;
    CourseGraph.seedPositions(graph.courseNodes);
    _applyNodeSizes();
    _recomputeVisibility(reheat: false);
    _restartSimulation(fitAfterFrames: 70);
  }

  // ---------------------------------------------------------------------------
  // Tìm kiếm
  // ---------------------------------------------------------------------------

  Set<String> _computeSearchMatches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return {};
    return {
      for (final node in _visibleNodes)
        if (!node.isSemesterNode && (node.id.toLowerCase().contains(q) || node.title.toLowerCase().contains(q))) node.id,
    };
  }

  GraphNode? _bestSearchMatch(String query) {
    final q = query.trim().toLowerCase();
    if (_searchMatches.isEmpty) return null;
    final ids = _searchMatches.toList()
      ..sort((a, b) {
        final aPrefix = a.toLowerCase().startsWith(q) ? 0 : 1;
        final bPrefix = b.toLowerCase().startsWith(q) ? 0 : 1;
        return aPrefix != bPrefix ? aPrefix - bPrefix : a.compareTo(b);
      });
    return _nodeById[ids.first];
  }

  void _onSearchChanged(String query) {
    setState(() => _searchMatches = _computeSearchMatches(query));
    _frame.value++;
    // Khớp thì tự căn giữa vào node phù hợp nhất (Mục 4.3.f).
    final best = _bestSearchMatch(query);
    if (best != null && best.id != _lastCenteredMatch) {
      _lastCenteredMatch = best.id;
      _centerOn(best);
    }
    if (best == null) _lastCenteredMatch = null;
  }

  void _onSearchSubmitted(String query) {
    final best = _bestSearchMatch(query);
    if (best == null) return;
    _selectNode(best.id);
    _centerOn(best);
  }

  // ---------------------------------------------------------------------------
  // Giao diện
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CourseCatalog>();
    if (_graph == null) {
      if (catalog.error != null) {
        return Center(child: Text(catalog.error!, style: const TextStyle(fontSize: 15)));
      }
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        if (_viewport != viewport) {
          final firstLayout = _viewport.isEmpty;
          _viewport = viewport;
          // Màn hẹp: thu gọn bảng điều khiển để không che đồ thị.
          if (firstLayout && viewport.width < 900) _panelOpen = false;
          // Vùng Map đổi kích thước (đóng/mở khung chat, đổi cửa sổ): căn lại nếu người dùng chưa tự zoom/kéo.
          if (firstLayout || !_userMovedCamera) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _fitToScreen(animate: !firstLayout);
            });
          }
        }
        final compact = viewport.width < 760;

        // ClipRect: CustomPainter vẽ theo toạ độ world nên phải cắt để không tràn ra breadcrumb/tab.
        return ClipRect(
          child: ColoredBox(
            color: const Color(0xFFFBFCFE),
            child: Stack(
              children: [
                Positioned.fill(child: _buildCanvas()),
                Positioned(top: 12, left: 12, right: _panelOpen && !compact ? _panelWidth + 24 : 12, child: _buildToolbar()),
                if (_localRootId != null || _chainRootId != null)
                  Positioned(top: 64, left: 12, child: _buildModeBanner()),
                Positioned(left: 12, bottom: 12, child: _buildLegend()),
                if (_panelOpen)
                  Positioned(
                    top: 12,
                    right: 12,
                    bottom: 12,
                    child: Align(alignment: Alignment.topRight, child: _buildPanel()),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCanvas() {
    return Listener(
      onPointerSignal: _onPointerSignal,
      onPointerDown: (event) => _pointerDownPosition = event.localPosition,
      child: MouseRegion(
        cursor: _cursor,
        onHover: _onHover,
        onExit: (_) {
          if (_draggingId == null) _setHovered(null);
          _setCursor(SystemMouseCursors.basic);
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: _onTapUp,
          onLongPressStart: _onLongPressStart,
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onScaleEnd: _onScaleEnd,
          child: CustomPaint(
            size: Size.infinite,
            painter: GraphPainter(
              repaint: Listenable.merge([_frame, _highlightController]),
              nodes: _visibleNodes,
              edges: _visibleEdges,
              nodeById: _nodeById,
              cameraScale: () => _scale,
              cameraOffset: () => _offset,
              highlight: () => _highlight,
              highlightProgress: () => _highlightController.value,
              selectedId: _selectedId,
              searchMatches: _searchMatches,
              display: _display,
              statuses: widget.statuses,
              semesterColumns: _semesterColumns(),
            ),
          ),
        ),
      ),
    );
  }

  Map<int, double> _semesterColumns() {
    if (!_semesterLayout || _visibleNodes.isEmpty) return const {};
    final semesters = _visibleNodes.map((n) => n.semester).toSet();
    final lo = semesters.reduce(min), hi = semesters.reduce(max);
    return {for (final sem in semesters) sem: ForceSimulation.semesterColumnX(sem, lo, hi)};
  }

  Widget _buildToolbar() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ToolbarButton(
          icon: _semesterLayout ? Icons.scatter_plot_outlined : Icons.view_column_outlined,
          label: _semesterLayout ? 'Bố cục tự do' : 'Sắp xếp theo học kỳ',
          active: _semesterLayout,
          onPressed: _toggleSemesterLayout,
        ),
        _ToolbarButton(icon: Icons.fit_screen_outlined, label: 'Vừa màn hình', onPressed: _fitToScreen),
        _ToolbarButton(icon: Icons.restart_alt, label: 'Reset', onPressed: _reset),
        _ToolbarButton(
          icon: Icons.zoom_in,
          tooltip: 'Phóng to',
          onPressed: () => _animateCamera(
            (_scale * 1.25).clamp(_minScale, _maxScale),
            _viewport.center(Offset.zero) - (_toWorld(_viewport.center(Offset.zero)) * (_scale * 1.25).clamp(_minScale, _maxScale)),
          ),
        ),
        _ToolbarButton(
          icon: Icons.zoom_out,
          tooltip: 'Thu nhỏ',
          onPressed: () => _animateCamera(
            (_scale / 1.25).clamp(_minScale, _maxScale),
            _viewport.center(Offset.zero) - (_toWorld(_viewport.center(Offset.zero)) * (_scale / 1.25).clamp(_minScale, _maxScale)),
          ),
        ),
        if (!_panelOpen)
          _ToolbarButton(
            icon: Icons.tune,
            label: 'Bảng điều khiển',
            onPressed: () => setState(() => _panelOpen = true),
          ),
      ],
    );
  }

  Widget _buildModeBanner() {
    final isLocal = _localRootId != null;
    return Material(
      color: const Color(0xFFF5F3FF),
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isLocal)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.hub_outlined, size: 18, color: kSelectionColor),
                  const SizedBox(width: 8),
                  Text('Liên kết của $_localRootId', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 12),
                  Text('Độ sâu $_localDepth', style: const TextStyle(fontSize: 13.5, color: AppTheme.slate700)),
                  SizedBox(
                    width: 140,
                    child: Slider(
                      value: _localDepth.toDouble(),
                      min: 1,
                      max: 3,
                      divisions: 2,
                      label: '$_localDepth cấp',
                      onChanged: (v) {
                        if (v.round() == _localDepth) return;
                        setState(() => _localDepth = v.round());
                        _recomputeVisibility();
                        _pendingFitFrames = 45;
                        _userMovedCamera = false;
                      },
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _exitLocalGraph,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Xem toàn bộ'),
                  ),
                ],
              ),
            if (_chainRootId != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_tree_outlined, size: 18, color: kPrerequisiteColor),
                  const SizedBox(width: 8),
                  Text(
                    'Chuỗi tiên quyết của $_chainRootId',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _chainRootId = null);
                      _syncHighlight();
                    },
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Tắt'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    final semesters = {for (final n in _graph!.courseNodes) n.semester}.toList()..sort();
    final byStatus = _display.colorByStatus && _hasStatuses;

    return Material(
      color: Colors.white.withValues(alpha: 0.96),
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: min(430, _viewport.width - 24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                byStatus ? 'Màu theo trạng thái học' : 'Màu theo học kỳ',
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.slate900),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: byStatus
                    ? [for (final s in CourseProgressStatus.values) _LegendDot(color: s.color, label: s.label)]
                    : [for (final sem in semesters) _LegendDot(color: semesterColor(sem), label: semesterLabel(sem))],
              ),
              const SizedBox(height: 8),
              const Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _LegendLine(color: kPrerequisiteColor, label: 'Môn tiên quyết (phía trước)'),
                  _LegendLine(color: kDependentColor, label: 'Môn phụ thuộc (phía sau)'),
                  _LegendText('Node lớn = nhiều liên kết'),
                  _LegendText('◉ chấm trắng = không tính GPA'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPanel() {
    final semesters = {for (final n in _graph!.courseNodes) n.semester}.toList()..sort();
    return ConstrainedBox(
      // Chừa góc dưới cho nút chat nổi của Màn 2.
      constraints: BoxConstraints(maxHeight: max(_viewport.height - 96, 200)),
      child: GraphControlPanel(
        searchController: _searchController,
        onSearchChanged: _onSearchChanged,
        onSearchSubmitted: _onSearchSubmitted,
        searchMatchCount: _searchMatches.length,
        semesters: semesters,
        filters: _filters,
        onFiltersChanged: (filters) {
          setState(() => _filters = filters);
          _recomputeVisibility();
        },
        hasStatuses: _hasStatuses,
        display: _display,
        onDisplayChanged: (display) {
          final sizeChanged = display.nodeScale != _display.nodeScale;
          setState(() => _display = display);
          if (sizeChanged) {
            _applyNodeSizes();
            _simulation.reheat(0.3);
            _startTicker();
          }
          _frame.value++;
        },
        showSemesterNodes: _showSemesterNodes,
        onShowSemesterNodesChanged: (value) {
          setState(() => _showSemesterNodes = value);
          _recomputeVisibility();
        },
        forces: _forces,
        onForcesChanged: (forces) {
          setState(() => _forces = forces);
          _simulation.reheat(0.5);
          _startTicker();
        },
        onClose: () => setState(() => _panelOpen = false),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({required this.icon, required this.onPressed, this.label, this.tooltip, this.active = false});

  final IconData icon;
  final String? label;
  final String? tooltip;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(
      backgroundColor: active ? AppTheme.primaryLight : Colors.white,
      foregroundColor: active ? AppTheme.primaryBlue : AppTheme.slate800,
      side: BorderSide(color: active ? AppTheme.primaryBlue : AppTheme.slate200, width: active ? 1.6 : 1.2),
      padding: EdgeInsets.symmetric(horizontal: label == null ? 10 : 14, vertical: 14),
      minimumSize: const Size(44, 44),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
    ).copyWith(
      overlayColor: WidgetStatePropertyAll(AppTheme.primaryBlue.withValues(alpha: 0.08)),
      elevation: const WidgetStatePropertyAll(1),
    );

    final button = label == null
        ? OutlinedButton(style: style, onPressed: onPressed, child: Icon(icon, size: 20))
        : OutlinedButton.icon(style: style, onPressed: onPressed, icon: Icon(icon, size: 20), label: Text(label!));
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.slate700)),
      ],
    );
  }
}

class _LegendLine extends StatelessWidget {
  const _LegendLine({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 18, height: 3.5, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.slate700)),
      ],
    );
  }
}

class _LegendText extends StatelessWidget {
  const _LegendText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 13, color: AppTheme.slate600));
  }
}


