import 'dart:io';
import 'dart:ui' as ui;

import 'package:flm_courses/app/app_shell.dart';
import 'package:flm_courses/models/transcript_entry.dart';
import 'package:flm_courses/screens/transcript_confirm_screen.dart';
import 'package:flm_courses/state/course_catalog.dart';
import 'package:flm_courses/state/learning_profile_provider.dart';
import 'package:flm_courses/state/transcript_provider.dart';
import 'package:flm_courses/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const captureEvidence = bool.fromEnvironment('UX_EVIDENCE');

Future<void> loadEvidenceFont() async {
  // Use the same SDK font shipped with Flutter, without a machine-specific path.
  var directory = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 9; i++) {
    final font = File(
      '${directory.path}/artifacts/material_fonts/roboto-regular.ttf',
    );
    if (font.existsSync()) {
      final loader = FontLoader('Roboto');
      for (final name in ['regular', 'medium', 'bold']) {
        final bytes = File(
          '${directory.path}/artifacts/material_fonts/roboto-$name.ttf',
        ).readAsBytesSync();
        loader.addFont(Future.value(ByteData.sublistView(bytes)));
      }
      await loader.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              File(
                '${directory.path}/artifacts/material_fonts/materialicons-regular.otf',
              ).readAsBytesSync(),
            ),
          ),
        );
      await icons.load();
      return;
    }
    directory = directory.parent;
  }
  throw StateError('Cannot locate Flutter SDK Roboto for visual evidence.');
}

Future<void> capture(WidgetTester tester, String name) async {
  if (!captureEvidence) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('capture')),
    );
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('../evidence/ux/2026-10-27/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  for (final width in [360.0, 412.0]) {
    testWidgets(
      'journey and OCR review fit ${width.toInt()} dp with readable theme',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        if (captureEvidence) await tester.runAsync(loadEvidenceFont);
        SharedPreferences.setMockInitialValues({});
        final catalog = CourseCatalog();
        await tester.runAsync(catalog.load);
        final transcript = TranscriptProvider();
        await transcript.load();
        final profile = LearningProfileProvider();
        await profile.load();
        final courses = catalog.courses.take(3).toList();
        final rows = [
          for (var i = 0; i < courses.length; i++)
            TranscriptEntry(
              courseCode: courses[i].code,
              score: i == 0 ? 8 : 0,
              credits: courses[i].credits,
              semester: courses[i].semester,
              isPassed: i == 0,
              inProgress: i == 1,
            ),
        ];
        await transcript.save(rows);
        Widget app(Widget screen, {double scale = 1}) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: catalog),
            ChangeNotifierProvider.value(value: transcript),
            ChangeNotifierProvider.value(value: profile),
          ],
          child: RepaintBoundary(
            key: const Key('capture'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme(),
              home: screen,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
            ),
          ),
        );
        await tester.pumpWidget(app(const AppShell()));
        await tester.pumpAndSettle();
        expect(
          find.text('1/${catalog.courses.length} môn đã hoàn thành'),
          findsOneWidget,
        );
        expect(
          find.text('Còn lại: ${catalog.courses.length - 1}'),
          findsOneWidget,
        );
        expect(find.text('Đang học: 1'), findsOneWidget);
        expect(find.text('Cần học lại: 1'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await capture(tester, 'home-fixture-${width.toInt()}');

        await tester.pumpWidget(app(const AppShell(), scale: 1.3));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          app(
            TranscriptConfirmScreen(
              rawExtractedEntries: rows,
              onSaved: (_) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await capture(tester, 'confirm-fixture-${width.toInt()}');

        await transcript.save([]);
        await tester.pumpWidget(app(const AppShell()));
        await tester.pumpAndSettle();
        expect(find.text('Bắt đầu từ kết quả của bạn'), findsOneWidget);
        expect(
          find.text('0/${catalog.courses.length} môn đã hoàn thành'),
          findsNothing,
        );
        expect(find.text('0'), findsNothing);
        expect(tester.takeException(), isNull);
        await capture(tester, 'home-empty-${width.toInt()}');
      },
    );
  }
}
