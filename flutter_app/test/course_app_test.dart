import 'package:flm_courses/main.dart';
import 'package:flm_courses/models/course.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Course.fromJson parses valid and fallback data correctly', () {
    final course = Course.fromJson({
      'code': 'PRM392',
      'name': 'Mobile Programming',
      'credits': 3,
      'semester': 6,
      'prerequisites': ['PRJ301'],
    });

    expect(course.code, equals('PRM392'));
    expect(course.name, equals('Mobile Programming'));
    expect(course.credits, equals(3));
    expect(course.semester, equals(6));
    expect(course.prerequisites, contains('PRJ301'));
  });

  testWidgets('Duyệt ứng dụng FLM và chuyển tab không cần server', (
    tester,
  ) async {
    await tester.pumpWidget(const FlmApp());
    await tester.pump(const Duration(milliseconds: 500));

    // Verify main AppShell renders with title
    expect(find.text('Danh sách Môn học FLM'), findsOneWidget);

    // Switch to Graph Tab (Sơ đồ)
    await tester.tap(find.text('Sơ đồ'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Sơ đồ Đồ thị Môn học (Obsidian Graph)'), findsOneWidget);

    // Switch to Chat Tab (Trợ lý AI)
    await tester.tap(find.text('Trợ lý AI'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Trợ lý AI FLM (RAG)'), findsOneWidget);

    // Switch back to Môn học tab
    await tester.tap(find.text('Môn học'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Danh sách Môn học FLM'), findsOneWidget);
  });
}
