import 'dart:math';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../../models/course.dart';
import '../../../pages/course_detail_page.dart';
import '../../../state/course_catalog.dart';
import '../data/vault_graph_data.dart';
import '../logic/course_graph.dart';
import '../models/graph_models.dart';
import 'graph_painter.dart' show GraphDisplaySettings;
import 'widgets/graph_control_panel.dart';
import 'widgets/graph_node_dialog.dart';

// Kích thước canvas đồ thị chuẩn Obsidian không gian 2D rộng rãi
const double kCanvasWidth = 1900.0;
const double kCanvasHeight = 1500.0;
const Offset kCanvasCenter = Offset(950.0, 750.0);
const double kGraphMaxRadius = 560.0;

// Tọa độ vị trí chuẩn xác 100% trích xuất từ đồ thị mẫu Obsidian
const Map<String, Offset> kObsidianGraphCoords = {
  "#HK0": Offset(0.68, -0.18),
  "#HK1": Offset(0.68, 0.74),
  "#HK2": Offset(0.35, 0.77),
  "#HK3": Offset(-0.78, -0.38),
  "#HK4": Offset(-0.39, -0.29),
  "#HK5": Offset(-0.88, -0.22),
  "#HK6": Offset(0.64, -0.54),
  "#HK7": Offset(0.24, -0.58),
  "#HK8": Offset(0.00, 0.86),
  "#HK9": Offset(-0.24, 0.23),
  "BIT_SE_K19B": Offset(-0.16, 0.08),
  "CEA201": Offset(0.48, 0.26),
  "CSD201": Offset(-0.10, -0.28),
  "CSI106": Offset(0.16, 0.59),
  "Curriculum_Overview": Offset(0.00, -0.04),
  "DBI202": Offset(-0.56, -0.16),
  "ENW493c": Offset(0.26, -0.28),
  "EXE101": Offset(0.42, -0.11),
  "EXE201": Offset(0.45, 0.44),
  "HCM202": Offset(-0.44, 0.60),
  "IOT102": Offset(-0.38, 0.18),
  "ITE302c": Offset(0.22, 0.40),
  "JPD113": Offset(-0.18, -0.42),
  "JPD123": Offset(0.00, -0.40),
  "JPD133": Offset(0.16, -0.75),
  "LAB211": Offset(-0.70, -0.08),
  "MAC101": Offset(0.76, 0.10),
  "MAD101": Offset(0.36, 0.17),
  "MAE101": Offset(0.58, 0.36),
  "MAS291": Offset(0.48, 0.08),
  "MLN111": Offset(-0.20, 0.78),
  "MLN122": Offset(-0.36, 0.72),
  "MLN131": Offset(-0.02, 0.62),
  "NWC204": Offset(0.10, 0.46),
  "OJT202": Offset(0.38, -0.37),
  "OSG202": Offset(0.06, 0.33),
  "OTP101": Offset(0.28, -0.14),
  "PMG201c": Offset(0.45, -0.25),
  "PRF192": Offset(-0.20, 0.37),
  "PRJ301": Offset(-0.78, 0.08),
  "PRM393": Offset(-0.08, 0.30),
  "PRN212": Offset(-0.68, 0.22),
  "PRN222": Offset(-0.42, 0.02),
  "PRN232": Offset(-0.38, 0.46),
  "PRO192": Offset(-0.28, -0.04),
  "PRU213": Offset(0.12, -0.26),
  "Program_Learning_Outcomes": Offset(0.14, 0.10),
  "SEP490": Offset(0.14, -0.47),
  "SSG104": Offset(0.22, 0.22),
  "SSL101c": Offset(0.32, 0.49),
  "SWD392": Offset(-0.10, -0.56),
  "SWE102": Offset(-0.20, -0.74),
  "SWE201c": Offset(-0.52, -0.58),
  "SWE202c": Offset(-0.42, -0.76),
  "SWP391": Offset(-0.66, -0.32),
  "SWR302": Offset(-0.36, -0.46),
  "SWT301": Offset(-0.49, -0.39),
  "TMI101": Offset(0.33, 0.31),
  "TRS601": Offset(0.32, 0.02),
  "VNR202": Offset(-0.60, 0.52),
  "VOV114": Offset(0.28, 0.64),
  "VOV124": Offset(-0.14, 0.56),
  "VOV134": Offset(-0.50, 0.35),
  "WDU203c": Offset(-0.54, 0.14),
  "WED201c": Offset(-0.38, -0.15),
};

class GraphNodeData {
  GraphNodeData({
    required this.id,
    required this.label,
    required this.title,
    required this.semester,
    required this.credits,
    required this.color,
    required this.normPos,
    required this.radius,
    this.isHub = false,
    this.isTag = false,
  });

  final String id;
  final String label;
  final String title;
  final int semester;
  final int credits;
  final Color color;
  final Offset normPos;
  final double radius;
  final bool isHub;
  final bool isTag;

  Offset getActualPos(Offset center, double maxRadius) {
    return Offset(center.dx + normPos.dx * maxRadius, center.dy + normPos.dy * maxRadius);
  }
}

/// Tab Map: Obsidian Graph kèm đầy đủ bộ lọc & lộ trình.
///
/// Bố cục gốc lấy từ đồ thị Obsidian của vault; người dùng có thể kéo thả node,
/// lọc theo học kỳ/trạng thái/GPA/tiên quyết, xem liên kết local, chuỗi tiên quyết
/// và sắp xếp lại theo học kỳ.
class GraphViewScreen extends StatefulWidget {
  final String? selectedCode;
  final ValueChanged<String?>? onNodeSelected;
  final ValueChanged<String>? onOpenDetail;
  final ValueChanged<String>? onAdvisorRequested;
  final Map<String, CourseProgressStatus> statuses;

  const GraphViewScreen({
    super.key,
    this.selectedCode,
    this.onNodeSelected,
    this.onOpenDetail,
    this.onAdvisorRequested,
    this.statuses = const {},
  });

  @override
  State<GraphViewScreen> createState() => _GraphViewScreenState();
}

class _GraphViewScreenState extends State<GraphViewScreen> with TickerProviderStateMixin {
  static const double _minScale = 0.3;
  static const double _maxScale = 2.8;
  static const double _panelWidth = 320;

  /// Tỉ lệ dịch chuyển của các node liên kết khi kéo một node (cảm giác "đàn hồi" kiểu Obsidian).
  static const double _neighborFollow = 0.35;

