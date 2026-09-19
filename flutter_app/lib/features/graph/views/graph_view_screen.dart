import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../models/course.dart';
import '../../../pages/course_detail_page.dart';
import '../../../state/course_catalog.dart';

class GraphNodeData {
  GraphNodeData({
    required this.id,
    required this.label,
    required this.title,
    required this.semester,
    required this.credits,
    required this.color,
    required this.position,
    required this.radius,
    this.isHub = false,
  });

  final String id;
  final String label;
  final String title;
  final int semester;
  final int credits;
  final Color color;
  Offset position;
  final double radius;
  final bool isHub;
}

class GraphEdgeData {
  GraphEdgeData({
    required this.from,
    required this.to,
    this.label = 'Môn tiên quyết',
  });

  final String from;
  final String to;
  final String label;
}

class GraphViewScreen extends StatefulWidget {
  const GraphViewScreen({super.key});

  @override
  State<GraphViewScreen> createState() => _GraphViewScreenState();
}

class _GraphViewScreenState extends State<GraphViewScreen> {
  final TransformationController _transformationController = TransformationController();
  List<GraphNodeData> _nodes = [];
  List<GraphEdgeData> _edges = [];
  bool _isLoading = true;
  String? _selectedNodeId;
  String _searchQuery = '';
  bool _showArrows = true;

  @override
  void initState() {
    super.initState();
    _loadGraphData();
  }

