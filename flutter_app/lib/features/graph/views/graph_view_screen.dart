import 'dart:convert';
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
    required this.colorHex,
    required this.position,
  });

  final String id;
  final String label;
  final String title;
  final int semester;
  final int credits;
  final String colorHex;
  Offset position;
}

class GraphEdgeData {
  GraphEdgeData({
    required this.from,
    required this.to,
  });

  final String from;
  final String to;
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

      // Group nodes by semester for organized layout
      final semesterGroups = <int, List<Map<String, dynamic>>>{};
      for (final raw in rawNodes) {
        final nodeMap = raw as Map<String, dynamic>;
        final id = nodeMap['id'] as String;
        final course = coursesMap[id];
        final semester = course?.semester ?? 1;

        semesterGroups.putIfAbsent(semester, () => []).add(nodeMap);
      }

      final nodes = <GraphNodeData>[];
      const double colWidth = 240.0;
      const double rowHeight = 100.0;
      const double startX = 60.0;
      const double startY = 80.0;

      final sortedSemesters = semesterGroups.keys.toList()..sort();

      for (int col = 0; col < sortedSemesters.length; col++) {
        final sem = sortedSemesters[col];
        final group = semesterGroups[sem]!;
        final x = startX + col * colWidth;

        for (int row = 0; row < group.length; row++) {
          final nMap = group[row];
          final id = nMap['id'] as String;
          final course = coursesMap[id];
          final y = startY + row * rowHeight;

          nodes.add(
            GraphNodeData(
              id: id,
              label: nMap['label'] as String? ?? id,
              title: course?.name ?? (nMap['title'] as String? ?? id),
              semester: sem,
              credits: course?.credits ?? 3,
              colorHex: nMap['group'] as String? ?? 'general',
              position: Offset(x, y),
            ),
          );
        }
      }

      final edges = <GraphEdgeData>[];
      for (final raw in rawEdges) {
        final edgeMap = raw as Map<String, dynamic>;
        edges.add(
          GraphEdgeData(
            from: edgeMap['from'] as String,
            to: edgeMap['to'] as String,
          ),
        );
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      node.id,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
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
                        backgroundColor: Theme.of(context).colorScheme.primary,
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

  Color _getNodeColor(String group, bool isSelected, bool matchesSearch) {
    if (matchesSearch) return Colors.amber.shade700;
    if (isSelected) return Colors.deepPurple;
    switch (group) {
      case 'core':
        return const Color(0xFF1976D2);
      case 'specialized':
        return const Color(0xFF388E3C);
      case 'general':
        return const Color(0xFF7B1FA2);
      case 'capstone':
        return const Color(0xFFD32F2F);
      default:
        return const Color(0xFF0288D1);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm node môn học (VD: PRM392)...',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
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
          Expanded(
            child: InteractiveViewer(
              transformationController: _transformationController,
              constrained: false,
              boundaryMargin: const EdgeInsets.all(500),
              minScale: 0.2,
              maxScale: 2.5,
              child: SizedBox(
                width: 2500,
                height: 1800,
                child: CustomPaint(
                  painter: GraphPainter(
                    nodes: _nodes,
                    edges: _edges,
                    selectedNodeId: _selectedNodeId,
                    searchQuery: _searchQuery,
                  ),
                  child: Stack(
                    children: [
                      for (final node in _nodes) ...[
                        Positioned(
                          left: node.position.dx - 70,
                          top: node.position.dy - 25,
                          child: GestureDetector(
                            onTap: () => _showNodeModal(context, node),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 140,
                              height: 50,
                              decoration: BoxDecoration(
                                color: _getNodeColor(
                                  node.colorHex,
                                  node.id == _selectedNodeId,
                                  _searchQuery.isNotEmpty &&
                                      (node.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                                       node.title.toLowerCase().contains(_searchQuery.toLowerCase())),
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: (node.id == _selectedNodeId)
                                        ? Colors.purple.withOpacity(0.5)
                                        : Colors.black12,
                                    blurRadius: (node.id == _selectedNodeId) ? 12 : 4,
                                    spreadRadius: (node.id == _selectedNodeId) ? 2 : 0,
                                  )
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    node.id,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'HK ${node.semester} • ${node.credits}TC',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GraphPainter extends CustomPainter {
  GraphPainter({
    required this.nodes,
    required this.edges,
    required this.selectedNodeId,
    required this.searchQuery,
  });

  final List<GraphNodeData> nodes;
  final List<GraphEdgeData> edges;
  final String? selectedNodeId;
  final String searchQuery;

  @override
  void paint(Canvas canvas, Size size) {
    final nodeMap = <String, GraphNodeData>{};
    for (final n in nodes) {
      nodeMap[n.id] = n;
    }

    final paintNormal = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final paintHighlight = Paint()
      ..color = Colors.deepPurple
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    for (final edge in edges) {
      final fromNode = nodeMap[edge.from];
      final toNode = nodeMap[edge.to];
      if (fromNode == null || toNode == null) continue;

      final isHighlighted = selectedNodeId != null &&
          (edge.from == selectedNodeId || edge.to == selectedNodeId);

      final p = isHighlighted ? paintHighlight : paintNormal;

      final start = fromNode.position;
      final end = toNode.position;

      final controlPoint1 = Offset(start.dx + (end.dx - start.dx) / 2, start.dy);
      final controlPoint2 = Offset(start.dx + (end.dx - start.dx) / 2, end.dy);

      final path = Path()
        ..moveTo(start.dx + 70, start.dy)
        ..cubicTo(
          controlPoint1.dx,
          controlPoint1.dy,
          controlPoint2.dx,
          controlPoint2.dy,
          end.dx - 70,
          end.dy,
        );

      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) {
    return oldDelegate.selectedNodeId != selectedNodeId ||
        oldDelegate.searchQuery != searchQuery;
  }
}
