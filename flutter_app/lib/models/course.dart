class Course {
  const Course({
    required this.code,
    required this.name,
    this.nameVi = '',
    required this.credits,
    required this.semester,
    required this.learningOutcomes,
    required this.prerequisites,
    this.colorHex,
  });

  final String code;
  final String name;
  final String nameVi;
  final int credits;
  final int semester;
  final List<String> learningOutcomes;
  final List<String> prerequisites;
  final String? colorHex;

  factory Course.fromJson(Map<String, dynamic> json) {
    final code = (json['code'] as String? ?? '').trim();
    final nameEng = (json['name'] as String? ?? '').trim();
    final nameVi = (json['name_vi'] as String? ?? '').trim();
    final name = nameEng.isNotEmpty ? nameEng : (nameVi.isNotEmpty ? nameVi : code);
    final credits = (json['credits'] as num?)?.toInt() ?? 3;
    final semester = (json['semester'] as num?)?.toInt() ?? 1;

    final los = <String>[];
    if (json['learningOutcomes'] != null) {
      los.addAll(List<String>.from(json['learningOutcomes'] as List));
    } else if (json['syllabus_details'] != null && json['syllabus_details'] is Map) {
      final sd = json['syllabus_details'] as Map<String, dynamic>;
      if (sd['assessment_items'] != null && sd['assessment_items'] is List) {
        for (final item in (sd['assessment_items'] as List)) {
          if (item is Map && item['type'] != null) {
            los.add('${item['type']}: ${item['weight'] ?? ''}% - ${item['name'] ?? ''}');
          }
        }
      }
    }

    final prereqs = <String>[];
    if (json['prerequisites'] != null && json['prerequisites'] is List) {
      prereqs.addAll(List<String>.from(json['prerequisites'] as List));
    }

    return Course(
      code: code,
      name: name,
      nameVi: nameVi,
      credits: credits,
      semester: semester,
      learningOutcomes: los,
      prerequisites: prereqs,
      colorHex: json['color'] as String?,
    );
  }
}