  late final AnimationController _hoverAnimController;
  late final Animation<double> _hoverAnimation;
  late final AnimationController _cameraController;
  late final AnimationController _layoutController;
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);
  final ValueNotifier<MouseCursor> _cursor = ValueNotifier<MouseCursor>(SystemMouseCursors.basic);

  /// Ticker chuyển động: node trôi mượt về vị trí đích, zoom con lăn êm, quán tính khi thả nền.
  late final Ticker _motionTicker;
  Duration _lastTick = Duration.zero;
  final Map<String, Offset> _targets = {};
  double? _zoomTargetScale;
  Offset _zoomFocal = Offset.zero;
  Offset _panVelocity = Offset.zero;

  /// Cache nhãn chữ đã layout để không phải dựng lại mỗi khung hình.
  final Map<String, TextPainter> _labelCache = {};

  String? _hoveredNodeId;
  String? _activeFocusId; // Node đang được soi (giữ nguyên khi animation fade-out đang chạy)
  String? _selectedNodeId;
  bool _showLegend = true;

  // Dữ liệu đồ thị.
  List<Course>? _sourceCourses;
  List<GraphNodeData> _nodes = [];
  Map<String, GraphNodeData> _nodeMap = {};
  List<VaultEdge> _edges = [];
  Map<String, Set<String>> _adjacencyMap = {};
  CourseGraph? _courseGraph;
  Map<String, Course> _courseById = {};
  Map<String, String> _idByNormCode = {};
  Set<String> _visibleIds = {};

  // Vị trí node (toạ độ canvas), có thể thay đổi khi kéo thả hoặc đổi bố cục.
  final Map<String, Offset> _positions = {};
  Map<String, Offset> _layoutFrom = {};
  Map<String, Offset> _layoutTo = {};

  // Camera: screen = world * scale + offset.
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  Size _viewport = Size.zero;
  double _cameraFromScale = 1, _cameraToScale = 1;
  Offset _cameraFromOffset = Offset.zero, _cameraToOffset = Offset.zero;
  bool _userMovedCamera = false;

  // Kéo thả.
  String? _draggingId;
  double _scaleAtGestureStart = 1;
  Offset? _pointerDownPosition;

  // Tuỳ chọn người dùng.
  bool _semesterLayout = false;
  bool _showSemesterNodes = true;
  bool _panelOpen = true;
  String? _localRootId;
  int _localDepth = 1;
  String? _chainRootId;
  GraphFilters _filters = const GraphFilters();
  GraphDisplaySettings _display = const GraphDisplaySettings();
  final TextEditingController _searchController = TextEditingController();
  Set<String> _searchMatches = {};
  String? _lastCenteredMatch;

  bool get _hasStatuses => widget.statuses.isNotEmpty;

  @override
  void initState() {
    super.initState();

    // Hiệu ứng chuyển đổi mượt mà chuẩn Obsidian (fade in/out nhẹ nhàng)
    _hoverAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _hoverAnimation = CurvedAnimation(
      parent: _hoverAnimController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _hoverAnimController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && _hoveredNodeId == null && _draggingId == null) {
        _activeFocusId = null;
        _frame.value++;
      }
    });

    _cameraController = AnimationController(vsync: this, duration: const Duration(milliseconds: 450))
      ..addListener(_onCameraAnimate);
    _layoutController = AnimationController(vsync: this, duration: const Duration(milliseconds: 650))
      ..addListener(_onLayoutAnimate);
    _motionTicker = createTicker(_onMotionTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final courses = context.watch<CourseCatalog>().courses;
    if (!identical(courses, _sourceCourses)) {
      _sourceCourses = courses;
      _loadGraphData(courses);
    }
  }

  @override
  void didUpdateWidget(covariant GraphViewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedCode != oldWidget.selectedCode) {
      final id = widget.selectedCode == null ? null : _toNodeId(widget.selectedCode!);
      if (id != _selectedNodeId) {
        setState(() => _selectedNodeId = id);
        if (id != null && _visibleIds.contains(id)) _centerOn(id);
      }
    }
    if (!identical(widget.statuses, oldWidget.statuses)) _recomputeVisibility();
  }

  @override
  void dispose() {
    _hoverAnimController.dispose();
    _cameraController.dispose();
    _layoutController.dispose();
    _motionTicker.dispose();
    _frame.dispose();
    _cursor.dispose();
    _searchController.dispose();
    for (final tp in _labelCache.values) {
      tp.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Dữ liệu
  // ---------------------------------------------------------------------------

  void _loadGraphData(List<Course> courses) {
    final coursesMap = {for (var c in courses) c.code: c};

    final nodes = <GraphNodeData>[];
    final nodeMap = <String, GraphNodeData>{};

    // 1. Ba Hub trung tâm chuẩn Obsidian Vault
    final hub1 = GraphNodeData(
      id: 'Curriculum_Overview',
      label: 'Curriculum_Overview',
      title: 'Tổng quan chương trình đào tạo BIT_SE_K19B',
      semester: 0,
      credits: 145,
      color: const Color(0xFFF59E0B), // Vàng cam Obsidian Hub lớn
      normPos: kObsidianGraphCoords['Curriculum_Overview'] ?? const Offset(0.00, -0.04),
      radius: 26,
      isHub: true,
    );
    final hub2 = GraphNodeData(
      id: 'Program_Learning_Outcomes',
      label: 'Program_Learning_Outcomes',
      title: '13 Chuẩn đầu ra ngành',
      semester: 0,
      credits: 13,
      color: const Color(0xFFD97706), // Vàng hổ phách Hub
      normPos: kObsidianGraphCoords['Program_Learning_Outcomes'] ?? const Offset(0.14, 0.10),
      radius: 22,
      isHub: true,
    );
    final hub3 = GraphNodeData(
      id: 'BIT_SE_K19B',
      label: 'BIT_SE_K19B',
      title: 'Chuyên ngành Kỹ thuật Phần mềm',
      semester: 0,
      credits: 145,
      color: const Color(0xFF374151), // Xám than đậm Obsidian Hub
      normPos: kObsidianGraphCoords['BIT_SE_K19B'] ?? const Offset(-0.16, 0.08),
      radius: 20,
      isHub: true,
    );

    nodes.addAll([hub1, hub2, hub3]);
    nodeMap[hub1.id] = hub1;
    nodeMap[hub2.id] = hub2;
    nodeMap[hub3.id] = hub3;

    // 2. Các Tag học kỳ (#HK0 -> #HK9) màu xanh lá viền ngoài
    for (int sem = 0; sem <= 9; sem++) {
      final tagId = '#HK$sem';
      final pos = kObsidianGraphCoords[tagId] ?? Offset(0.8 * cos(sem * 0.6), 0.8 * sin(sem * 0.6));
      final tagNode = GraphNodeData(
        id: tagId,
        label: tagId,
        title: 'Học kỳ $sem',
        semester: sem,
        credits: 0,
        color: const Color(0xFF16A34A), // Green Obsidian Tag
        normPos: pos,
        radius: 8.5,
        isTag: true,
      );
      nodes.add(tagNode);
      nodeMap[tagId] = tagNode;
    }

    // 3. Các môn học từ flm_knowledge_vault với nhóm màu theo .obsidian/graph.json
    for (final entry in kObsidianGraphCoords.entries) {
      final id = entry.key;
      if (id.startsWith('#HK') || id.startsWith('Curriculum_') || id.startsWith('Program_') || id == 'BIT_SE_K19B') {
        continue;
      }

      final course = coursesMap[id];
      final sem = course?.semester ?? 1;

      Color color = const Color(0xFF0284C7); // Mặc định xanh dương
      double radius = 12.0;

      if (id == 'PRO192') {
        color = const Color(0xFF0D9488); // Teal PRO192
        radius = 14.0;
      } else if (id.startsWith('PRN') || id == 'SWP391' || id == 'SWR302' || id == 'SWT301' || id == 'OJT202') {
        color = const Color(0xFFF97316); // Track .NET & SWP màu Cam
        radius = 12.5;
      } else if (id == 'SWE201c' ||
          id == 'SWE202c' ||
          id == 'SWE102' ||
          id == 'LAB211' ||
          id == 'PRJ301' ||
          id == 'DBI202') {
        color = const Color(0xFF10B981); // Môn Xanh ngọc
        radius = 12.0;
      } else if (id == 'SEP490' ||
          id.startsWith('MLN') ||
          id == 'VNR202' ||
          id == 'HCM202' ||
          id == 'ITE302c' ||
          id == 'SSL101c') {
        color = const Color(0xFF8B5CF6); // Capstone, Chính trị, Kỹ năng Tím
        radius = 12.5;
      } else if (id == 'SWD392' || id == 'PRU213' || id.startsWith('EXE')) {
        color = const Color(0xFFEF4444); // Môn Đỏ
        radius = 12.5;
      } else if (id == 'MAC101' ||
          id == 'TRS601' ||
          id.startsWith('JPD') ||
          id == 'ENW493c' ||
          id == 'PMG201c' ||
          id == 'WDU203c') {
        color = const Color(0xFF6B7280); // Môn Xám
        radius = 11.5;
      }

      final node = GraphNodeData(
        id: id,
        label: id,
        title: course?.nameVi.isNotEmpty == true ? course!.nameVi : (course?.name ?? id),
        semester: sem,
        credits: course?.credits ?? 3,
        color: color,
        normPos: entry.value,
        radius: radius,
      );

      nodes.add(node);
      nodeMap[id] = node;
    }

    // 4. Nạp toàn bộ liên kết trích xuất từ flm_knowledge_vault
    final validEdges = <VaultEdge>[];
    final adjacency = <String, Set<String>>{};
    for (final e in kVaultEdges) {
      if (nodeMap.containsKey(e.from) && nodeMap.containsKey(e.to)) {
        validEdges.add(e);
        adjacency.putIfAbsent(e.from, () => <String>{}).add(e.to);
        adjacency.putIfAbsent(e.to, () => <String>{}).add(e.from);
      }
    }

    // 5. Đồ thị tiên quyết (dùng cho bộ lọc, liên kết local, chuỗi tiên quyết)
    final courseNodeIds = nodes.where((n) => !n.isHub && !n.isTag).map((n) => n.id);

    _nodes = nodes;
    _nodeMap = nodeMap;
    _edges = validEdges;
    _adjacencyMap = adjacency;
    _courseGraph = CourseGraph.fromCourses(courses);
    _courseById = {
      for (final id in courseNodeIds)
        if (coursesMap[id] != null) id: coursesMap[id]!,
    };
    _idByNormCode = {for (final id in courseNodeIds) CourseGraph.normalizeCode(id): id};
    _positions
      ..clear()
      ..addAll(_homePositions());
    _targets
      ..clear()
      ..addAll(_positions);
    _recomputeVisibility();
  }

  Map<String, Offset> _homePositions() {
    return {for (final n in _nodes) n.id: n.getActualPos(kCanvasCenter, kGraphMaxRadius)};
  }

  String? _toNodeId(String code) => _nodeMap.containsKey(code) ? code : _idByNormCode[CourseGraph.normalizeCode(code)];

  Set<String> _mapCodes(Iterable<String> codes) => {
    for (final c in codes)
      if (_idByNormCode[c] != null) _idByNormCode[c]!,
  };

  Set<String> _prerequisitesOf(String id) =>
      _mapCodes(_courseGraph?.prerequisitesOf[CourseGraph.normalizeCode(id)] ?? const <String>{});

  Set<String> _dependentsOf(String id) =>
      _mapCodes(_courseGraph?.dependentsOf[CourseGraph.normalizeCode(id)] ?? const <String>{});

  Set<String> _chainOf(String id) => {
    id,
    ..._mapCodes(_courseGraph?.ancestorsOf(CourseGraph.normalizeCode(id)) ?? const <String>{}),
  };

  CourseProgressStatus? _statusOf(String id) => widget.statuses[id] ?? widget.statuses[CourseGraph.normalizeCode(id)];

  bool _passesFilters(GraphNodeData node) {
    if (_filters.semesters.isNotEmpty && !_filters.semesters.contains(node.semester)) return false;
    if (_hasStatuses && _filters.statuses.isNotEmpty) {
      final status = _statusOf(node.id) ?? CourseProgressStatus.notStarted;
      if (!_filters.statuses.contains(status)) return false;
    }
    final countsInGpa = _courseById[node.id]?.countsInGpa ?? true;
    if (_filters.gpa == TriFilter.yes && !countsInGpa) return false;
    if (_filters.gpa == TriFilter.no && countsInGpa) return false;
    final hasPrereq = _prerequisitesOf(node.id).isNotEmpty;
    if (_filters.prerequisite == TriFilter.yes && !hasPrereq) return false;
    if (_filters.prerequisite == TriFilter.no && hasPrereq) return false;
    if (!_filters.showIsolated && !hasPrereq && _dependentsOf(node.id).isEmpty) return false;
    return true;
  }

  void _recomputeVisibility() {
    final local = _localRootId == null
        ? null
        : _mapCodes(
            _courseGraph?.neighborhood(CourseGraph.normalizeCode(_localRootId!), _localDepth) ?? const <String>{},
          );

    final visible = <String>{};
    final visibleSemesters = <int>{};
    for (final n in _nodes) {
      if (n.isHub || n.isTag) continue;
      if (n.id != _localRootId && ((local != null && !local.contains(n.id)) || !_passesFilters(n))) continue;
      visible.add(n.id);
      visibleSemesters.add(n.semester);
    }
    for (final n in _nodes) {
      if (n.isHub && local == null) visible.add(n.id);
      if (n.isTag && _showSemesterNodes) {
        final show = local == null
            ? (_filters.semesters.isEmpty || _filters.semesters.contains(n.semester))
            : visibleSemesters.contains(n.semester);
        if (show) visible.add(n.id);
      }
    }

    _visibleIds = visible;
    _searchMatches = _computeSearchMatches(_searchController.text);
    if (_hoveredNodeId != null && !visible.contains(_hoveredNodeId)) _onHoverChanged(null);
    if (_chainRootId != null && !visible.contains(_chainRootId)) _chainRootId = null;
    if (mounted) setState(() {});
    _frame.value++;
  }

  // ---------------------------------------------------------------------------
  // Bố cục
  // ---------------------------------------------------------------------------

  /// Bố cục "Sắp xếp theo học kỳ": mỗi học kỳ một cột, nhãn #HK ở đầu cột, hub ở trên cùng.
  Map<String, Offset> _semesterPositions() {
    const colGap = 170.0, rowGap = 56.0;
    final top = kCanvasCenter.dy - 380;
    final bySemester = <int, List<String>>{};
    for (final n in _nodes) {
      if (!n.isHub && !n.isTag) bySemester.putIfAbsent(n.semester, () => []).add(n.id);
    }
    final result = <String, Offset>{};
    for (final n in _nodes) {
      final x = kCanvasCenter.dx + (n.semester - 4.5) * colGap;
      if (n.isTag) result[n.id] = Offset(x, top);
    }
    for (final entry in bySemester.entries) {
      final ids = entry.value..sort();
      final x = kCanvasCenter.dx + (entry.key - 4.5) * colGap;
      for (var i = 0; i < ids.length; i++) {
        result[ids[i]] = Offset(x, top + 70 + i * rowGap);
      }
    }
    final hubs = _nodes.where((n) => n.isHub).toList();
    for (var i = 0; i < hubs.length; i++) {
      result[hubs[i].id] = Offset(kCanvasCenter.dx + (i - (hubs.length - 1) / 2) * 300, top - 150);
    }
    return result;
  }

  void _animateLayout(Map<String, Offset> targets) {
    _layoutFrom = Map.of(_positions);
    _layoutTo = targets;
    _layoutController.forward(from: 0).whenComplete(() {
      if (mounted) _fitToScreen();
    });
  }

  void _onLayoutAnimate() {
    final t = Curves.easeInOutCubic.transform(_layoutController.value);
    for (final entry in _layoutTo.entries) {
      final from = _layoutFrom[entry.key] ?? entry.value;
      final pos = Offset.lerp(from, entry.value, t)!;
      _positions[entry.key] = pos;
      _targets[entry.key] = pos;
    }
    _frame.value++;
  }

  void _toggleSemesterLayout() {
    setState(() => _semesterLayout = !_semesterLayout);
    _userMovedCamera = false;
    _animateLayout(_semesterLayout ? _semesterPositions() : _homePositions());
  }

  void _reset() {
    setState(() {
      _semesterLayout = false;
      _showSemesterNodes = true;
      _localRootId = null;
      _localDepth = 1;
      _chainRootId = null;
      _filters = const GraphFilters();
      _display = const GraphDisplaySettings();
      _searchController.clear();
      _lastCenteredMatch = null;
    });
    _selectNode(null);
    _recomputeVisibility();
    _userMovedCamera = false;
    _animateLayout(_homePositions());
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

  void _zoomBy(double factor) {
    final center = _viewport.center(Offset.zero);
    final scale = (_scale * factor).clamp(_minScale, _maxScale);
    _animateCamera(scale, center - _toWorld(center) * scale);
  }

  void _animateCamera(double scale, Offset offset) {
    _zoomTargetScale = null;
    _panVelocity = Offset.zero;
    _cameraFromScale = _scale;
    _cameraFromOffset = _offset;
    _cameraToScale = scale;
    _cameraToOffset = offset;
    _cameraController.forward(from: 0);
  }

  void _startMotion() {
    if (_motionTicker.isActive) return;
    _lastTick = Duration.zero;
    _motionTicker.start();
  }

  void _onMotionTick(Duration elapsed) {
    final dt = _lastTick == Duration.zero ? 1 / 60 : ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _lastTick = elapsed;
    var active = false;

    // Không cho node đè lên nhau (bỏ qua khi đang chạy animation đổi bố cục).
    if (!_layoutController.isAnimating && _resolveCollisions()) active = true;

    // Node trôi về vị trí đích theo hàm mũ (không phụ thuộc tốc độ khung hình).
    final k = 1 - exp(-dt * 12);
    for (final entry in _targets.entries) {
      final pos = _positions[entry.key]!;
      final d = entry.value - pos;
      if (d.distanceSquared > 0.04) {
        _positions[entry.key] = pos + d * k;
        active = true;
      } else if (d != Offset.zero) {
        _positions[entry.key] = entry.value;
      }
    }

    // Zoom con lăn êm quanh vị trí con trỏ.
    final zoomTarget = _zoomTargetScale;
    if (zoomTarget != null) {
      final world = _toWorld(_zoomFocal);
      final nextScale = _scale + (zoomTarget - _scale) * (1 - exp(-dt * 16));
      final done = (nextScale - zoomTarget).abs() < 0.0008;
      _scale = done ? zoomTarget : nextScale;
      _offset = _zoomFocal - world * _scale;
      if (done) {
        _zoomTargetScale = null;
      } else {
        active = true;
      }
    }

    // Quán tính sau khi thả nền.
    if (_panVelocity.distance > 8) {
      _offset += _panVelocity * dt;
      _panVelocity *= exp(-dt * 6);
      active = true;
    } else {
      _panVelocity = Offset.zero;
    }

    _frame.value++;
    if (!active) _motionTicker.stop();
  }

  void _onCameraAnimate() {
    final t = Curves.easeInOutCubic.transform(_cameraController.value);
    _scale = _cameraFromScale + (_cameraToScale - _cameraFromScale) * t;
    _offset = Offset.lerp(_cameraFromOffset, _cameraToOffset, t)!;
    _frame.value++;
  }

  /// Vùng nhìn thấy thực tế (trừ thanh công cụ và bảng điều khiển khi đang mở trên màn rộng).
  Rect get _usableViewport {
    final reserveRight = _panelOpen && _viewport.width > 760 ? _panelWidth + 24 : 0.0;
    return Rect.fromLTWH(0, 64, max(_viewport.width - reserveRight, 200), max(_viewport.height - 64 - 70, 200));
  }

  void _fitToScreen({bool animate = true}) {
    final visible = _nodes.where((n) => _visibleIds.contains(n.id)).toList();
    if (visible.isEmpty || _viewport.isEmpty) return;
    Rect? bounds;
    for (final node in visible) {
      final rect = Rect.fromCircle(center: _positions[node.id]!, radius: node.radius + 30);
      bounds = bounds == null ? rect : bounds.expandToInclude(rect);
    }
    final area = _usableViewport.deflate(20);
    final scale = min(area.width / max(bounds!.width, 1), area.height / max(bounds.height, 1)).clamp(_minScale, 1.6);
    final offset = area.center - bounds.center * scale;
    if (animate) {
      _animateCamera(scale, offset);
    } else {
      _scale = scale;
      _offset = offset;
      _frame.value++;
    }
  }

  void _centerOn(String id) {
    final pos = _positions[id];
    if (pos == null) return;
    final scale = max(_scale, 0.9).clamp(_minScale, _maxScale);
    _animateCamera(scale, _usableViewport.center - pos * scale);
  }

  // ---------------------------------------------------------------------------
  // Tương tác
  // ---------------------------------------------------------------------------

  void _onHoverChanged(String? newHoverId) {
    if (_hoveredNodeId == newHoverId) return;
    _hoveredNodeId = newHoverId;
    _syncFocus();
  }

  void _syncFocus() {
    final focus = _hoveredNodeId ?? _draggingId;
    if (focus != null) {
      _activeFocusId = focus;
      _hoverAnimController.forward();
    } else {
      _hoverAnimController.reverse();
    }
    _frame.value++;
  }

  GraphNodeData? _hitTest(Offset screen) {
    final world = _toWorld(screen);
    final tolerance = 12 / _scale;
    GraphNodeData? best;
    var bestDistance = double.infinity;
    for (final node in _nodes) {
      if (!_visibleIds.contains(node.id)) continue;
      final pos = _positions[node.id]!;
      final radius = node.radius * _display.nodeScale;
      final d = world - pos;
      final distance = d.distance;
      // Vòng tròn node hoặc vùng nhãn chữ ngay bên dưới.
      final onLabel = d.dx.abs() <= 36 && d.dy >= radius && d.dy <= radius + 22;
      if ((distance <= max(radius + 8, tolerance) || onLabel) && distance < bestDistance) {
        best = node;
        bestDistance = distance;
      }
    }
    return best;
  }

  void _setCursor(MouseCursor cursor) => _cursor.value = cursor;

  void _onPointerHover(PointerHoverEvent event) {
    final hit = _hitTest(event.localPosition);
    _onHoverChanged(hit?.id);
    _setCursor(hit == null ? SystemMouseCursors.basic : SystemMouseCursors.click);
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      _cameraController.stop();
      _userMovedCamera = true;
      _zoomTargetScale = ((_zoomTargetScale ?? _scale) * exp(-event.scrollDelta.dy / 420)).clamp(_minScale, _maxScale);
      _zoomFocal = event.localPosition;
      _startMotion();
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    _cameraController.stop();
    _zoomTargetScale = null;
    _panVelocity = Offset.zero;
    _userMovedCamera = true;
    final hit = details.pointerCount == 1 ? _hitTest(_pointerDownPosition ?? details.localFocalPoint) : null;
    if (hit != null) {
      _layoutController.stop();
      _draggingId = hit.id;
      _setCursor(SystemMouseCursors.grabbing);
      _syncFocus();
    } else {
      _scaleAtGestureStart = _scale;
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final draggingId = _draggingId;
    if (draggingId != null) {
      final world = _toWorld(details.localFocalPoint);
      final delta = world - _targets[draggingId]!;
      // Node đang kéo bám sát con trỏ; hàng xóm trôi theo mượt qua ticker.
      _targets[draggingId] = world;
      _positions[draggingId] = world;
      // Hub nối với gần như mọi môn nên không kéo theo hàng xóm.
      if (!_nodeMap[draggingId]!.isHub) {
        for (final neighborId in _adjacencyMap[draggingId] ?? const <String>{}) {
          final neighbor = _nodeMap[neighborId];
          if (neighbor == null || neighbor.isHub || neighbor.isTag || !_visibleIds.contains(neighborId)) continue;
          _targets[neighborId] = _targets[neighborId]! + delta * _neighborFollow;
        }
      }
      _startMotion();
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

  /// Đẩy các node đang chồng lên nhau ra xa (chừa chỗ cho nhãn chữ bên dưới).
  /// Node đang kéo đứng yên, node bị chạm vào sẽ dạt ra. Trả về true nếu có node bị đẩy.
  bool _resolveCollisions() {
    const labelGap = 20.0;
    final visible = [
      for (final n in _nodes)
        if (_visibleIds.contains(n.id)) n,
    ];
    var moved = false;
    for (var pass = 0; pass < 2; pass++) {
      for (var i = 0; i < visible.length; i++) {
        final a = visible[i];
        for (var j = i + 1; j < visible.length; j++) {
          final b = visible[j];
          final pa = _targets[a.id]!, pb = _targets[b.id]!;
          final minDist = (a.radius + b.radius) * _display.nodeScale + labelGap;
          var d = pb - pa;
          final dist2 = d.distanceSquared;
          // Bỏ qua chồng lấn rất nhỏ để ticker dừng hẳn, không rung lắc.
          if (dist2 >= (minDist - 0.5) * (minDist - 0.5)) continue;
          var dist = sqrt(dist2);
          if (dist < 0.01) {
            // Trùng hẳn vị trí: chọn một hướng cố định để tách ra.
            d = Offset(cos(i + j.toDouble()), sin(i + j.toDouble()));
            dist = 1;
          }
          final push = d / dist * (minDist - dist);
          if (a.id == _draggingId) {
            _targets[b.id] = pb + push;
          } else if (b.id == _draggingId) {
            _targets[a.id] = pa - push;
          } else {
            _targets[a.id] = pa - push / 2;
            _targets[b.id] = pb + push / 2;
          }
          moved = true;
        }
      }
    }
    return moved;
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_draggingId == null) {
      // Thả nền khi đang lướt: trôi tiếp một đoạn rồi dừng.
      final v = details.velocity.pixelsPerSecond;
      if (details.pointerCount == 0 && v.distance > 200) {
        _panVelocity = v.distance > 2500 ? v / v.distance * 2500 : v;
        _startMotion();
      }
      return;
    }
    _draggingId = null;
    _setCursor(SystemMouseCursors.click);
    _syncFocus();
  }

  void _onTapUp(TapUpDetails details) {
    final hit = _hitTest(details.localPosition);
    if (hit == null) {
      // Bấm nền: bỏ làm nổi bật cố định (chuỗi tiên quyết / chạm giữ trên mobile).
      if (_chainRootId != null || _hoveredNodeId != null) {
        setState(() => _chainRootId = null);
        _onHoverChanged(null);
      }
      return;
    }
    if (hit.isHub || hit.isTag) {
      _showNodeModal(context, hit);
      return;
    }
    _selectNode(hit.id);
    _openNodeDialog(hit);
  }

  /// Chạm giữ trên màn cảm ứng tương đương hover trên desktop.
  void _onLongPressStart(LongPressStartDetails details) {
    _onHoverChanged(_hitTest(details.localPosition)?.id);
  }

  void _selectNode(String? id) {
    if (_selectedNodeId == id) return;
    setState(() => _selectedNodeId = id);
    widget.onNodeSelected?.call(id);
  }

  Future<void> _openNodeDialog(GraphNodeData node) async {
    final course = _courseById[node.id];
    final action = await GraphNodeDialog.show(
      context,
      node: GraphNode(
        id: node.id,
        title: node.title,
        semester: node.semester,
        credits: node.credits,
        countsInGpa: course?.countsInGpa ?? true,
      ),
      prerequisites: _prerequisitesOf(node.id).toList()..sort(),
      dependents: _dependentsOf(node.id).toList()..sort(),
      status: _statusOf(node.id),
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
        _setLocalRoot(node.id);
      case GraphNodeAction.showPrerequisiteChain:
        setState(() => _chainRootId = node.id);
        _frame.value++;
      case GraphNodeAction.advise:
        if (widget.onAdvisorRequested != null) {
          widget.onAdvisorRequested!(node.id);
        } else {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Chưa kết nối được chức năng tư vấn cho môn ${node.id}.')));
        }
    }
  }

  void _setLocalRoot(String? id) {
    setState(() => _localRootId = id);
    _recomputeVisibility();
    _userMovedCamera = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitToScreen();
    });
  }

  void _showNodeModal(BuildContext context, GraphNodeData node) {
    final connectedIds = (_adjacencyMap[node.id] ?? <String>{}).toSet()..remove(node.id);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -4))],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: node.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: node.color, width: 1.5),
                  ),
                  child: Text(
                    node.id,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: node.color),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.title,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        node.isHub ? 'Hub tri thức trung tâm' : 'Nhãn học kỳ Obsidian',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.pop(modalContext),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (connectedIds.isNotEmpty) ...[
              const Text(
                'Liên kết tri thức Vault:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: (connectedIds.toList()..sort()).take(24).map((cid) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Text(
                      cid,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0284C7)),
                    ),
                  );
                }).toList(),
              ),
            ],
            if (node.isTag) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(modalContext);
                    setState(() => _filters = _filters.copyWith(semesters: {node.semester}));
                    _recomputeVisibility();
                    _userMovedCamera = false;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _fitToScreen();
                    });
                  },
                  icon: const Icon(Icons.filter_alt_outlined, size: 18),
                  label: Text('Chỉ xem môn ${semesterLabel(node.semester)}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tìm kiếm
  // ---------------------------------------------------------------------------

  Set<String> _computeSearchMatches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return {};
    return {
      for (final node in _nodes)
        if (_visibleIds.contains(node.id) &&
            (node.id.toLowerCase().contains(q) || node.title.toLowerCase().contains(q)))
          node.id,
    };
  }

  String? _bestSearchMatch(String query) {
    final q = query.trim().toLowerCase();
    if (_searchMatches.isEmpty) return null;
    final ids = _searchMatches.toList()
      ..sort((a, b) {
        final aPrefix = a.toLowerCase().startsWith(q) ? 0 : 1;
        final bPrefix = b.toLowerCase().startsWith(q) ? 0 : 1;
        return aPrefix != bPrefix ? aPrefix - bPrefix : a.compareTo(b);
      });
    return ids.first;
  }

  void _onSearchChanged(String query) {
    setState(() => _searchMatches = _computeSearchMatches(query));
    _frame.value++;
    // Khớp thì tự căn giữa vào node phù hợp nhất.
    final best = _bestSearchMatch(query);
    if (best != null && best != _lastCenteredMatch) {
      _lastCenteredMatch = best;
      _centerOn(best);
    }
    if (best == null) _lastCenteredMatch = null;
  }

  void _onSearchSubmitted(String query) {
    final best = _bestSearchMatch(query);
    if (best == null) return;
    final node = _nodeMap[best]!;
    if (!node.isHub && !node.isTag) _selectNode(best);
    _centerOn(best);
  }

  // ---------------------------------------------------------------------------
  // Giao diện
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_nodes.isEmpty) {
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
          // Vùng Map đổi kích thước: căn lại nếu người dùng chưa tự zoom/kéo.
          if (firstLayout || !_userMovedCamera) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _fitToScreen(animate: !firstLayout);
            });
          }
        }
        final compact = viewport.width < 760;

        // ClipRect: CustomPainter vẽ theo toạ độ world nên phải cắt để không tràn ra ngoài.
        return ClipRect(
          child: ColoredBox(
            color: Colors.white,
            child: Stack(
              children: [
                Positioned.fill(child: _buildCanvas()),
                Positioned(
                  top: 12,
                  left: 16,
                  right: _panelOpen && !compact ? _panelWidth + 24 : 16,
                  child: _buildToolbar(compact),
                ),
                if (_localRootId != null || _chainRootId != null)
                  Positioned(top: 64, left: 16, child: _buildModeBanner()),
                Positioned(bottom: 48, left: 16, child: _buildLegend()),
                Positioned(
                  bottom: 12,
                  left: 16,
                  right: _panelOpen && !compact ? _panelWidth + 24 : 16,
                  child: Align(alignment: Alignment.centerLeft, child: _buildHint()),
                ),
                if (_panelOpen)
                  Positioned(
                    top: 12,
                    right: 12,
                    bottom: 12,
                    child: Align(
                      alignment: Alignment.topRight,
                      child: RepaintBoundary(child: _buildPanel()),
                    ),
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
      child: ValueListenableBuilder<MouseCursor>(
        valueListenable: _cursor,
        builder: (context, cursor, child) => MouseRegion(
          cursor: cursor,
          onHover: _onPointerHover,
          onExit: (_) {
            if (_draggingId == null) _onHoverChanged(null);
            _setCursor(SystemMouseCursors.basic);
          },
          child: child,
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: _onTapUp,
          onLongPressStart: _onLongPressStart,
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onScaleEnd: _onScaleEnd,
          child: RepaintBoundary(
            child: CustomPaint(
              size: Size.infinite,
              painter: ObsidianPureGraphPainter(
                repaint: Listenable.merge([_frame, _hoverAnimation]),
                nodes: _nodes,
                nodeById: _nodeMap,
                labelCache: _labelCache,
                edges: _edges,
                adjacencyMap: _adjacencyMap,
                positions: _positions,
                visibleIds: _visibleIds,
                cameraScale: () => _scale,
                cameraOffset: () => _offset,
                hoverProgress: () => _hoverAnimation.value,
                activeFocusId: () => _activeFocusId,
                selectedNodeId: _selectedNodeId,
                searchMatches: _searchMatches,
                chainIds: _chainRootId == null ? null : _chainOf(_chainRootId!),
                chainRootId: _chainRootId,
                display: _display,
                statusColors: _display.colorByStatus && _hasStatuses
                    ? {
                        for (final n in _nodes)
                          if (!n.isHub && !n.isTag) n.id: (_statusOf(n.id) ?? CourseProgressStatus.notStarted).color,
                      }
                    : const {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(bool compact) {
    final query = _searchController.text.trim();
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.96),
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Tìm nhanh môn học trên Graph (PRM393, PRO192, SWP391)...',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                suffixIcon: query.isEmpty
                    ? null
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _searchMatches.isEmpty ? 'Không có kết quả' : '${_searchMatches.length} kết quả',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            tooltip: 'Xoá tìm kiếm',
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          ),
                        ],
                      ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
              onChanged: _onSearchChanged,
              onSubmitted: _onSearchSubmitted,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _RoundToolButton(
          icon: _semesterLayout ? Icons.scatter_plot_outlined : Icons.view_column_outlined,
          label: compact ? null : (_semesterLayout ? 'Bố cục Obsidian' : 'Theo học kỳ'),
          tooltip: _semesterLayout ? 'Trở về bố cục Obsidian' : 'Sắp xếp theo học kỳ',
          active: _semesterLayout,
          onPressed: _toggleSemesterLayout,
        ),
        const SizedBox(width: 6),
        _RoundToolButton(icon: Icons.add, tooltip: 'Phóng to (+)', onPressed: () => _zoomBy(1.2)),
        const SizedBox(width: 6),
        _RoundToolButton(icon: Icons.remove, tooltip: 'Thu nhỏ (-)', onPressed: () => _zoomBy(1 / 1.2)),
        const SizedBox(width: 6),
        _RoundToolButton(icon: Icons.center_focus_strong, tooltip: 'Vừa màn hình', onPressed: _fitToScreen),
        const SizedBox(width: 6),
        _RoundToolButton(icon: Icons.restart_alt, tooltip: 'Đặt lại bố cục & bộ lọc', onPressed: _reset),
        if (!_panelOpen) ...[
          const SizedBox(width: 6),
          _RoundToolButton(
            icon: Icons.tune,
            label: compact ? null : 'Bộ lọc',
            tooltip: 'Mở bảng điều khiển',
            active: !_filters.isDefault,
            onPressed: () => setState(() => _panelOpen = true),
          ),
        ],
      ],
    );
  }

  Widget _buildModeBanner() {
    final isLocal = _localRootId != null;
    return Material(
      color: const Color(0xFFF5F3FF),
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(16),
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
                  Text('Độ sâu $_localDepth', style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155))),
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
                        _localDepth = v.round();
                        _setLocalRoot(_localRootId);
                      },
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _setLocalRoot(null),
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
                      _frame.value++;
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

  Widget _buildLegendItem(Color color, String label, {bool isLine = false, bool isTag = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLine)
            Container(
              width: 14,
              height: 3.5,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
            )
          else
            Container(
              width: isTag ? 8 : 10,
              height: isTag ? 8 : 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.2),
              ),
            ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    final byStatus = _display.colorByStatus && _hasStatuses;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: _showLegend ? 260 : 185,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _showLegend = !_showLegend),
            child: Row(
              children: [
                const Icon(Icons.palette_outlined, size: 15, color: Color(0xFF8B5CF6)),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Chú thích màu sắc',
                    style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  _showLegend ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                  size: 18,
                  color: const Color(0xFF64748B),
                ),
              ],
            ),
          ),
          if (_showLegend) ...[
            const SizedBox(height: 6),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 6),
            _buildLegendItem(const Color(0xFF8B5CF6), 'Liên kết đang soi (Hover)', isLine: true),
            _buildLegendItem(kPrerequisiteColor, 'Chuỗi tiên quyết', isLine: true),
            _buildLegendItem(const Color(0xFFF59E0B), 'Hub chương trình & CĐR'),
            if (byStatus)
              for (final s in CourseProgressStatus.values) _buildLegendItem(s.color, s.label)
            else ...[
              _buildLegendItem(const Color(0xFF0284C7), 'Core CS & Kỹ thuật PM'),
              _buildLegendItem(const Color(0xFF10B981), 'Web & Java cơ sở'),
              _buildLegendItem(const Color(0xFFF97316), 'Chuyên ngành .NET & SWP'),
              _buildLegendItem(const Color(0xFF8B5CF6), 'Capstone, Chính trị & KN'),
              _buildLegendItem(const Color(0xFFEF4444), 'Kiến trúc & Đồ án thực chiến'),
              _buildLegendItem(const Color(0xFF6B7280), 'Toán, Ngoại ngữ & Đại cương'),
            ],
            _buildLegendItem(const Color(0xFF16A34A), 'Nhãn học kỳ (#HK0 - #HK9)', isTag: true),
          ],
        ],
      ),
    );
  }

  Widget _buildHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pan_tool_outlined, size: 14, color: Color(0xFF8B5CF6)),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              'Kéo nền để di chuyển • Kéo node để sắp xếp • Cuộn để Zoom • Rê chuột soi liên kết • Click xem chi tiết',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF475569), fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel() {
    final semesters = {
      for (final n in _nodes)
        if (!n.isHub && !n.isTag) n.semester,
    }.toList()..sort();
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: max(_viewport.height - 96, 200)),
      child: GraphControlPanel(
        showSearch: false,
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
          setState(() => _display = display);
          _frame.value++;
        },
        semesterNodesLabel: 'Hiện nhãn học kỳ (#HK)',
        showSemesterNodes: _showSemesterNodes,
        onShowSemesterNodesChanged: (value) {
          setState(() => _showSemesterNodes = value);
          _recomputeVisibility();
        },
        onClose: () => setState(() => _panelOpen = false),
      ),
    );
  }
}

