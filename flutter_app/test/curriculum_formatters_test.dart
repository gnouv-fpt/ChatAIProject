import 'package:flm_courses/models/course.dart';
import 'package:flm_courses/models/curriculum.dart';
import 'package:flm_courses/state/course_catalog.dart';
import 'package:flm_courses/utils/curriculum_formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CurriculumFormatters & Consistency Tests', () {
    test('formatCurriculumCredits formats credits accurately', () {
      expect(formatCurriculumCredits(147), '147 tín chỉ');
      expect(formatCurriculumCredits(0), '0 tín chỉ');
    });

    test('formatCurriculumSemesters includes zero-semester explicitly', () {
      expect(formatCurriculumSemesters(10, startSemester: 0), '10 học kỳ (HK0–HK9)');
      expect(formatCurriculumSemesters(9, startSemester: 1), '9 học kỳ (HK1–HK9)');
      expect(formatCurriculumSemesters(0), '0 học kỳ');
    });

    test('capitalizeFirst uses Vietnamese sentence case instead of Title Case', () {
      expect(capitalizeFirst('lộ trình học tập'), 'Lộ trình học tập');
      expect(capitalizeFirst('hỏi về lộ trình học tập'), 'Hỏi về lộ trình học tập');
      expect(capitalizeFirst('bảng điểm cá nhân'), 'Bảng điểm cá nhân');
      expect(capitalizeFirst('  mục tiêu học tập  '), 'Mục tiêu học tập');
      expect(capitalizeFirst(''), '');
    });

    test('formatContextScopeLabel masks raw technical keys into friendly labels', () {
      expect(
        formatContextScopeLabel(scope: 'curriculum', scopeId: 'BIT_SE_K19B:roadmap', title: 'lộ trình'),
        'Phạm vi: Lộ trình học tập',
      );
      expect(
        formatContextScopeLabel(scope: 'curriculum', scopeId: 'BIT_SE_K19B:transcript', title: 'bảng điểm'),
        'Phạm vi: Bảng điểm cá nhân',
      );
      expect(
        formatContextScopeLabel(scope: 'curriculum', scopeId: 'BIT_SE_K19B:settings', title: 'cài đặt'),
        'Phạm vi: Mục tiêu học tập',
      );
      expect(
        formatContextScopeLabel(scope: 'curriculum', scopeId: 'BIT_SE_K19B:semester_3', semesterNumber: 3),
        'Phạm vi: Học kỳ 3',
      );
      expect(
        formatContextScopeLabel(scope: 'subject', scopeId: 'PRM393'),
        'Môn: PRM393',
      );
      expect(
        formatContextScopeLabel(scope: 'subject', scopeId: 'BIT_SE_K19B:PRM393'),
        'Môn: PRM393',
      );
    });

    test('CourseCatalog and Curriculum credits consistency check', () {
      final catalog = CourseCatalog();
      catalog.curriculum = Curriculum(
        id: 'BIT_SE_K19B',
        code: 'BIT_SE_K19B',
        name: 'Curriculum',
        nameVi: 'Chương trình KTPM',
        totalCredits: 147,
        totalSubjects: 48,
        decisionNo: '1140',
        degreeLevel: 'Bachelor',
        institution: 'FPTU',
        major: 'SE',
        subjects: [],
      );

      catalog.courses = const [
        Course(
          code: 'PRF192',
          codeOriginal: 'PRF192',
          name: 'C',
          credits: 3,
          semester: 1,
          learningOutcomes: [],
          prerequisites: [],
          unlocks: [],
        ),
        Course(
          code: 'PRO192',
          codeOriginal: 'PRO192',
          name: 'Java',
          credits: 3,
          semester: 2,
          learningOutcomes: [],
          prerequisites: [],
          unlocks: [],
        ),
      ];

      expect(catalog.totalCredits, 6);
      expect(formatCurriculumCredits(catalog.curriculum!.totalCredits), '147 tín chỉ');
    });
  });
}
