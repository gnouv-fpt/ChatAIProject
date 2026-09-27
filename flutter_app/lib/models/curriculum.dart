class CurriculumSubjectEntry {
  final String code;
  final int semester;

  const CurriculumSubjectEntry({
    required this.code,
    required this.semester,
  });

  factory CurriculumSubjectEntry.fromJson(Map<String, dynamic> json) {
    return CurriculumSubjectEntry(
      code: (json['code'] as String? ?? '').trim().toUpperCase(),
      semester: (json['semester'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'semester': semester,
  };
}

class CurriculumHeader {
  final String id;
  final String name;
  final String nameVi;

  const CurriculumHeader({
    required this.id,
    required this.name,
    required this.nameVi,
  });

  factory CurriculumHeader.fromJson(Map<String, dynamic> json) {
    return CurriculumHeader(
      id: (json['id'] as String? ?? json['code'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      nameVi: (json['name_vi'] as String? ?? json['name'] as String? ?? '').trim(),
    );
  }
}

class PloItem {
  final String id;
  final int index;
  final String name;
  final String description;

  const PloItem({
    required this.id,
    required this.index,
    required this.name,
    required this.description,
  });

  factory PloItem.fromJson(Map<String, dynamic> json) {
    return PloItem(
      id: json['id'] as String? ?? '',
      index: (json['index'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }
}

class SemesterData {
  final int semester;
  final String title;
  final String color;
  final int totalCredits;
  final int courseCount;
  final List<String> courseCodes;
  final double? gpa; // Hook cho Khối E khi có điểm

  const SemesterData({
    required this.semester,
    required this.title,
    required this.color,
    required this.totalCredits,
    required this.courseCount,
    required this.courseCodes,
    this.gpa,
  });

  factory SemesterData.fromJson(Map<String, dynamic> json) {
    return SemesterData(
      semester: (json['semester'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? 'Học kỳ ${json['semester'] ?? 0}',
      color: json['color'] as String? ?? '#3B82F6',
      totalCredits: (json['total_credits'] as num?)?.toInt() ?? 0,
      courseCount: (json['course_count'] as num?)?.toInt() ?? 0,
      courseCodes: (json['course_codes'] as List<dynamic>?)
              ?.map((e) => e.toString().trim().toUpperCase())
              .toList() ??
          [],
      gpa: (json['gpa'] as num?)?.toDouble(),
    );
  }
}

class Curriculum {
  final String id;
  final String code;
  final String name;
  final String nameVi;
  final int totalCredits;
  final int totalSubjects;
  final String decisionNo;
  final String degreeLevel;
  final String institution;
  final String major;
  final List<CurriculumSubjectEntry> subjects;

  const Curriculum({
    required this.id,
    required this.code,
    required this.name,
    required this.nameVi,
    required this.totalCredits,
    required this.totalSubjects,
    required this.decisionNo,
    required this.degreeLevel,
    required this.institution,
    required this.major,
    required this.subjects,
  });

  factory Curriculum.fromJson(Map<String, dynamic> json) {
    final subList = <CurriculumSubjectEntry>[];
    if (json['subjects'] != null && json['subjects'] is List) {
      for (final item in json['subjects'] as List) {
        if (item is Map<String, dynamic>) {
          subList.add(CurriculumSubjectEntry.fromJson(item));
        }
      }
    }

    final id = (json['id'] as String? ?? json['code'] as String? ?? 'BIT_SE_K19B').trim();
    return Curriculum(
      id: id,
      code: (json['code'] as String? ?? id).trim(),
      name: (json['name'] as String? ?? 'Curriculum $id').trim(),
      nameVi: (json['name_vi'] as String? ?? json['name'] as String? ?? 'Chương trình đào tạo $id').trim(),
      totalCredits: (json['total_credits'] as num?)?.toInt() ?? (subList.isEmpty ? 145 : 0),
      totalSubjects: (json['total_subjects'] as num?)?.toInt() ?? subList.length,
      decisionNo: json['decision_no'] as String? ?? '1140/QĐ-ĐHFPT dated 09/11/2026',
      degreeLevel: json['degree_level'] as String? ?? 'Bachelor / Đại học chính quy',
      institution: json['institution'] as String? ?? 'FPT University (FPTU)',
      major: json['major'] as String? ?? 'Software Engineering (SE)',
      subjects: subList,
    );
  }

  int get semesterCount {
    if (subjects.isEmpty) return 10;
    final maxSem = subjects.map((s) => s.semester).reduce((a, b) => a > b ? a : b);
    return maxSem + 1;
  }
}