class _RoundToolButton extends StatelessWidget {
  const _RoundToolButton({required this.icon, required this.onPressed, this.label, this.tooltip, this.active = false});

  final IconData icon;
  final String? label;
  final String? tooltip;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final fg = active ? const Color(0xFF7C3AED) : const Color(0xFF0F172A);
    final button = Material(
      color: active ? const Color(0xFFF5F3FF) : Colors.white,
      shape: StadiumBorder(
        side: BorderSide(color: active ? const Color(0xFF8B5CF6) : const Color(0xFFE2E8F0), width: active ? 1.5 : 1),
      ),
      elevation: 1,
      shadowColor: Colors.black12,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: label == null ? 11 : 14, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: fg),
              if (label != null) ...[
                const SizedBox(width: 6),
                Text(
                  label!,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: fg),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class ObsidianPureGraphPainter extends CustomPainter {
  ObsidianPureGraphPainter({
    required Listenable repaint,
    required this.nodes,
    required this.nodeById,
    required this.labelCache,
    required this.edges,
    required this.adjacencyMap,
    required this.positions,
    required this.visibleIds,
    required this.cameraScale,
    required this.cameraOffset,
    required this.hoverProgress,
    required this.activeFocusId,
    required this.selectedNodeId,
    required this.searchMatches,
    required this.chainIds,
    required this.chainRootId,
    required this.display,
    required this.statusColors,
  }) : super(repaint: repaint);

  final List<GraphNodeData> nodes;
  final Map<String, GraphNodeData> nodeById;
  final Map<String, TextPainter> labelCache;
  final List<VaultEdge> edges;
  final Map<String, Set<String>> adjacencyMap;
  final Map<String, Offset> positions;
  final Set<String> visibleIds;
  final double Function() cameraScale;
  final Offset Function() cameraOffset;
  final double Function() hoverProgress;
  final String? Function() activeFocusId;
  final String? selectedNodeId;
  final Set<String> searchMatches;
  final Set<String>? chainIds;
  final String? chainRootId;
  final GraphDisplaySettings display;
  final Map<String, Color> statusColors;

  static const Color _hoverColor = Color(0xFF8B5CF6);
  static const Color _edgeColor = Color(0xFFCBD5E1);
  static const Color _searchColor = Color(0xFFFBBF24);

  // Bút vẽ dùng chung
  static final Paint _edgePaint = Paint()..style = PaintingStyle.stroke;
  static final Paint _arrowPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _nodeFillPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _nodeBorderPaint = Paint()..style = PaintingStyle.stroke;
  static final Paint _nodeGlowPaint = Paint()..style = PaintingStyle.stroke;

  static void _addArrow(Path path, Offset start, Offset end, double targetRadius, double size) {
    final angle = atan2(end.dy - start.dy, end.dx - start.dx);
    final tip = Offset(end.dx - (targetRadius + 3) * cos(angle), end.dy - (targetRadius + 3) * sin(angle));
    path
      ..moveTo(tip.dx - size * cos(angle - pi / 6), tip.dy - size * sin(angle - pi / 6))
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - size * cos(angle + pi / 6), tip.dy - size * sin(angle + pi / 6))
      ..close();
  }

  void _drawArrow(Canvas canvas, Offset start, Offset end, double targetRadius, double size, Color color) {
    final path = Path();
    _addArrow(path, start, end, targetRadius, size);
    _arrowPaint.color = color;
    canvas.drawPath(path, _arrowPaint);
  }

  /// Nhãn chữ được cache theo (node, kiểu chữ, mức độ mờ đã lượng tử hoá).
  TextPainter _label(GraphNodeData node, bool emphasized, bool isFocused, double opacity) {
    final q = (opacity * 20).round();
    final key = '${node.id}|${emphasized ? 1 : 0}|${isFocused ? 1 : 0}|$q';
    final cached = labelCache[key];
    if (cached != null) return cached;
    final o = q / 20;
    final textColor = isFocused
        ? const Color(0xFF0F172A)
        : (emphasized ? const Color(0xFF1E293B) : (node.isTag ? const Color(0xFF16A34A) : const Color(0xFF4B5563)));
    final tp = TextPainter(
      text: TextSpan(
        text: node.id,
        style: TextStyle(
          fontSize: emphasized ? 13.0 : (node.isHub ? 12.0 : (node.isTag ? 10.5 : 11.5)),
          fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
          color: textColor.withOpacity(o),
          shadows: [Shadow(color: Colors.white.withOpacity(o * 0.9), blurRadius: 3)],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    labelCache[key] = tp;
    return tp;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final focusId = activeFocusId();
    final t = focusId == null ? 0.0 : hoverProgress();
    final connectedIds = focusId != null ? adjacencyMap[focusId] : null;
    final chain = focusId == null ? chainIds : null;
    final widthScale = display.edgeWidth / 1.4;

    final isFocusingHub =
        focusId == 'Curriculum_Overview' || focusId == 'BIT_SE_K19B' || focusId == 'Program_Learning_Outcomes';

    canvas.save();
    canvas.translate(cameraOffset().dx, cameraOffset().dy);
    canvas.scale(cameraScale());

    // Các cạnh thường cùng màu được gom vào một Path để vẽ một lần.
    final normalEdges = Path();
    final normalArrows = Path();
    final normalOpacity = lerpDouble(0.50, 0.0, t)!;

    // 1. CÁC ĐƯỜNG LIÊN KẾT (EDGES) & MŨI TÊN (ARROWS)
    for (final edge in edges) {
      if (!visibleIds.contains(edge.from) || !visibleIds.contains(edge.to)) continue;
      final fromNode = nodeById[edge.from]!;
      final toNode = nodeById[edge.to]!;
      final start = positions[edge.from]!;
      final end = positions[edge.to]!;
      final toRadius = toNode.radius * display.nodeScale;

      if (chain != null) {
        // CHẾ ĐỘ CHUỖI TIÊN QUYẾT: chỉ tô các liên kết giữa môn trong chuỗi.
        final inChain = chain.contains(edge.from) && chain.contains(edge.to) && !fromNode.isTag && !toNode.isTag;
        _edgePaint
          ..color = inChain ? kPrerequisiteColor : _edgeColor.withOpacity(0.10)
          ..strokeWidth = (inChain ? 2.2 : 1.0) * widthScale;
        canvas.drawLine(start, end, _edgePaint);
        if (inChain && display.showArrows) _drawArrow(canvas, start, end, toRadius, 9, kPrerequisiteColor);
        continue;
      }

      final isDirectlyConnected = focusId != null && (edge.from == focusId || edge.to == focusId);

      // Nếu đang hover vào Hub trung tâm, chỉ giữ liên kết giữa các Hub và với các nhãn kỳ để tránh rối.
      if (isFocusingHub &&
          isDirectlyConnected &&
          !edge.isHub &&
          !edge.to.startsWith('#HK') &&
          !edge.from.startsWith('#HK')) {
        continue;
      }

      if (isDirectlyConnected) {
        // Lerp mượt mà từ xám nhạt sang tím và tăng độ dày.
        final edgeOpacity = lerpDouble(0.50, 1.0, t)!;
        _edgePaint
          ..color = Color.lerp(_edgeColor, _hoverColor, t)!.withOpacity(edgeOpacity)
          ..strokeWidth = lerpDouble(1.0, 2.4, t)! * widthScale;
        canvas.drawLine(start, end, _edgePaint);
        if (display.showArrows) {
          final arrowColor = Color.lerp(const Color(0xFF94A3B8), _hoverColor, t)!;
          _drawArrow(canvas, start, end, toRadius, lerpDouble(6.0, 9.5, t)!, arrowColor.withOpacity(edgeOpacity));
        }
      } else {
        // Đường không liên quan: mờ dần nhẹ nhàng khi hover.
        if (normalOpacity > 0.01) {
          normalEdges
            ..moveTo(start.dx, start.dy)
            ..lineTo(end.dx, end.dy);
          if (display.showArrows && !edge.isHub) _addArrow(normalArrows, start, end, toRadius, 6.0);
        }
      }
    }
    if (normalOpacity > 0.01) {
      _edgePaint
        ..color = _edgeColor.withOpacity(normalOpacity)
        ..strokeWidth = 1.0 * widthScale;
      canvas.drawPath(normalEdges, _edgePaint);
      _arrowPaint.color = const Color(0xFF94A3B8).withOpacity(normalOpacity);
      canvas.drawPath(normalArrows, _arrowPaint);
    }

    // 2. CÁC NODE VÀ NHÃN CHỮ
    for (final node in nodes) {
      if (!visibleIds.contains(node.id)) continue;
      final pos = positions[node.id]!;
      final radius = node.radius * display.nodeScale;
      final isFocused = focusId == node.id;
      final isConnected = connectedIds != null && connectedIds.contains(node.id);
      final inChain = chain != null && chain.contains(node.id);
      final isOutside = chain != null ? !inChain : (focusId != null && !isFocused && !isConnected);
      final isSearched = searchMatches.contains(node.id);
      final isSelected = selectedNodeId == node.id;

      final double opacity = chain != null ? (inChain ? 1.0 : 0.12) : (isOutside ? lerpDouble(1.0, 0.08, t)! : 1.0);
      final nodeColor = statusColors[node.id] ?? node.color;

      // A. Vòng hào quang cho Hub trung tâm
      if (node.isHub) {
        _nodeGlowPaint
          ..color = node.color.withOpacity(0.35 * opacity)
          ..strokeWidth = 1.6;
        canvas.drawCircle(pos, radius + 6.0, _nodeGlowPaint);
      }

      // B. Quầng sáng khi Focus / Connected / Tìm kiếm / Chuỗi tiên quyết
      if (inChain) {
        _nodeGlowPaint
          ..color = (node.id == chainRootId ? _hoverColor : kPrerequisiteColor).withOpacity(0.55)
          ..strokeWidth = 4;
        canvas.drawCircle(pos, radius + 3.5, _nodeGlowPaint);
      } else if (isSearched || ((isFocused || isConnected) && !isOutside)) {
        final glowColor = isSearched ? _searchColor : (isFocused ? _hoverColor : nodeColor);
        final glowIntensity = isSearched ? 0.6 : (isFocused ? 0.65 * t : 0.35 * t);
        _nodeGlowPaint
          ..color = glowColor.withOpacity(glowIntensity)
          ..strokeWidth = isFocused ? lerpDouble(2.0, 5.0, t)! : 3.0;
        canvas.drawCircle(pos, radius + (isFocused ? 3.5 : 2.0), _nodeGlowPaint);
      }

      // C. Vòng tròn node chính
      final baseColor = isSearched ? _searchColor : (isFocused ? Color.lerp(nodeColor, _hoverColor, t)! : nodeColor);
      _nodeFillPaint.color = baseColor.withOpacity(opacity);
      canvas.drawCircle(pos, radius, _nodeFillPaint);

      // D. Viền trắng quanh node
      _nodeBorderPaint
        ..color = (isFocused ? Colors.white : Colors.white70).withOpacity(opacity)
        ..strokeWidth = isFocused ? lerpDouble(1.5, 2.5, t)! : 1.4;
      canvas.drawCircle(pos, radius, _nodeBorderPaint);

      // E. Vòng chọn (đồng bộ với tab Danh sách môn)
      if (isSelected) {
        _nodeGlowPaint
          ..color = kSelectionColor.withOpacity(0.9 * max(opacity, 0.4))
          ..strokeWidth = 2.5;
        canvas.drawCircle(pos, radius + 5.5, _nodeGlowPaint);
      }

      // F. Nhãn chữ
      final emphasized = isFocused || isConnected || inChain;
      if (!display.showLabels && !emphasized && !isSearched && !isSelected && !node.isHub) continue;

      final tp = _label(node, emphasized, isFocused, opacity);
      tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy + radius + 3.5));
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ObsidianPureGraphPainter oldDelegate) => true;
}
