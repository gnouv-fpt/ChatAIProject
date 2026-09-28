import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../pages/course_detail_page.dart';
import '../../../state/course_catalog.dart';
import '../data/vault_graph_data.dart';

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
    return Offset(
      center.dx + normPos.dx * maxRadius,
      center.dy + normPos.dy * maxRadius,
    );
  }
}

class GraphViewScreen extends StatefulWidget {
  const GraphViewScreen({super.key});

  @override
  State<GraphViewScreen> createState() => _GraphViewScreenState();
}

class _GraphViewScreenState extends State<GraphViewScreen> with SingleTickerProviderStateMixin {
  final TransformationController _transformationController = TransformationController();
  final ValueNotifier<MouseCursor> _cursorNotifier = ValueNotifier<MouseCursor>(SystemMouseCursors.basic);

  late final AnimationController _hoverAnimController;
  late final Animation<double> _hoverAnimation;

  String? _hoveredNodeId;
  String? _activeFocusId; // Node đang được soi (giữ nguyên khi animation fade-out đang chạy)
  String? _selectedNodeId;
  String _searchQuery = '';
  bool _showArrows = true;
  bool _showLegend = true;

  List<GraphNodeData> _nodes = [];
  Map<String, GraphNodeData> _nodeMap = {};
  List<VaultEdge> _edges = [];
  Map<String, Set<String>> _adjacencyMap = {};

  bool _isLoading = true;
  bool _didInitialCenter = false;

