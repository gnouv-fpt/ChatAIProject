import 'package:flm_courses/models/transcript_entry.dart';
import 'package:flm_courses/screens/transcript_confirm_screen.dart';
import 'package:flm_courses/state/course_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('deleting the last course confirms and persists empty transcript',
      (tester) async {
    final catalog = CourseCatalog();
    List<TranscriptEntry>? saved;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: catalog,
        child: MaterialApp(
          home: TranscriptConfirmScreen(
            rawExtractedEntries: [
              TranscriptEntry(
                courseCode: 'PRM393',
                courseName: 'Lập trình di động',
                score: 8.5,
                credits: 3,
                semester: 8,
                isPassed: true,
              ),
            ],
            manualEntry: true,
            onSaved: (entries) async => saved = entries,
          ),
        ),
      ),
    );
    await tester.runAsync(catalog.load);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    await tester.tap(find.byTooltip('Lưu bảng điểm'));
    await tester.pumpAndSettle();
    expect(find.text('Xóa toàn bộ bảng điểm?'), findsOneWidget);
    expect(saved, isNull);
    await tester.tap(find.text('Xóa bảng điểm'));
    await tester.pumpAndSettle();
    expect(saved, isEmpty);
  });

  testWidgets(
    'manual transcript entry validates course and saves catalog credits',
    (tester) async {
      final catalog = CourseCatalog();
      List<TranscriptEntry>? saved;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: catalog,
          child: MaterialApp(
            home: TranscriptConfirmScreen(
              rawExtractedEntries: const [],
              manualEntry: true,
              onSaved: (entries) async => saved = entries,
            ),
          ),
        ),
      );
      await tester.runAsync(catalog.load);
      await tester.pump();
      expect(catalog.findByCode('PRM393'), isNotNull);

      await tester.tap(find.text('Thêm môn thủ công'));
      await tester.pump(const Duration(milliseconds: 300));
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'UNKNOWN');
      await tester.enterText(fields.at(1), '8,5');
      await tester.enterText(fields.at(2), '8');
      await tester.tap(find.text('Áp dụng'));
      await tester.pump();
      expect(find.text('Mã môn không có trong chương trình'), findsOneWidget);

      await tester.enterText(fields.at(0), 'PRM393');
      await tester.tap(find.text('Áp dụng'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 550));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Lưu bảng điểm'));
      await tester.pump();

      expect(saved, isNotNull);
      expect(saved!.single.courseCode, 'PRM393');
      expect(saved!.single.score, 8.5);
      expect(saved!.single.credits, catalog.findByCode('PRM393')!.credits);
    },
  );
}