  Future<void> _loadGraphData() async {
    try {
      final rawJson = await rootBundle.loadString('assets/courses_data.json');
      final data = jsonDecode(rawJson) as Map<String, dynamic>;

      final graphData = data['graph'] as Map<String, dynamic>? ?? {};
      final rawNodes = graphData['nodes'] as List<dynamic>? ?? [];
      final rawEdges = graphData['edges'] as List<dynamic>? ?? [];

      final coursesMap = <String, Course>{};
      final catalog = context.read<CourseCatalog>();
      for (final c in catalog.courses) {
        coursesMap[c.code] = c;
      }

      final nodes = <GraphNodeData>[];
      final nodeMap = <String, GraphNodeData>{};

      // Organic Force/Semester Clustered Layout (Obsidian Graph view style)
      // Hub nodes placed in center, courses grouped in semester arcs/columns
      const double centerX = 1200.0;
      const double centerY = 800.0;

      // Add Hubs
      final hub1 = GraphNodeData(
        id: '_Curriculum_Overview',
        label: 'BIT_SE_K19B',
        title: 'Tổng quan chương trình đào tạo',
        semester: 0,
        credits: 145,
        color: const Color(0xFFEAB308),
        position: const Offset(centerX - 100, centerY),
        radius: 28,
        isHub: true,
      );
      final hub2 = GraphNodeData(
        id: '_Program_Learning_Outcomes',
        label: '13 PLOs',
        title: '13 Chuẩn đầu ra ngành',
        semester: 0,
        credits: 13,
        color: const Color(0xFFF59E0B),
        position: const Offset(centerX + 100, centerY),
        radius: 26,
        isHub: true,
      );
      nodes.add(hub1);
      nodes.add(hub2);
      nodeMap[hub1.id] = hub1;
      nodeMap[hub2.id] = hub2;

      // Semester layout radius
      final semesterGroups = <int, List<Map<String, dynamic>>>{};
      for (final raw in rawNodes) {
        final nodeMapRaw = raw as Map<String, dynamic>;
        final id = nodeMapRaw['id'] as String;
        if (id == '_Curriculum_Overview' || id == '_Program_Learning_Outcomes') continue;
        final course = coursesMap[id];
        final semester = course?.semester ?? (nodeMapRaw['semester'] as int? ?? 1);
        semesterGroups.putIfAbsent(semester, () => []).add(nodeMapRaw);
      }

      final sortedSemesters = semesterGroups.keys.toList()..sort();

      for (int i = 0; i < sortedSemesters.length; i++) {
        final sem = sortedSemesters[i];
        final group = semesterGroups[sem]!;
        final angleStep = (2 * pi) / (group.length == 0 ? 1 : group.length);
        final baseRadius = 260.0 + (sem * 130.0);

        for (int j = 0; j < group.length; j++) {
          final nMap = group[j];
          final id = nMap['id'] as String;
          final course = coursesMap[id];

          // Offset angle based on semester to create organic radial graph
          final angle = j * angleStep + (sem * 0.4);
          final x = centerX + baseRadius * cos(angle);
          final y = centerY + baseRadius * sin(angle);

          Color nodeColor = const Color(0xFF0284C7); // Default Core Blue
          double radius = 15;

          if (id.startsWith('PRN')) {
            nodeColor = const Color(0xFFEA580C); // .NET Track Orange
            radius = 17;
          } else if (id.startsWith('PRM')) {
            nodeColor = const Color(0xFF9333EA); // Mobile Track Purple
            radius = 17;
          } else if (id == 'SEP490' || id == 'SWP391') {
            nodeColor = const Color(0xFFDC2626); // Capstone Red
            radius = 18;
          } else if (id == 'PRO192' || id == 'PRF192' || id == 'CSD201' || id == 'DBI202' || id == 'LAB211') {
            nodeColor = const Color(0xFF0284C7); // Fundamental Blue
            radius = 16;
          } else if (sem == 0 || sem == 1) {
            nodeColor = const Color(0xFF64748B); // Slate
            radius = 13;
          }

          final nodeObj = GraphNodeData(
            id: id,
            label: id,
            title: course?.name ?? (nMap['title'] as String? ?? id),
            semester: sem,
            credits: course?.credits ?? (nMap['credits'] as int? ?? 3),
            color: nodeColor,
            position: Offset(x, y),
            radius: radius,
          );
          nodes.add(nodeObj);
          nodeMap[id] = nodeObj;
        }
      }

      final edges = <GraphEdgeData>[];
      for (final raw in rawEdges) {
        final edgeMap = raw as Map<String, dynamic>;
        final from = (edgeMap['from'] as String? ?? edgeMap['source'] as String? ?? '');
        final to = (edgeMap['to'] as String? ?? edgeMap['target'] as String? ?? '');
        if (from.isNotEmpty && to.isNotEmpty) {
          edges.add(GraphEdgeData(from: from, to: to));
        }
      }

      // Connect hub nodes to courses
      for (final n in nodes) {
        if (!n.isHub) {
          edges.add(GraphEdgeData(from: '_Curriculum_Overview', to: n.id));
        }
      }

      if (mounted) {
        setState(() {
          _nodes = nodes;
          _edges = edges;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Lỗi tải dữ liệu Graph: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showNodeModal(BuildContext context, GraphNodeData node) {
    setState(() {
      _selectedNodeId = node.id;
    });

    if (node.isHub) {
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (modalContext) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                node.title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
              ),
              const SizedBox(height: 12),
              Text(
                'Mã chương trình: BIT_SE_K19B\n'
                'Tổng số môn học: 48 môn | 145 tín chỉ\n'
                'Độ bao phủ: 13 Chuẩn đầu ra ngành (PLOs)',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade800, height: 1.4),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(modalContext),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
                child: const Text('Đóng'),
              ),
            ],
          ),
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) {
        final catalog = modalContext.read<CourseCatalog>();
        final course = catalog.findByCode(node.id);

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 20,
                spreadRadius: 2,
              )
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: node.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: node.color),
                    ),
                    child: Text(
                      node.id,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: node.color,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Chip(
                    avatar: const Icon(Icons.school, size: 16),
                    label: Text('Học kỳ ${node.semester}'),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    avatar: const Icon(Icons.stars, size: 16),
                    label: Text('${node.credits} Tín chỉ'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                node.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              if (course?.nameVi != null && course!.nameVi.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  course.nameVi,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (course != null && course.prerequisites.isNotEmpty) ...[
                const Text(
                  'Môn tiên quyết:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: course.prerequisites
                      .map((p) => Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(p, style: const TextStyle(fontSize: 12)),
                            backgroundColor: Colors.blue.shade50,
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(modalContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Đóng'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(modalContext);
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => CourseDetailPage(code: node.id),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: node.color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text(
                        'Xem chi tiết',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() {
          _selectedNodeId = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Main Graph Canvas View (InteractiveViewer for Zoom & Pan)
          InteractiveViewer(
            transformationController: _transformationController,
            constrained: false,
            boundaryMargin: const EdgeInsets.all(800),
            minScale: 0.1,
            maxScale: 3.0,
            child: SizedBox(
              width: 2600,
              height: 1800,
              child: CustomPaint(
                painter: ObsidianGraphPainter(
                  nodes: _nodes,
                  edges: _edges,
                  selectedNodeId: _selectedNodeId,
                  searchQuery: _searchQuery,
                  showArrows: _showArrows,
                ),
                child: Stack(
                  children: [
                    for (final node in _nodes) ...[
                      Positioned(
                        left: node.position.dx - node.radius,
                        top: node.position.dy - node.radius,
                        child: GestureDetector(
                          onTap: () => _showNodeModal(context, node),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Circular Node (Matching Obsidian Graph View Circles)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: node.radius * 2,
                                height: node.radius * 2,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: (_searchQuery.isNotEmpty &&
                                          (node.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                                           node.title.toLowerCase().contains(_searchQuery.toLowerCase())))
                                      ? Colors.amber.shade400
                                      : (node.id == _selectedNodeId ? Colors.purpleAccent : node.color),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (node.id == _selectedNodeId)
                                          ? Colors.purple.withOpacity(0.6)
                                          : node.color.withOpacity(0.3),
                                      blurRadius: (node.id == _selectedNodeId) ? 14 : 6,
                                      spreadRadius: (node.id == _selectedNodeId) ? 3 : 1,
                                    )
                                  ],
                                  border: Border.all(
                                    color: node.id == _selectedNodeId ? Colors.white : Colors.white70,
                                    width: 2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Node Text Label underneath circle
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
                                ),
                                child: Text(
                                  node.id,
                                  style: TextStyle(
                                    fontSize: node.isHub ? 12 : 11,
                                    fontWeight: node.isHub ? FontWeight.bold : FontWeight.w600,
                                    color: node.isHub ? const Color(0xFFD97706) : const Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Top Bar Search & Reset View
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm node môn học trên Obsidian Graph (VD: PRM393, PRO192)...',
                        prefixIcon: const Icon(Icons.search, color: Colors.indigo),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.center_focus_strong),
                    tooltip: 'Reset xem toàn cảnh',
                    onPressed: () {
                      _transformationController.value = Matrix4.identity();
                    },
                  ),
                ],
              ),
            ),
          ),

          // Obsidian Graph Group Filter Panel (Floating Overlay like Obsidian Screenshot 5)
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              width: 240,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.hub, size: 18, color: Colors.indigo),
                      SizedBox(width: 6),
                      Text(
                        'Obsidian Graph Groups',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const Divider(height: 12),
                  _buildLegendItem(const Color(0xFFEAB308), 'Curriculum & PLOs Hubs'),
                  _buildLegendItem(const Color(0xFFEA580C), '.NET Track (PRN212, PRN222)'),
                  _buildLegendItem(const Color(0xFF9333EA), 'Mobile Track (PRM393)'),
                  _buildLegendItem(const Color(0xFFDC2626), 'Capstone (SEP490, SWP391)'),
                  _buildLegendItem(const Color(0xFF0284C7), 'Core & Prerequisites'),
                  _buildLegendItem(const Color(0xFF64748B), 'General Courses'),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Mũi tên (Arrows):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      Switch(
                        value: _showArrows,
                        activeColor: Colors.indigo,
                        onChanged: (val) {
                          setState(() {
                            _showArrows = val;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 11.5, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class ObsidianGraphPainter extends CustomPainter {
  ObsidianGraphPainter({
    required this.nodes,
    required this.edges,
    required this.selectedNodeId,
    required this.searchQuery,
    required this.showArrows,
  });

  final List<GraphNodeData> nodes;
  final List<GraphEdgeData> edges;
  final String? selectedNodeId;
  final String searchQuery;
  final bool showArrows;

  @override
  void paint(Canvas canvas, Size size) {
    final nodeMap = <String, GraphNodeData>{};
    for (final n in nodes) {
      nodeMap[n.id] = n;
    }

    final paintNormal = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final paintHubEdge = Paint()
      ..color = Colors.amber.shade200.withOpacity(0.5)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final paintHighlight = Paint()
      ..color = Colors.deepPurple
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke;

    final arrowPaint = Paint()
      ..color = Colors.grey.shade500
      ..style = PaintingStyle.fill;

    final arrowHighlightPaint = Paint()
      ..color = Colors.deepPurple
      ..style = PaintingStyle.fill;

    for (final edge in edges) {
      final fromNode = nodeMap[edge.from];
      final toNode = nodeMap[edge.to];
      if (fromNode == null || toNode == null) continue;

      final isHighlighted = selectedNodeId != null &&
          (edge.from == selectedNodeId || edge.to == selectedNodeId);

      final isHubConnection = fromNode.isHub || toNode.isHub;

      final p = isHighlighted
          ? paintHighlight
          : (isHubConnection ? paintHubEdge : paintNormal);

      final start = fromNode.position;
      final end = toNode.position;

      // Draw edge line
      canvas.drawLine(start, end, p);

      // Draw Arrowhead if enabled (Obsidian Graph Directed Arrows)
      if (showArrows && !isHubConnection) {
        final double angle = atan2(end.dy - start.dy, end.dx - start.dx);
        final double arrowRadius = toNode.radius + 4;
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

        canvas.drawPath(path, isHighlighted ? arrowHighlightPaint : arrowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ObsidianGraphPainter oldDelegate) {
    return oldDelegate.selectedNodeId != selectedNodeId ||
        oldDelegate.searchQuery != searchQuery ||
        oldDelegate.showArrows != showArrows;
  }
}
