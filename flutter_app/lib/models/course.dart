class Course {
  const Course({
    required this.code,
    required this.name,
    required this.credits,
    required this.semester,
    required this.learningOutcomes,
    required this.prerequisites,
  });

  final String code;
  final String name;
  final int credits;
  final int semester;
  final List<String> learningOutcomes;
  final List<String> prerequisites;

  factory Course.fromJson(Map<String, dynamic> json) {
    final code = (json['code'] as String).trim();
    final name = (json['name'] as String).trim();
    final credits = json['credits'] as int;
    final semester = json['semester'] as int;
    if (code.isEmpty || name.isEmpty || credits < 1 || semester < 1) {
      throw const FormatException('Dữ liệu môn học không hợp lệ.');
    }
    return Course(
      code: code,
      name: name,
      credits: credits,
      semester: semester,
      learningOutcomes: List<String>.from(json['learningOutcomes'] ?? const []),
      prerequisites: List<String>.from(json['prerequisites'] ?? const []),
    );
  }
}
