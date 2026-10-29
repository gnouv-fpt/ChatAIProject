import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flm_courses/pages/curriculum_detail_page.dart';
import 'package:flm_courses/screens/settings_screen.dart';
import 'package:flm_courses/screens/sign_in_screen.dart';
import 'package:flm_courses/services/auth_service.dart';
import 'package:flm_courses/state/auth_view_model.dart';
import 'package:flm_courses/state/learning_profile_provider.dart';
import 'package:flm_courses/state/transcript_provider.dart';
import 'package:flm_courses/features/chat/providers/chat_provider.dart';
import 'package:flm_courses/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'curriculum_ux_test.dart' show fixtureCatalog;
import 'feedback_ui_test.dart' show loadEvidenceFont;
import 'settings_sign_out_test.dart' show OfflineChat;

const evidence = bool.fromEnvironment('FIGMA_SYNC_EVIDENCE');

class _Auth implements AuthService {
  @override
  Stream<AuthAccount?> get changes => Stream.value(
    const AuthAccount(uid: 'fixture', name: 'Tài khoản kiểm thử'),
  );
  @override
  Future<void> signIn() async =>
      throw const AuthFailure('Bạn đã hủy đăng nhập.');
  @override
  Future<void> signOut() async {}
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!evidence) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('figma-capture')),
    );
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('../evidence/ux/2026-10-29/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  for (final width in [360.0, 412.0, 1280.0]) {
    testWidgets('Figma auth and settings route work at $width dp, text 1.3x', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      if (evidence) await tester.runAsync(loadEvidenceFont);
      SharedPreferences.setMockInitialValues({});
      final auth = AuthViewModel(_Auth());
      final profile = LearningProfileProvider();
      final transcript = TranscriptProvider();
      await profile.load();
      await transcript.load();
      final chat = ChatProvider(apiService: OfflineChat(), profile: profile);
      final catalog = fixtureCatalog();
      addTearDown(auth.dispose);
      addTearDown(profile.dispose);
      addTearDown(transcript.dispose);
      addTearDown(chat.dispose);
      addTearDown(catalog.dispose);

      Widget app(Widget screen) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: profile),
          ChangeNotifierProvider.value(value: transcript),
          ChangeNotifierProvider.value(value: chat),
          ChangeNotifierProvider.value(value: catalog),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          debugShowCheckedModeBanner: false,
          routes: {
            '/curricula/TEST': (_) =>
                const CurriculumDetailPage(curriculumId: 'TEST'),
          },
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(1.3)),
            child: RepaintBoundary(
              key: const Key('figma-capture'),
              child: child!,
            ),
          ),
          home: screen,
        ),
      );

      await tester.pumpWidget(app(const SignInScreen()));
      await tester.pumpAndSettle();
      await _capture(tester, 'auth-${width.toInt()}');
      final login = find.widgetWithText(FilledButton, 'Đăng nhập với Google');
      expect(tester.getSize(login).height, greaterThanOrEqualTo(48));
      await tester.tap(login);
      await tester.pumpAndSettle();
      expect(find.text('Bạn đã hủy đăng nhập.'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Start a separate signed-in screen fixture after checking cancellation.
      auth.message = null;
      await tester.pumpWidget(app(const SettingsScreen()));
      await tester.pumpAndSettle();
      await _capture(tester, 'settings-${width.toInt()}');
      expect(find.text('Tài khoản kiểm thử'), findsOneWidget);
      expect(find.text('GPA mục tiêu: 8.0 / 10'), findsOneWidget);
      final program = find.text('Xem chương trình');
      await tester.scrollUntilVisible(
        program,
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(program);
      await tester.pumpAndSettle();
      expect(find.text('Chương trình học'), findsOneWidget);
      expect(find.text('TEST'), findsOneWidget);
      for (final label in ['Tổng quan', 'Danh sách môn', 'Sơ đồ môn học']) {
        expect(find.text(label).hitTestable(), findsOneWidget);
      }
      await _capture(tester, 'curriculum-${width.toInt()}');
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
