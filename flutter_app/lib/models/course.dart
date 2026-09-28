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

class CourseAppearsIn {
  final String curriculum;
  final int semester;

  const CourseAppearsIn({
    required this.curriculum,
    required this.semester,
  });

  factory CourseAppearsIn.fromJson(Map<String, dynamic> json) {
    return CourseAppearsIn(
      curriculum: (json['curriculum'] as String? ?? json['id'] as String? ?? '').trim(),
      semester: (json['semester'] as num?)?.toInt() ?? 1,
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
    this.hasPe = false,
    this.hasPeSource = '',
    this.countsInGpa = true,
    this.appearsIn = const [],
    this.inCurriculum = true,
    this.prerequisitesNorm = const [],
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
  final bool hasPe;
  final String hasPeSource;
  final bool countsInGpa;
  final List<CourseAppearsIn> appearsIn;
  final bool inCurriculum;
  final List<String> prerequisitesNorm;

  factory Course.fromJson(Map<String, dynamic> json) {
    final code = (json['code'] as String? ?? '').trim().toUpperCase();
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
      los.add('Chưa có dữ liệu chuẩn đầu ra cho môn $code.');
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
      assessments.add(const AssessmentItem(
        item: 'Chưa có dữ liệu đánh giá',
        weight: '',
        minMark: '',
      ));
    }

    final appears = <CourseAppearsIn>[];
    if (json['appears_in'] != null && json['appears_in'] is List) {
      for (final ap in json['appears_in'] as List) {
        if (ap is Map<String, dynamic>) {
          appears.add(CourseAppearsIn.fromJson(ap));
        }
      }
    }

    final prereqsNorm = <String>[];
    if (json['prerequisites_norm'] != null && json['prerequisites_norm'] is List) {
      prereqsNorm.addAll(List<String>.from(json['prerequisites_norm'] as List));
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
      hasPe: json['has_pe'] == true,
      hasPeSource: json['has_pe_source'] as String? ?? '',
      countsInGpa: json['counts_in_gpa'] != false,
      appearsIn: appears,
      inCurriculum: json['in_curriculum'] != false,
      prerequisitesNorm: prereqsNorm,
    );
  }
}
