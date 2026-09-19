import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import '../models/course_node.dart';
import '../widgets/course_summary_modal.dart';

class GraphViewScreen extends StatefulWidget {
  const GraphViewScreen({super.key});

  @override
  State<GraphViewScreen> createState() => _GraphViewScreenState();
}

class _GraphViewScreenState extends State<GraphViewScreen> {
  final Graph graph = Graph()..isTree = false;
  late Algorithm _algorithm;

  final Map<String, CourseNode> _courseMap = {
    'PRF192': CourseNode(id: 'PRF192', name: 'Programming Fundamentals', credits: 3, semester: 1),
    'PRO192': CourseNode(id: 'PRO192', name: 'Object-Oriented Programming', credits: 3, semester: 2, prerequisites: ['PRF192']),
    'CSD201': CourseNode(id: 'CSD201', name: 'Data Structures and Algorithms', credits: 3, semester: 3, prerequisites: ['PRO192']),
    'PRM392': CourseNode(id: 'PRM392', name: 'Mobile Programming', credits: 3, semester: 5, prerequisites: ['PRO192']),
    'SWD392': CourseNode(id: 'SWD392', name: 'Software Architecture and Design', credits: 3, semester: 6, prerequisites: ['CSD201']),
  };

  final Map<String, Node> _nodeMap = {};

  @override
  void initState() {
    super.initState();
    _buildGraphData();
    _algorithm = BuchheimWalkerAlgorithm(
      BuchheimWalkerConfiguration()
        ..orientation = BuchheimWalkerConfiguration.ORIENTATION_LEFT_RIGHT
        ..siblingSeparation = 40
        ..levelSeparation = 60
        ..subtreeSeparation = 40,
      TreeEdgeRenderer(BuchheimWalkerConfiguration()),
    );
  }

  void _buildGraphData() {
    _courseMap.forEach((id, course) {
      final node = Node.Id(id);
      _nodeMap[id] = node;
      graph.addNode(node);
    });

    _courseMap.forEach((id, course) {
      for (var preId in course.prerequisites) {
        if (_nodeMap.containsKey(preId) && _nodeMap.containsKey(id)) {
          graph.addEdge(_nodeMap[preId]!, _nodeMap[id]!);
        }
      }
    });
  }

  void _onNodeTapped(String courseId) {
    final course = _courseMap[courseId];
    if (course == null) return;

    CourseSummaryModal.show(
      context,
      course: course,
      onDetailsPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chuy?n t?i Chi ti?t môn: ${course.id}')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Obsidian Knowledge Graph'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: InteractiveViewer(
        constrained: false,
        boundaryMargin: const EdgeInsets.all(100),
        minScale: 0.1,
        maxScale: 3.0,
        child: GraphView(
          graph: graph,
          algorithm: _algorithm,
          paint: Paint()
            ..color = Colors.indigo.shade200
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke,
          builder: (Node node) {
            final courseId = node.key!.value as String;
            final course = _courseMap[courseId];

            return GestureDetector(
              onTap: () => _onNodeTapped(courseId),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.indigo, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.indigo.withOpacity(0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      courseId,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.indigo,
                      ),
                    ),
                    if (course != null)
                      Text(
                        '${course.credits} TC',
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}