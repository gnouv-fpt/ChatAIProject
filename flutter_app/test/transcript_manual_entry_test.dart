import 'package:flm_courses/models/transcript_entry.dart';
import 'package:flm_courses/screens/transcript_confirm_screen.dart';
import 'package:flm_courses/state/course_catalog.dart';
import 'package:flm_courses/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'long review warning scrolls and save stays reachable with large text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final catalog = CourseCatalog();
      await tester.runAsync(catalog.load);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: catalog,
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: TranscriptConfirmScreen(
              rawExtractedEntries: [
                TranscriptEntry(
                  courseCode: 'CEA201',
                  score: 8,
                  credits: 3,
                  semester: 1,
                  isPassed: true,
                ),
              ],
              importWarning: 'Kiểm tra lại mã môn, điểm và tín chỉ trước khi lưu. Nếu thông tin chưa khớp với bảng điểm gốc, hãy mở từng môn để sửa lại hoặc thêm môn còn thiếu.',
              onSaved: (_) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Lưu bảng điểm').hitTestable(), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byTooltip('Sửa môn học').hitTestable(),
        160,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Sửa môn học'));
      await tester.pumpAndSettle();
      expect(find.text('Áp dụng'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'missing OCR credits cannot silently change GPA and can use catalog credits',
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
                  courseCode: 'CEA201',
                  score: 8,
                  credits: 0,
                  semester: 1,
                  isPassed: true,
                ),
              ],
              onSaved: (entries) async => saved = entries,
            ),
          ),
        ),
      );
      await tester.runAsync(catalog.load);
      await tester.pump();
      expect(find.text('Kiểm tra tín chỉ'), findsOneWidget);
      await tester.tap(find.byTooltip('Lưu bảng điểm'));
      await tester.pump();
      expect(saved, isNull);
      await tester.tap(find.byTooltip('Sửa môn học'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Áp dụng'));
      await tester.pump(const Duration(milliseconds: 850));
      await tester.tap(find.byTooltip('Lưu bảng điểm'));
      await tester.pump();
      expect(saved!.single.credits, catalog.findByCode('CEA201')!.credits);
      expect(saved!.single.credits, greaterThan(0));
    },
  );
  testWidgets('scanned semester zero is valid and cards fit a phone screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final catalog = CourseCatalog();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: catalog,
        child: MaterialApp(
          home: TranscriptConfirmScreen(
            rawExtractedEntries: [
              TranscriptEntry(
                courseCode: 'OTP101',
                score: 6.9,
                credits: 0,
                semester: 0,
                isPassed: true,
                confidence: 0.65,
              ),
              TranscriptEntry(
                courseCode: 'CEA201',
                score: 7.2,
                credits: 3,
                semester: 1,
                isPassed: true,
              ),
            ],
            importWarning: 'Kiểm tra điểm và tín chỉ trước khi lưu.',
            onSaved: (_) async {},
          ),
        ),
      ),
    );
    await tester.runAsync(catalog.load);
    await tester.pump();
    expect(find.text('Mã chưa khớp'), findsNothing);
    expect(find.textContaining('Kỳ 0 • 0 tín chỉ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'deleting the last course confirms and persists empty transcript',
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
    },
  );

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
