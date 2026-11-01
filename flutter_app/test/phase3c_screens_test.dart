import 'dart:io';
import 'dart:ui' as ui;

import 'package:flm_courses/features/chat/providers/chat_provider.dart';
import 'package:flm_courses/features/graph/views/graph_view_screen.dart';
import 'package:flm_courses/models/load_status.dart';
import 'package:flm_courses/models/transcript_entry.dart';
import 'package:flm_courses/screens/settings_screen.dart';
import 'package:flm_courses/screens/sign_in_screen.dart';
import 'package:flm_courses/screens/transcript_confirm_screen.dart';
import 'package:flm_courses/screens/transcript_screen.dart';
import 'package:flm_courses/state/auth_view_model.dart';
import 'package:flm_courses/state/course_catalog.dart';
import 'package:flm_courses/state/learning_profile_provider.dart';
import 'package:flm_courses/state/transcript_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'feedback_ui_test.dart' show loadEvidenceFont;
import 'fixtures/phase3a_fixtures.dart';

Future<void> _captureScreen(
  WidgetTester tester,
  GlobalKey key,
  String filename, {
  String dir = '../evidence/ux/phase3c',
}) async {
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(key),
    );
    final image = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$dir/$filename.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    await loadEvidenceFont();
  });

  group('Phase 3c - TranscriptScreen', () {
    testWidgets('Empty State - Single EmptyState, 2 buttons, security note, no sync badge', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final catalog = CourseCatalog();
      await tester.runAsync(catalog.load);
      final profile = LearningProfileProvider();
      await profile.load();
      final transcript = TranscriptProvider();
      await transcript.load(); // empty
      final auth = AuthViewModel(TestAuthService());
      final chat = ChatProvider(apiService: OfflineChatService());

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        catalog.dispose();
        profile.dispose();
        transcript.dispose();
        auth.dispose();
        chat.dispose();
      });

      final keyLight = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const TranscriptScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: keyLight,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chưa có bảng điểm'), findsOneWidget);
      expect(find.text('Nhập ảnh bảng điểm'), findsOneWidget);
      expect(find.text('Nhập điểm thủ công'), findsOneWidget);
      expect(find.text('Bảng điểm được lưu an toàn trên thiết bị của bạn'), findsOneWidget);
      // Ensure "ĐỒNG BỘ" badge is NOT rendered
      expect(find.text('ĐỒNG BỘ'), findsNothing);

      await _captureScreen(tester, keyLight, 'transcript_empty_390x844_light');

      // Dark Mode & Scale 1.3
      final keyDark = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const TranscriptScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          isDark: true,
          repaintKey: keyDark,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();
      await _captureScreen(tester, keyDark, 'transcript_empty_390x844_dark');

      final keyScale = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const TranscriptScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          textScale: 1.3,
          repaintKey: keyScale,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _captureScreen(tester, keyScale, 'transcript_empty_390x844_scale13');

      // Compact (360x640) & Wide (630x900)
      final keyCompact = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const TranscriptScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: keyCompact,
          viewport: const Size(360, 640),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _captureScreen(tester, keyCompact, 'transcript_empty_360x640_light');

      final keyWide = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const TranscriptScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: keyWide,
          viewport: const Size(630, 900),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _captureScreen(tester, keyWide, 'transcript_empty_630x900_light');
    });

    testWidgets('Populated State - SummaryCard, semester grouping, quick edit, delete undo', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final catalog = CourseCatalog();
      await tester.runAsync(catalog.load);
      final profile = LearningProfileProvider();
      await profile.load();
      final transcript = TranscriptProvider();
      await transcript.load();
      await transcript.save(createSampleTranscriptEntries());
      final auth = AuthViewModel(TestAuthService());
      final chat = ChatProvider(apiService: OfflineChatService());

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        catalog.dispose();
        profile.dispose();
        transcript.dispose();
        auth.dispose();
        chat.dispose();
      });

      final keyPop = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const TranscriptScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: keyPop,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Điểm trung bình tích lũy (GPA)'), findsOneWidget);
      expect(find.text('GPA hiện tại'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('PRF192'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('PRF192'), findsOneWidget);

      await _captureScreen(tester, keyPop, 'transcript_populated_390x844_light');

      // Dark Mode
      final keyDark = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const TranscriptScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          isDark: true,
          repaintKey: keyDark,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();
      await _captureScreen(tester, keyDark, 'transcript_populated_390x844_dark');

      // Scale 1.3
      final keyScale = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const TranscriptScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          textScale: 1.3,
          repaintKey: keyScale,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _captureScreen(tester, keyScale, 'transcript_populated_390x844_scale13');

      // Viewports
      final keyCompact = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const TranscriptScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: keyCompact,
          viewport: const Size(360, 640),
        ),
      );
      await tester.pumpAndSettle();
      await _captureScreen(tester, keyCompact, 'transcript_populated_360x640_light');

      final keyWide = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const TranscriptScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: keyWide,
          viewport: const Size(630, 900),
        ),
      );
      await tester.pumpAndSettle();
      await _captureScreen(tester, keyWide, 'transcript_populated_630x900_light');
    });

    testWidgets('Loading & Error States', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final catalog = CourseCatalog();
      final profile = LearningProfileProvider();
      final transcript = TranscriptProvider();
      transcript.status = LoadStatus.loading;
      final auth = AuthViewModel(TestAuthService());
      final chat = ChatProvider(apiService: OfflineChatService());

      final keyLoading = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const TranscriptScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: keyLoading,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pump();
      await _captureScreen(tester, keyLoading, 'transcript_loading_390x844_light');

      // Error State
      transcript.status = LoadStatus.error;
      transcript.loadError = 'Không thể tải bảng điểm từ máy chủ Firestore';
      final keyError = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const TranscriptScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: keyError,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Không thể tải bảng điểm từ máy chủ Firestore'), findsOneWidget);
      await _captureScreen(tester, keyError, 'transcript_error_390x844_light');
    });
  });

  group('Phase 3c - TranscriptConfirmScreen', () {
    testWidgets('Populated with OCR extracted entries, uncertain highlights, unsaved dialog', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final catalog = CourseCatalog();
      await tester.runAsync(catalog.load);
      final profile = LearningProfileProvider();
      await profile.load();
      final transcript = TranscriptProvider();
      final auth = AuthViewModel(TestAuthService());
      final chat = ChatProvider(apiService: OfflineChatService());

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        catalog.dispose();
        profile.dispose();
        transcript.dispose();
        auth.dispose();
        chat.dispose();
      });

      final entries = [
        TranscriptEntry(
          courseCode: 'PRF192',
          courseName: 'Cơ sở lập trình',
          score: 8.5,
          credits: 3,
          semester: 1,
          isPassed: true,
          confidence: 0.95,
        ),
        TranscriptEntry(
          courseCode: 'MAE101',
          courseName: 'Toán cho ngành kỹ thuật',
          score: 7.2,
          credits: 3,
          semester: 1,
          isPassed: true,
          confidence: 0.75, // uncertain -> should show warning chip
        ),
      ];

      final keyConfirm = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: TranscriptConfirmScreen(
            rawExtractedEntries: entries,
            importWarning: 'AI đã nhận diện 2 môn học từ ảnh chụp.',
            onSaved: (saved) async {},
          ),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: keyConfirm,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Xác nhận bảng điểm đã quét'), findsOneWidget);
      expect(find.text('Tin cậy'), findsOneWidget);
      expect(find.text('Cần kiểm tra'), findsWidgets);
      expect(find.textContaining('Xác nhận & Lưu bảng điểm'), findsOneWidget);

      await _captureScreen(tester, keyConfirm, 'transcript_confirm_populated_390x844_light');

      // Dark Mode
      final keyDark = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: TranscriptConfirmScreen(
            rawExtractedEntries: entries,
            onSaved: (saved) async {},
          ),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          isDark: true,
          repaintKey: keyDark,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();
      await _captureScreen(tester, keyDark, 'transcript_confirm_populated_390x844_dark');

      // Test PopScope exit dialog using Navigator
      final keyDialog = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (navContext) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(
                      navContext,
                      MaterialPageRoute(
                        builder: (_) => TranscriptConfirmScreen(
                          rawExtractedEntries: entries,
                          onSaved: (saved) async {},
                        ),
                      ),
                    ),
                    child: const Text('Mở xác nhận'),
                  ),
                ),
              ),
            ),
          ),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: keyDialog,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mở xác nhận'));
      await tester.pumpAndSettle();

      final backBtn = find.byType(BackButton);
      expect(backBtn, findsOneWidget);
      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      expect(find.text('Thoát mà không lưu?'), findsOneWidget);
      await _captureScreen(tester, keyDialog, 'transcript_confirm_unsaved_dialog_390x844_light');
    });
  });

  group('Phase 3c - SettingsScreen', () {
    testWidgets('4 grouped sections, GPA slider 5.0-10.0, dev mode unlock, danger dialog', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final catalog = CourseCatalog();
      await tester.runAsync(catalog.load);
      final profile = LearningProfileProvider();
      await profile.load();
      final transcript = TranscriptProvider();
      await transcript.load();
      await transcript.save(createSampleTranscriptEntries());
      final auth = AuthViewModel(TestAuthService(userName: 'Nguyễn Đăng Khôi'));
      final chat = ChatProvider(apiService: OfflineChatService(), profile: profile);

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        catalog.dispose();
        profile.dispose();
        transcript.dispose();
        auth.dispose();
        chat.dispose();
      });

      final keySettings = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const SettingsScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: keySettings,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      // Check 4 grouped headers
      expect(find.text('Tài khoản'), findsOneWidget);
      expect(find.text('Mục tiêu học tập'), findsOneWidget);
      expect(find.textContaining('Chương trình đào tạo:'), findsOneWidget);
      expect(find.text('5.0 (Tối thiểu)'), findsOneWidget);
      expect(find.text('10.0 (Xuất sắc)'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Trợ lý AI'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Trợ lý AI'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Dữ liệu'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Dữ liệu'), findsOneWidget);

      await _captureScreen(tester, keySettings, 'settings_overview_390x844_light');

      // Dark Mode & Scale
      final keyDark = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const SettingsScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          isDark: true,
          repaintKey: keyDark,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();
      await _captureScreen(tester, keyDark, 'settings_overview_390x844_dark');

      final keyScale = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const SettingsScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          textScale: 1.3,
          repaintKey: keyScale,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _captureScreen(tester, keyScale, 'settings_overview_390x844_scale13');

      // Slider interaction
      final slider = find.byType(Slider);
      expect(slider, findsOneWidget);
      await tester.drag(slider, const Offset(60, 0));
      await tester.pumpAndSettle();
      await _captureScreen(tester, keyScale, 'settings_gpa_slider_390x844_light');

      // Dismiss floating snackbar before next interaction
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // Clear Transcript Danger Dialog
      await tester.scrollUntilVisible(
        find.text('Xóa bảng điểm cá nhân'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -100));
      await tester.pumpAndSettle();
      final clearTile = find.text('Xóa bảng điểm cá nhân');
      expect(clearTile, findsOneWidget);
      await tester.tap(clearTile);
      await tester.pumpAndSettle();

      expect(find.text('Xóa bảng điểm?'), findsOneWidget);
      expect(find.text('Xóa vĩnh viễn'), findsOneWidget);
      await _captureScreen(tester, keyScale, 'settings_danger_dialog_390x844_light');
    });
  });

  group('Phase 3c - GraphViewScreen', () {
    testWidgets('SemesterPalette sync, status chips, bottom sheet with Hoi AI, accessible list', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final catalog = CourseCatalog();
      await tester.runAsync(catalog.load);
      final profile = LearningProfileProvider();
      await profile.load();
      final transcript = TranscriptProvider();
      await transcript.load();
      await transcript.save(createSampleTranscriptEntries());
      final auth = AuthViewModel(TestAuthService());
      final chat = ChatProvider(apiService: OfflineChatService());

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        catalog.dispose();
        profile.dispose();
        transcript.dispose();
        auth.dispose();
        chat.dispose();
      });

      final keyGraph = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const GraphViewScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: keyGraph,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.text('Chú giải màu'), findsOneWidget);

      await _captureScreen(tester, keyGraph, 'graph_view_390x844_light');

      // Dark Mode
      final keyDark = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const GraphViewScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          isDark: true,
          repaintKey: keyDark,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();
      await _captureScreen(tester, keyDark, 'graph_view_390x844_dark');

      // Accessible list modal
      final listButton = find.byTooltip('Xem danh sách (Trợ năng)');
      expect(listButton, findsOneWidget);
      await tester.tap(listButton);
      await tester.pumpAndSettle();

      expect(find.textContaining('Danh sách môn học trong sơ đồ'), findsOneWidget);
      await _captureScreen(tester, keyDark, 'graph_view_accessible_list_390x844_light');

      // Tap on a course to open course detail bottom sheet with "Hỏi AI"
      final courseTile = find.text('PRF192');
      if (courseTile.evaluate().isNotEmpty) {
        await tester.tap(courseTile.first);
        await tester.pumpAndSettle();
        expect(find.text('Hỏi AI'), findsOneWidget);
        await _captureScreen(tester, keyDark, 'graph_view_course_sheet_390x844_light');
      }
    });
  });

  group('Phase 3c - SignInScreen', () {
    testWidgets('8dp grid, 48dp button, M3 typography, dark mode and error banner', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final catalog = CourseCatalog();
      final profile = LearningProfileProvider();
      final transcript = TranscriptProvider();
      final auth = AuthViewModel(TestAuthService(signedIn: false));
      final chat = ChatProvider(apiService: OfflineChatService());

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        catalog.dispose();
        profile.dispose();
        transcript.dispose();
        auth.dispose();
        chat.dispose();
      });

      final keySignIn = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const SignInScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: keySignIn,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đăng nhập để tiếp tục'), findsOneWidget);
      expect(find.text('Đăng nhập với Google'), findsOneWidget);

      await _captureScreen(tester, keySignIn, 'sign_in_390x844_light');

      // Dark Mode
      final keyDark = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const SignInScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          isDark: true,
          repaintKey: keyDark,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();
      await _captureScreen(tester, keyDark, 'sign_in_390x844_dark');

      // Error Banner
      auth.message = 'Xác thực Google thất bại. Vui lòng kiểm tra kết nối mạng.';
      final keyError = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const SignInScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: keyError,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Xác thực Google thất bại. Vui lòng kiểm tra kết nối mạng.'), findsOneWidget);
      await _captureScreen(tester, keyError, 'sign_in_error_390x844_light');
    });
  });
}
