import 'dart:io';
import 'dart:ui' as ui;

import 'package:flm_courses/app/app_shell.dart';
import 'package:flm_courses/features/chat/providers/chat_provider.dart';
import 'package:flm_courses/features/chat/views/widgets/contextual_chat_panel.dart';
import 'package:flm_courses/features/graph/views/graph_view_screen.dart';
import 'package:flm_courses/models/transcript_entry.dart';
import 'package:flm_courses/screens/sign_in_screen.dart';
import 'package:flm_courses/screens/transcript_confirm_screen.dart';
import 'package:flm_courses/services/auth_service.dart';
import 'package:flm_courses/services/grade_import_service.dart';
import 'package:flm_courses/services/transcript_image_picker.dart';
import 'package:flm_courses/state/auth_view_model.dart';
import 'package:flm_courses/state/course_catalog.dart';
import 'package:flm_courses/state/learning_profile_provider.dart';
import 'package:flm_courses/state/transcript_import_view_model.dart';
import 'package:flm_courses/state/transcript_provider.dart';
import 'package:flm_courses/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'feedback_ui_test.dart' show loadEvidenceFont;
import 'settings_sign_out_test.dart' show OfflineChat, SignedInService;

Future<void> _capture(WidgetTester tester, String filename) async {
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('capture-root')),
    );
    final image = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('../evidence/ux/after_phase1/$filename.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

class _MockPicker implements TranscriptImagePicker {
  @override
  Future<List<ImageFile>?> pick() async => null;
}

Widget _wrapWithProviders({
  required Widget child,
  required CourseCatalog catalog,
  required LearningProfileProvider profile,
  required TranscriptProvider transcript,
  required AuthViewModel auth,
  required ChatProvider chat,
  double width = 390,
  double height = 844,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: catalog),
      ChangeNotifierProvider.value(value: profile),
      ChangeNotifierProvider.value(value: transcript),
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider.value(value: chat),
      Provider<TranscriptImagePicker>(create: (_) => _MockPicker()),
      ChangeNotifierProvider(
        create: (context) => TranscriptImportViewModel(
          picker: context.read<TranscriptImagePicker>(),
          service: () => GradeImportService(baseUrl: chat.baseUrl),
        ),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme(),
      debugShowCheckedModeBanner: false,
      home: SizedBox(
        width: width,
        height: height,
        child: RepaintBoundary(
          key: const Key('capture-root'),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Capture before_phase1 baseline screens', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(loadEvidenceFont);

    SharedPreferences.setMockInitialValues({});
    final catalog = CourseCatalog();
    await tester.runAsync(catalog.load);
    final profile = LearningProfileProvider();
    await profile.load();
    final transcript = TranscriptProvider();
    await transcript.load();
    final auth = AuthViewModel(SignedInService());
    final chat = ChatProvider(
      apiService: OfflineChat(),
      profile: profile,
    );

    addTearDown(catalog.dispose);
    addTearDown(profile.dispose);
    addTearDown(transcript.dispose);
    addTearDown(auth.dispose);
    addTearDown(chat.dispose);

    // 1. Tab 1: Trang chủ (Home)
    await tester.pumpWidget(
      _wrapWithProviders(
        child: const AppShell(),
        catalog: catalog,
        profile: profile,
        transcript: transcript,
        auth: auth,
        chat: chat,
      ),
    );
    await tester.pumpAndSettle();
    await _capture(tester, '01_home');

    // 2. Tab 2: Lộ trình (Roadmap)
    await tester.tap(find.text('Lộ trình'));
    await tester.pumpAndSettle();
    await _capture(tester, '02_roadmap');

    // 3. Tab 3: Trợ lý AI (Chat)
    await tester.tap(find.text('Trợ lý'));
    await tester.pumpAndSettle();
    await _capture(tester, '03_chat');

    // 4. Tab 4: Bảng điểm (Transcript)
    await tester.tap(find.text('Bảng điểm'));
    await tester.pumpAndSettle();
    await _capture(tester, '04_transcript');

    // 5. Tab 5: Cài đặt (Settings)
    await tester.tap(find.text('Cài đặt'));
    await tester.pumpAndSettle();
    await _capture(tester, '05_settings');

    // 6. Sheet ngữ cảnh (Contextual chat sheet)
    await tester.pumpWidget(
      _wrapWithProviders(
        child: Scaffold(
          body: ContextualChatPanel(
            scope: 'curriculum',
            scopeId: catalog.curriculum?.id ?? 'BIT_SE_K19B',
            backendScopeId: catalog.curriculum?.id ?? 'BIT_SE_K19B',
            title: 'Chương trình đào tạo',
            contextHint: 'Ngữ cảnh BIT_SE_K19B',
            suggestedQuestions: const [
              'Tôi nên học gì tiếp theo?',
              'Tóm tắt tiến độ học tập.',
            ],
            onClose: () {},
          ),
        ),
        catalog: catalog,
        profile: profile,
        transcript: transcript,
        auth: auth,
        chat: chat,
      ),
    );
    await tester.pumpAndSettle();
    await _capture(tester, '06_contextual_chat_sheet');

    // 7. Màn Sơ đồ (Graph view screen)
    await tester.pumpWidget(
      _wrapWithProviders(
        child: Scaffold(
          appBar: AppBar(title: const Text('Sơ đồ môn học')),
          body: GraphViewScreen(onOpenDetail: (_) {}),
        ),
        catalog: catalog,
        profile: profile,
        transcript: transcript,
        auth: auth,
        chat: chat,
      ),
    );
    await tester.pumpAndSettle();
    await _capture(tester, '07_graph_view');

    // 8. Sign-in (Đăng nhập)
    final loggedOutAuth = AuthViewModel(const _LoggedOutAuth());
    addTearDown(loggedOutAuth.dispose);
    await tester.pumpWidget(
      _wrapWithProviders(
        child: const SignInScreen(),
        catalog: catalog,
        profile: profile,
        transcript: transcript,
        auth: loggedOutAuth,
        chat: chat,
      ),
    );
    await tester.pumpAndSettle();
    await _capture(tester, '08_sign_in');

    // 9. Xác nhận bảng điểm (Transcript confirm screen)
    final sampleRows = [
      TranscriptEntry(
        courseCode: 'PRF192',
        courseName: 'Cơ sở lập trình',
        score: 8.5,
        credits: 3,
        semester: 1,
        isPassed: true,
      ),
      TranscriptEntry(
        courseCode: 'MAE101',
        courseName: 'Toán cho ngành kỹ thuật',
        score: 7.0,
        credits: 3,
        semester: 1,
        isPassed: true,
      ),
      TranscriptEntry(
        courseCode: 'CEA201',
        courseName: 'Kiến trúc máy tính',
        score: 9.0,
        credits: 3,
        semester: 2,
        isPassed: true,
      ),
    ];
    await tester.pumpWidget(
      _wrapWithProviders(
        child: TranscriptConfirmScreen(
          rawExtractedEntries: sampleRows,
          onSaved: (_) async {},
        ),
        catalog: catalog,
        profile: profile,
        transcript: transcript,
        auth: auth,
        chat: chat,
      ),
    );
    await tester.pumpAndSettle();
    await _capture(tester, '09_transcript_confirm');
  });
}

class _LoggedOutAuth implements AuthService {
  const _LoggedOutAuth();
  @override
  Stream<AuthAccount?> get changes => Stream.value(null);
  @override
  Future<void> signIn() async {}
  @override
  Future<void> signOut() async {}
}