  @override
  void initState() {
    super.initState();

    // Khởi tạo AnimationController cho hiệu ứng chuyển đổi mượt mà chuẩn Obsidian (fade in/out nhẹ nhàng)
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
      if (status == AnimationStatus.dismissed && _hoveredNodeId == null) {
        if (mounted) {
          setState(() {
            _activeFocusId = null;
          });
        }
      }
    });

    _loadGraphData();
  }

  @override
  void dispose() {
    _hoverAnimController.dispose();
    _cursorNotifier.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _loadGraphData() {
    final catalog = context.read<CourseCatalog>();
    final courses = catalog.courses;
    final coursesMap = {for (var c in courses) c.code: c};

    final nodes = <GraphNodeData>[];
    final nodeMap = <String, GraphNodeData>{};

    // 1. Ba Hub trung tâm chuẩn Obsidian Vault
    final hub1 = GraphNodeData(
      id: 'Curriculum_Overview',
      label: 'Tổng quan chương trình',
      title: 'Tổng quan chương trình đào tạo BIT SE K19B',
      semester: 0,
      credits: 145,
      color: const Color(0xFFF59E0B), // Vàng cam Obsidian Hub lớn
      normPos: kObsidianGraphCoords['Curriculum_Overview'] ?? const Offset(0.00, -0.04),
      radius: 26,
      isHub: true,
    );
    final hub2 = GraphNodeData(
      id: 'Program_Learning_Outcomes',
      label: 'Chuẩn đầu ra chương trình',
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
      label: 'BIT SE K19B',
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
        label: 'Học kỳ $sem',
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
      } else if (id == 'SWE201c' || id == 'SWE202c' || id == 'SWE102' || id == 'LAB211' || id == 'PRJ301' || id == 'DBI202') {
        color = const Color(0xFF10B981); // Môn Xanh ngọc
        radius = 12.0;
      } else if (id == 'SEP490' || id.startsWith('MLN') || id == 'VNR202' || id == 'HCM202' || id == 'ITE302c' || id == 'SSL101c') {
        color = const Color(0xFF8B5CF6); // Capstone, Chính trị, Kỹ năng Tím
        radius = 12.5;
      } else if (id == 'SWD392' || id == 'PRU213' || id.startsWith('EXE')) {
        color = const Color(0xFFEF4444); // Môn Đỏ
        radius = 12.5;
      } else if (id == 'MAC101' || id == 'TRS601' || id.startsWith('JPD') || id == 'ENW493c' || id == 'PMG201c' || id == 'WDU203c') {
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

    // 4. Nạp 100% chính xác toàn bộ 334 liên kết trích xuất từ flm_knowledge_vault
    final validEdges = <VaultEdge>[];
    final adjacency = <String, Set<String>>{};

    for (final e in kVaultEdges) {
      if (nodeMap.containsKey(e.from) && nodeMap.containsKey(e.to)) {
        validEdges.add(e);
        adjacency.putIfAbsent(e.from, () => <String>{}).add(e.to);
        adjacency.putIfAbsent(e.to, () => <String>{}).add(e.from);
      }
    }

    setState(() {
      _nodes = nodes;
      _nodeMap = nodeMap;
      _edges = validEdges;
      _adjacencyMap = adjacency;
      _isLoading = false;
    });
  }

  void _onHoverChanged(String? newHoverId) {
    if (_hoveredNodeId == newHoverId) return;

    _hoveredNodeId = newHoverId;

    if (newHoverId != null) {
      _activeFocusId = newHoverId;
      _hoverAnimController.forward();
    } else {
      _hoverAnimController.reverse();
    }
  }

  void _centerGraph(Size viewportSize) {
    if (viewportSize.width <= 0 || viewportSize.height <= 0) return;
    final scaleX = (viewportSize.width - 60) / 1250.0;
    final scaleY = (viewportSize.height - 60) / 1150.0;
    final scale = min(scaleX, scaleY).clamp(0.55, 1.10);

    final tx = (viewportSize.width - kCanvasWidth * scale) / 2;
    final ty = (viewportSize.height - kCanvasHeight * scale) / 2;

    final matrix = Matrix4.identity()
      ..translate(tx, ty)
      ..scale(scale, scale);

    _transformationController.value = matrix;
  }

  void _zoomBy(double factor, Size viewportSize) {
    final currentMatrix = _transformationController.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();
    final newScale = (currentScale * factor).clamp(0.40, 2.50);
    final actualFactor = newScale / currentScale;

    final centerViewport = Offset(viewportSize.width / 2, viewportSize.height / 2);
    final matrix = Matrix4.identity()
      ..translate(centerViewport.dx, centerViewport.dy)
      ..scale(actualFactor, actualFactor)
      ..translate(-centerViewport.dx, -centerViewport.dy)
      ..multiply(currentMatrix);

    _transformationController.value = matrix;
  }

  GraphNodeData? _findNodeAt(Offset localPos) {
    for (final node in _nodes) {
      final pos = node.getActualPos(kCanvasCenter, kGraphMaxRadius);
      final dx = localPos.dx - pos.dx;
      final dy = localPos.dy - pos.dy;
      // Hit check: vòng tròn node hoặc vùng chữ ngay dưới
      if (dx * dx + dy * dy <= (node.radius + 10) * (node.radius + 10) ||
          (dx.abs() <= 36 && dy >= node.radius && dy <= node.radius + 22)) {
        return node;
      }
    }
    return null;
  }

  void _showNodeModal(BuildContext context, GraphNodeData node) {
    setState(() => _selectedNodeId = node.id);

    final connectedIds = (_adjacencyMap[node.id] ?? <String>{}).toSet()..remove(node.id);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
              offset: Offset(0, -4),
            )
          ],
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: node.color,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        node.isHub ? 'Hub tri thức trung tâm' : (node.isTag ? 'Nhãn học kỳ Obsidian' : 'Học kỳ ${node.semester} • ${node.credits} tín chỉ'),
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
                'Liên kết tri thức Vault (Tiên quyết, Mở khóa & Học kỳ):',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: connectedIds.take(16).map((cid) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Text(
                      cid,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(modalContext);
                      if (!node.isHub && !node.isTag) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => CourseDetailPage(code: node.id),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.menu_book_outlined, size: 18),
                    label: const Text('Xem chi tiết đề cương'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(modalContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Đang chọn môn ${node.id}. Bạn có thể hỏi AI ngay ở ô chat góc phải!'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('Hỏi AI về môn này'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).then((_) {
      if (mounted) setState(() => _selectedNodeId = null);
    });
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
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
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
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF475569),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

        // Tự động căn giữa đồ thị lần đầu tiên
        if (!_didInitialCenter && viewportSize.width > 0 && viewportSize.height > 0) {
          _didInitialCenter = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _centerGraph(viewportSize);
          });
        }

        return Container(
          color: Colors.white,
          child: Stack(
            children: [
              // BỘ RENDER ĐỒ THỊ 100% CANVAS GPU - SIÊU MƯỢT 60+ FPS VỚI ANIMATION CURVED LERP
              InteractiveViewer(
                transformationController: _transformationController,
                constrained: false, // Kéo di chuyển tự do 360 độ khắp không gian 2D
                boundaryMargin: const EdgeInsets.all(1400),
                minScale: 0.40,
                maxScale: 2.50,
                panEnabled: true,
                scaleEnabled: true,
                child: SizedBox(
                  width: kCanvasWidth,
                  height: kCanvasHeight,
                  child: ValueListenableBuilder<MouseCursor>(
                    valueListenable: _cursorNotifier,
                    builder: (context, currentCursor, _) {
                      return MouseRegion(
                        cursor: currentCursor,
                        // BẮT HOVER TRỰC TIẾP TRÊN CANVAS VÀ KÍCH HOẠT ANIMATION CHUYỂN CẢNH MƯỢT MÀ
                        onHover: (event) {
                          final hit = _findNodeAt(event.localPosition);
                          final newHoverId = hit?.id;
                          _onHoverChanged(newHoverId);

                          final newCursor = hit != null ? SystemMouseCursors.click : SystemMouseCursors.basic;
                          if (_cursorNotifier.value != newCursor) {
                            _cursorNotifier.value = newCursor;
                          }
                        },
                        onExit: (_) {
                          _onHoverChanged(null);
                          if (_cursorNotifier.value != SystemMouseCursors.basic) {
                            _cursorNotifier.value = SystemMouseCursors.basic;
                          }
                        },
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          // CLICK MỞ MODAL NGAY LẬP TỨC
                          onTapUp: (details) {
                            final hit = _findNodeAt(details.localPosition);
                            if (hit != null) {
                              _showNodeModal(context, hit);
                            }
                          },
                          child: CustomPaint(
                            size: const Size(kCanvasWidth, kCanvasHeight),
                            painter: ObsidianPureGraphPainter(
                              nodes: _nodes,
                              nodeMap: _nodeMap,
                              edges: _edges,
                              adjacencyMap: _adjacencyMap,
                              center: kCanvasCenter,
                              maxRadius: kGraphMaxRadius,
                              hoverAnimation: _hoverAnimation,
                              activeFocusId: _activeFocusId,
                              selectedNodeId: _selectedNodeId,
                              searchQuery: _searchQuery,
                              showArrows: _showArrows,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // THANH TÌM KIẾM VÀ ĐIỀU KHIỂN THU PHÓNG TRÊN CÙNG
              Positioned(
                top: 14,
                left: 20,
                right: 20,
                child: Row(
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
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Tìm nhanh môn học trên Graph (PRM393, PRO192, SWP391)...',
                            hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                            prefixIcon: Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 11),
                          ),
                          onChanged: (v) => setState(() => _searchQuery = v.trim()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.96),
                        borderRadius: BorderRadius.circular(21),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                      ),
                      child: Row(
                        children: [
                          const Text('Mũi tên', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                          const SizedBox(width: 4),
                          Switch(
                            value: _showArrows,
                            activeColor: const Color(0xFF8B5CF6),
                            onChanged: (val) => setState(() => _showArrows = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Nút Zoom In (+)
                    IconButton.filledTonal(
                      icon: const Icon(Icons.add, size: 18),
                      tooltip: 'Phóng to (+)',
                      onPressed: () => _zoomBy(1.20, viewportSize),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Nút Zoom Out (-)
                    IconButton.filledTonal(
                      icon: const Icon(Icons.remove, size: 18),
                      tooltip: 'Thu nhỏ (-)',
                      onPressed: () => _zoomBy(0.83, viewportSize),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Nút Căn giữa đồ thị
                    IconButton.filledTonal(
                      icon: const Icon(Icons.center_focus_strong, size: 18),
                      tooltip: 'Căn giữa đồ thị',
                      onPressed: () => _centerGraph(viewportSize),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ],
                ),
              ),

              // BẢNG CHÚ THÍCH ĐỒ THỊ (GRAPH LEGEND) - ĐẶT GÓC DƯỚI BÊN TRÁI TRÁNH ĐỤNG CHAT PANEL
              Positioned(
                bottom: 48,
                left: 20,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: _showLegend ? 260 : 185,
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.96),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setState(() => _showLegend = !_showLegend),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Row(
                                children: [
                                  Icon(Icons.palette_outlined, size: 15, color: Color(0xFF8B5CF6)),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Chú thích màu sắc',
                                      style: TextStyle(
                                        fontSize: 12.0,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
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
                        _buildLegendItem(const Color(0xFFF59E0B), 'Hub chương trình & CĐR'),
                        _buildLegendItem(const Color(0xFF0284C7), 'Core CS & Kỹ thuật PM'),
                        _buildLegendItem(const Color(0xFF10B981), 'Web & Java cơ sở'),
                        _buildLegendItem(const Color(0xFFF97316), 'Chuyên ngành .NET & SWP'),
                        _buildLegendItem(const Color(0xFF8B5CF6), 'Capstone, Chính trị & KN'),
                        _buildLegendItem(const Color(0xFFEF4444), 'Kiến trúc & Đồ án thực chiến'),
                        _buildLegendItem(const Color(0xFF6B7280), 'Toán, Ngoại ngữ & Đại cương'),
                        _buildLegendItem(const Color(0xFF16A34A), 'Nhãn học kỳ (#HK0 - #HK9)', isTag: true),
                      ],
                    ],
                  ),
                ),
              ),

              // HƯỚNG DẪN UX Ở CHÂN TRANG
              Positioned(
                bottom: 12,
                left: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.94),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.pan_tool_outlined, size: 14, color: Color(0xFF8B5CF6)),
                      SizedBox(width: 6),
                      Text(
                        'Kéo chuột di chuyển mượt mà • Cuộn để Zoom • Rê chuột để soi liên kết nhẹ nhàng • Click xem chi tiết',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ObsidianPureGraphPainter extends CustomPainter {
  ObsidianPureGraphPainter({
    required this.nodes,
    required this.nodeMap,
    required this.edges,
    required this.adjacencyMap,
    required this.center,
    required this.maxRadius,
    required this.hoverAnimation,
    required this.activeFocusId,
    required this.selectedNodeId,
    required this.searchQuery,
    required this.showArrows,
  }) : super(repaint: hoverAnimation);

  final List<GraphNodeData> nodes;
  final Map<String, GraphNodeData> nodeMap;
  final List<VaultEdge> edges;
  final Map<String, Set<String>> adjacencyMap;
  final Offset center;
  final double maxRadius;
  final Animation<double> hoverAnimation;
  final String? activeFocusId;
  final String? selectedNodeId;
  final String searchQuery;
  final bool showArrows;

  // Bút vẽ dùng chung
  static final Paint _edgePaint = Paint()..style = PaintingStyle.stroke;
  static final Paint _arrowPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _nodeFillPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _nodeBorderPaint = Paint()..style = PaintingStyle.stroke;
  static final Paint _nodeGlowPaint = Paint()..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final double t = hoverAnimation.value;
    final focusId = activeFocusId ?? selectedNodeId;
    final Set<String>? connectedIds = focusId != null ? adjacencyMap[focusId] : null;

    final isFocusingHub = focusId == 'Curriculum_Overview' ||
        focusId == 'BIT_SE_K19B' ||
        focusId == 'Program_Learning_Outcomes';

    // 1. VẼ CÁC ĐƯỜNG LIÊN KẾT (EDGES) & MŨI TÊN (ARROWS) VỚI ANIMATION LERP MƯỢT MÀ
    for (final edge in edges) {
      final fromNode = nodeMap[edge.from];
      final toNode = nodeMap[edge.to];
      if (fromNode == null || toNode == null) continue;

      final isDirectlyConnected = focusId != null &&
          (edge.from == focusId || edge.to == focusId);

      // Nếu đang hover vào Hub trung tâm, chỉ giữ liên kết giữa các Hub và với các nhãn kỳ để tránh nổ 50 mũi tên
      if (isFocusingHub && isDirectlyConnected && !edge.isHub && !edge.to.startsWith('#HK') && !edge.from.startsWith('#HK')) {
        continue;
      }

      final start = fromNode.getActualPos(center, maxRadius);
      final end = toNode.getActualPos(center, maxRadius);

      if (isDirectlyConnected) {
        // ĐƯỜNG LIÊN KẾT TRỰC TIẾP ĐANG ĐƯỢC SOI:
        // Lerp mượt mà từ màu xám nhạt sang tím rực rỡ và tăng độ dày từ 1.0 lên 2.4
        final strokeW = lerpDouble(1.0, 2.4, t)!;
        final edgeColor = Color.lerp(const Color(0xFFCBD5E1), const Color(0xFF8B5CF6), t)!;
        final edgeOpacity = lerpDouble(0.50, 1.0, t)!;

        _edgePaint
          ..color = edgeColor.withOpacity(edgeOpacity)
          ..strokeWidth = strokeW;
        canvas.drawLine(start, end, _edgePaint);

        // Vẽ mũi tên hướng cho liên kết đang focus
        if (showArrows && (!edge.isHub || isDirectlyConnected)) {
          final double angle = atan2(end.dy - start.dy, end.dx - start.dx);
          final double arrowRadius = toNode.radius + 3.0;
          final Offset arrowPos = Offset(
            end.dx - arrowRadius * cos(angle),
            end.dy - arrowRadius * sin(angle),
          );

          final double arrowSize = lerpDouble(6.0, 9.5, t)!;
          final arrowColor = Color.lerp(const Color(0xFF94A3B8), const Color(0xFF8B5CF6), t)!;
          final path = Path()
            ..moveTo(
              arrowPos.dx - arrowSize * cos(angle - pi / 6),
              arrowPos.dy - arrowSize * sin(angle - pi / 6),
            )
            ..lineTo(arrowPos.dx, arrowPos.dy)
            ..lineTo(
              arrowPos.dx - arrowSize * cos(angle + pi / 6),
              arrowPos.dy - arrowSize * sin(angle + pi / 6),
            )
            ..close();

          _arrowPaint.color = arrowColor.withOpacity(edgeOpacity);
          canvas.drawPath(path, _arrowPaint);
        }
      } else {
        // ĐƯỜNG KHÔNG LIÊN QUAN:
        // Khi hover, mờ dần nhẹ nhàng về 0.0 (fade out mềm mại) thay vì biến mất đột ngột
        final normalOpacity = lerpDouble(0.50, 0.0, t)!;
        if (normalOpacity > 0.01) {
          _edgePaint
            ..color = const Color(0xFFCBD5E1).withOpacity(normalOpacity)
            ..strokeWidth = 1.0;
          canvas.drawLine(start, end, _edgePaint);

          if (showArrows && !edge.isHub) {
            final double angle = atan2(end.dy - start.dy, end.dx - start.dx);
            final double arrowRadius = toNode.radius + 3.0;
            final Offset arrowPos = Offset(
              end.dx - arrowRadius * cos(angle),
              end.dy - arrowRadius * sin(angle),
            );

            const double arrowSize = 6.0;
            final path = Path()
              ..moveTo(
                arrowPos.dx - arrowSize * cos(angle - pi / 6),
                arrowPos.dy - arrowSize * sin(angle - pi / 6),
              )
              ..lineTo(arrowPos.dx, arrowPos.dy)
              ..lineTo(
                arrowPos.dx - arrowSize * cos(angle + pi / 6),
                arrowPos.dy - arrowSize * sin(angle + pi / 6),
              )
              ..close();

            _arrowPaint.color = const Color(0xFF94A3B8).withOpacity(normalOpacity);
            canvas.drawPath(path, _arrowPaint);
          }
        }
      }
    }

    // 2. VẼ CÁC NODE VÀ NHÃN CHỮ TRÊN CANVAS VỚI HIỆU ỨNG BLUR/DIM MỀM MẠI
    for (final node in nodes) {
      final pos = node.getActualPos(center, maxRadius);
      final isFocused = focusId == node.id;
      final isConnected = connectedIds != null && connectedIds.contains(node.id);
      final isOutside = focusId != null && !isFocused && !isConnected;

      final isSearched = searchQuery.isNotEmpty &&
          (node.id.toLowerCase().contains(searchQuery.toLowerCase()) ||
           node.title.toLowerCase().contains(searchQuery.toLowerCase()));

      // Độ mờ chuyển đổi mềm mại: các node bên ngoài không liên quan mờ dần nhẹ nhàng về 0.08
      final double opacity = isOutside ? lerpDouble(1.0, 0.08, t)! : 1.0;

      // A. Vòng hào quang cho Hub trung tâm chuẩn Obsidian
      if (node.isHub) {
        _nodeGlowPaint
          ..color = node.color.withOpacity(0.35 * opacity)
          ..strokeWidth = 1.6;
        canvas.drawCircle(pos, node.radius + 6.0, _nodeGlowPaint);
      }

      // B. Quầng sáng (Glow Shadow) khi Focus hoặc Connected
      if ((isFocused || isConnected || isSearched) && !isOutside) {
        final glowColor = isSearched
            ? const Color(0xFFFBBF24)
            : (isFocused ? const Color(0xFF8B5CF6) : node.color);
        final glowIntensity = isFocused ? (0.65 * t) : (0.35 * t);
        final strokeW = isFocused ? lerpDouble(2.0, 5.0, t)! : 3.0;

        _nodeGlowPaint
          ..color = glowColor.withOpacity(glowIntensity)
          ..strokeWidth = strokeW;
        canvas.drawCircle(pos, node.radius + (isFocused ? 3.5 : 2.0), _nodeGlowPaint);
      }

      // C. Vòng tròn node chính (màu sắc chuyển nhẹ khi hover)
      final baseColor = isSearched
          ? const Color(0xFFFBBF24)
          : (isFocused ? Color.lerp(node.color, const Color(0xFF8B5CF6), t)! : node.color);

      _nodeFillPaint.color = baseColor.withOpacity(opacity);
      canvas.drawCircle(pos, node.radius, _nodeFillPaint);

      // D. Viền trắng trang nhã quanh node
      _nodeBorderPaint
        ..color = (isFocused ? Colors.white : Colors.white70).withOpacity(opacity)
        ..strokeWidth = isFocused ? lerpDouble(1.5, 2.5, t)! : 1.4;
      canvas.drawCircle(pos, node.radius, _nodeBorderPaint);

      // E. Nhãn chữ hiển thị thanh thoát đúng chuẩn Obsidian
      final textColor = isFocused
          ? const Color(0xFF0F172A)
          : (isConnected
              ? const Color(0xFF1E293B)
              : (node.isTag ? const Color(0xFF16A34A) : const Color(0xFF4B5563)));

      final textSpan = TextSpan(
        text: node.id,
        style: TextStyle(
          fontSize: isFocused || isConnected
              ? 13.0
              : (node.isHub ? 12.0 : (node.isTag ? 10.5 : 11.5)),
          fontWeight: isFocused || isConnected ? FontWeight.w800 : FontWeight.w600,
          color: textColor.withOpacity(opacity),
          shadows: [
            Shadow(color: Colors.white.withOpacity(opacity * 0.9), blurRadius: 4),
            Shadow(color: Colors.white.withOpacity(opacity * 0.9), blurRadius: 2),
          ],
        ),
      );

      final tp = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy + node.radius + 3.5));
    }
  }

  @override
  bool shouldRepaint(covariant ObsidianPureGraphPainter oldDelegate) {
    return oldDelegate.searchQuery != searchQuery ||
        oldDelegate.showArrows != showArrows ||
        oldDelegate.selectedNodeId != selectedNodeId ||
        oldDelegate.activeFocusId != activeFocusId ||
        oldDelegate.center != center ||
        oldDelegate.maxRadius != maxRadius;
  }
}
