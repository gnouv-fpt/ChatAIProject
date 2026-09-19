class AssessmentItem {
  const AssessmentItem({
    required this.item,
    required this.weight,
    required this.minMark,
  });

  final String item;
  final String weight;
  final String minMark;

  factory AssessmentItem.fromJson(Map<String, dynamic> json) {
    return AssessmentItem(
      item: json['item'] as String? ?? json['type'] as String? ?? 'Thành phần đánh giá',
      weight: json['weight'] as String? ?? '${json['weight_percent'] ?? ''}%',
      minMark: json['min_mark'] as String? ?? '>0',
    );
  }
}

class Course {
  const Course({
    required this.code,
    required this.codeOriginal,
    required this.name,
    this.nameVi = '',
    required this.credits,
    required this.semester,
    required this.learningOutcomes,
    required this.prerequisites,
    required this.unlocks,
    this.prerequisiteRaw = '',
    this.syllabusUrl = '',
    this.assessmentScheme = const [],
    this.studentTasks = '',
    this.toolsSoftware = '',
    this.minPassMark = '',
    this.timeAllocation = '',
    this.teachingMethods = '',
    this.colorHex,
  });

  final String code;
  final String codeOriginal;
  final String name;
  final String nameVi;
  final int credits;
  final int semester;
  final List<String> learningOutcomes;
  final List<String> prerequisites;
  final List<String> unlocks;
  final String prerequisiteRaw;
  final String syllabusUrl;
  final List<AssessmentItem> assessmentScheme;
  final String studentTasks;
  final String toolsSoftware;
  final String minPassMark;
  final String timeAllocation;
  final String teachingMethods;
  final String? colorHex;

  factory Course.fromJson(Map<String, dynamic> json) {
    final code = (json['code'] as String? ?? '').trim();
    final codeOrig = (json['code_original'] as String? ?? code).trim();
    final nameEng = (json['name'] as String? ?? '').trim();
    final nameVi = (json['name_vi'] as String? ?? '').trim();
    final name = nameEng.isNotEmpty ? nameEng : (nameVi.isNotEmpty ? nameVi : code);
    final credits = (json['credits'] as num?)?.toInt() ?? 3;
    final semester = (json['semester'] as num?)?.toInt() ?? 1;
    final prereqRaw = json['prerequisite_raw'] as String? ?? '';
    final sylUrl = json['syllabus_url'] as String? ?? 'https://flm.fpt.edu.vn/';

    final los = <String>[];
    if (json['learningOutcomes'] != null && (json['learningOutcomes'] as List).isNotEmpty) {
      los.addAll(List<String>.from(json['learningOutcomes'] as List));
    } else if (json['learning_outcomes'] != null && (json['learning_outcomes'] as List).isNotEmpty) {
      los.addAll(List<String>.from(json['learning_outcomes'] as List));
    }

    if (los.isEmpty) {
      los.addAll([
        'Nắm vững kiến thức nền tảng và thực hành chuyên sâu môn $name ($code).',
        'Thành thạo các công cụ, kỹ năng chuyên ngành đề xuất cho Học kỳ $semester.',
        'Đạt các chuẩn đầu ra kiến thức và kỹ năng theo khung đào tạo FPT University (BIT_SE_K19B).'
      ]);
    }

    final prereqs = <String>[];
    if (json['prerequisites'] != null && json['prerequisites'] is List) {
      prereqs.addAll(List<String>.from(json['prerequisites'] as List));
    }

    final unlocks = <String>[];
    if (json['unlocks'] != null && json['unlocks'] is List) {
      unlocks.addAll(List<String>.from(json['unlocks'] as List));
    }

    final assessments = <AssessmentItem>[];
    if (json['assessment_scheme'] != null && json['assessment_scheme'] is List) {
      for (final a in (json['assessment_scheme'] as List)) {
        if (a is Map<String, dynamic>) {
          assessments.add(AssessmentItem.fromJson(a));
        }
      }
    }
    if (assessments.isEmpty) {
      assessments.addAll(const [
        AssessmentItem(item: 'Quiz & Assignments', weight: '20%', minMark: '>0'),
        AssessmentItem(item: 'Practical Exam (PE) / Progress Test', weight: '30%', minMark: '>0'),
        AssessmentItem(item: 'Final Exam (FE)', weight: '50%', minMark: '>= 4.0'),
      ]);
    }

    return Course(
      code: code,
      codeOriginal: codeOrig,
      name: name,
      nameVi: nameVi,
      credits: credits,
      semester: semester,
      learningOutcomes: los,
      prerequisites: prereqs,
      unlocks: unlocks,
      prerequisiteRaw: prereqRaw,
      syllabusUrl: sylUrl,
      assessmentScheme: assessments,
      studentTasks: json['student_tasks'] as String? ?? 'Tham gia 80%+ slot học, làm đầy đủ Lab/Assignment.',
      toolsSoftware: json['tools_software'] as String? ?? 'IDE/Compiler chuyên dụng, Git/GitHub, AI tools.',
      minPassMark: json['min_pass_mark'] as String? ?? '5.0 / 10 (FE >= 4.0)',
      timeAllocation: json['time_allocation'] as String? ?? '150h (45h Contact + 105h Self-study)',
      teachingMethods: json['teaching_methods'] as String? ?? 'In-class lecture, Lab practice, Project-based',
      colorHex: json['color'] as String?,
    );
  }
}
