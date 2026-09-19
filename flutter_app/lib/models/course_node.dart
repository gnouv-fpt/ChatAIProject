class CourseNode {
  final String id;
  final String name;
  final int credits;
  final int semester;
  final List<String> prerequisites;

  CourseNode({
    required this.id,
    required this.name,
    required this.credits,
    required this.semester,
    this.prerequisites = const [],
  });

  factory CourseNode.fromJson(Map<String, dynamic> json) {
    return CourseNode(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      credits: json['credits'] ?? 3,
      semester: json['semester'] ?? 1,
      prerequisites: List<String>.from(json['prerequisites'] ?? []),
    );
  }
}