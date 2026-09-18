import 'package:flm_courses/main.dart';
import 'package:flm_courses/models/course.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Dữ liệu môn học thiếu trường bắt buộc bị từ chối', () {
    expect(
      () => Course.fromJson({'code': 'X', 'name': 'Mẫu', 'credits': 3}),
      throwsA(isA<TypeError>()),
    );
  });

  testWidgets('Duyệt môn học cục bộ và mở chi tiết không cần server', (
    tester,
  ) async {
    await tester.pumpWidget(const FlmApp());
    await tester.pumpAndSettle();

    expect(find.text('DEMO101'), findsOneWidget);
    await tester.tap(find.text('Học kỳ 2'));
    await tester.pumpAndSettle();
    expect(find.text('DEMO101'), findsNothing);
    expect(find.text('DEMO201'), findsOneWidget);

    await tester.tap(find.text('DEMO201'));
    await tester.pumpAndSettle();
    expect(find.text('Môn học minh họa 3'), findsOneWidget);
    expect(find.text('Mục tiêu học tập (LOs)'), findsOneWidget);
    expect(find.text('Môn tiên quyết'), findsOneWidget);
    expect(find.text('DEMO102'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trợ lý AI'));
    await tester.pumpAndSettle();
    expect(
      find.text('Màn hình Chat AI sẽ được tích hợp tại đây.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Môn học'));
    await tester.pumpAndSettle();
    expect(find.text('DEMO201'), findsOneWidget);
  });
}
