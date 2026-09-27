import 'package:flm_courses/main.dart';
import 'package:flm_courses/models/course.dart';
import 'package:flm_courses/models/curriculum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Course.fromJson parses schema v7 data correctly', () {
    final course = Course.fromJson({
      'code': 'PRM393',
      'code_original': 'PRM393',
      'name': 'Mobile Programming',
      'name_vi': 'Lập trình di động',
      'credits': 3,
      'semester': 8,
      'prerequisites': ['PRO192'],
      'has_pe': true,
      'has_pe_source': 'detailed_assessment_table:practical_exam',
      'counts_in_gpa': true,
      'appears_in': [
        {'curriculum': 'BIT_SE_K19B', 'semester': 8}
      ],
    });

    expect(course.code, equals('PRM393'));
    expect(course.name, equals('Mobile Programming'));
    expect(course.nameVi, equals('Lập trình di động'));
    expect(course.credits, equals(3));
    expect(course.semester, equals(8));
    expect(course.prerequisites, contains('PRO192'));
    expect(course.hasPe, isTrue);
    expect(course.countsInGpa, isTrue);
    expect(course.appearsIn.length, equals(1));
    expect(course.appearsIn.first.curriculum, equals('BIT_SE_K19B'));
    expect(course.appearsIn.first.semester, equals(8));
  });

  test('Curriculum.fromJson parses curriculum schema v7 correctly', () {
    final cur = Curriculum.fromJson({
      'id': 'BIT_SE_K19B',
      'code': 'BIT_SE_K19B',
      'name': 'The Bachelor Program of Information Technology, Software Engineering Major',
      'name_vi': 'Chương trình cử nhân ngành Công nghệ thông tin, chuyên ngành Kỹ thuật phần mềm',
      'total_credits': 145,
      'total_subjects': 48,
      'decision_no': '1140/QĐ-ĐHFPT dated 09/11/2026',
      'degree_level': 'Bachelor / Đại học chính quy',
      'institution': 'FPT University (FPTU)',
      'major': 'Software Engineering (SE)',
      'subjects': [
        {'code': 'PRM393', 'semester': 8},
        {'code': 'SWD392', 'semester': 7},
      ],
    });

    expect(cur.id, equals('BIT_SE_K19B'));
    expect(cur.totalCredits, equals(145));
    expect(cur.subjects.length, equals(2));
    expect(cur.semesterCount, equals(9)); // max sem 8 + 1
  });

  testWidgets('Khởi chạy ứng dụng FLM hiển thị Màn 1 CurriculumListPage', (
    tester,
  ) async {
    await tester.pumpWidget(const FlmApp());
    await tester.pump(const Duration(milliseconds: 500));

    // Verify Màn 1 Header is rendered
    expect(find.text('FLM Curriculum & Knowledge Base'), findsOneWidget);
  });
}
