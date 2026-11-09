import 'dart:io';
import 'dart:ui' as ui;

import 'package:flm_courses/app/app_shell.dart' as flm_app;
import 'package:flm_courses/features/chat/providers/chat_provider.dart';
import 'package:flm_courses/models/load_status.dart';
import 'package:flm_courses/screens/home_screen.dart';
import 'package:flm_courses/screens/roadmap_screen.dart';
import 'package:flm_courses/state/auth_view_model.dart';
import 'package:flm_courses/state/course_catalog.dart';
import 'package:flm_courses/state/learning_profile_provider.dart';
import 'package:flm_courses/state/transcript_provider.dart';
import 'package:flm_courses/widgets/m3_components.dart';
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
  String dir = '../evidence/ux/phase3a',
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

  group('Phase 3a - HomeScreen', () {
    testWidgets('Empty State - 1 CTA, user greeting, no duplicate navigation', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final catalog = CourseCatalog();
      await tester.runAsync(catalog.load);
      final profile = LearningProfileProvider();
      await profile.load();
      final transcript = TranscriptProvider();
      await transcript.load(); // empty
      final auth = AuthViewModel(TestAuthService(userName: 'Nguyễn Đăng Khôi'));
      final chat = ChatProvider(apiService: OfflineChatService(), profile: profile);

      addTearDown(() {
        catalog.dispose();
        profile.dispose();
        transcript.dispose();
        auth.dispose();
        chat.dispose();
      });

      final key = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: HomeScreen(onNavigate: (_) {}),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: key,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      // Assertions
      expect(find.text('Cố vấn học tập FLM'), findsOneWidget);
      expect(find.text('Cử nhân CNTT · Kỹ thuật phần mềm'), findsOneWidget);
      expect(find.text('3 bước bắt đầu'), findsOneWidget);
      expect(find.text('1. Nhập bảng điểm'), findsOneWidget);
      // Exactly ONE primary CTA 'Nhập bảng điểm ngay'
      expect(find.text('Nhập bảng điểm ngay'), findsOneWidget);
      // No duplicate navigation icons for tabs
      expect(find.text('Môn ưu tiên kỳ tới'), findsNothing);

      await _captureScreen(tester, key, 'home_empty_390x844_light');
    });

    testWidgets('Empty State - Dark Mode & Scale 1.3', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final catalog = CourseCatalog();
      await tester.runAsync(catalog.load);
      final profile = LearningProfileProvider();
      await profile.load();
      final transcript = TranscriptProvider();
      await transcript.load();
      final auth = AuthViewModel(TestAuthService(userName: 'Nguyễn Đăng Khôi'));
      final chat = ChatProvider(apiService: OfflineChatService(), profile: profile);

      addTearDown(() {
        catalog.dispose();
        profile.dispose();
        transcript.dispose();
        auth.dispose();
        chat.dispose();
      });

      final keyDark = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: HomeScreen(onNavigate: (_) {}),
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
      await _captureScreen(tester, keyDark, 'home_empty_390x844_dark');

      final keyScale = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: HomeScreen(onNavigate: (_) {}),
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
      await _captureScreen(tester, keyScale, 'home_empty_390x844_scale13');
    });

    testWidgets('Populated State - metrics, priority next courses, no overflow', (tester) async {
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

      addTearDown(() {
        catalog.dispose();
        profile.dispose();
        transcript.dispose();
        auth.dispose();
        chat.dispose();
      });

      final key = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: HomeScreen(onNavigate: (_) {}),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: key,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      // Assertions
      expect(find.text('Cố vấn học tập FLM'), findsOneWidget);
      expect(find.text('Cử nhân CNTT · Kỹ thuật phần mềm'), findsOneWidget);
      expect(find.text('Xem gợi ý môn kỳ tới'), findsOneWidget);
      expect(find.text('Môn ưu tiên kỳ tới'), findsOneWidget);
      expect(find.text('Nhập bảng điểm'), findsNothing);

      // Scroll to view advising goals
      await tester.scrollUntilVisible(find.text('Mục tiêu học tập'), 100);
      expect(find.text('Mục tiêu học tập'), findsOneWidget);

      await _captureScreen(tester, key, 'home_populated_390x844_light');
    });

    testWidgets('Populated State - Dark Mode & Scale 1.3', (tester) async {
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

      addTearDown(() {
        catalog.dispose();
        profile.dispose();
        transcript.dispose();
        auth.dispose();
        chat.dispose();
      });

      final keyDark = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: HomeScreen(onNavigate: (_) {}),
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
      await _captureScreen(tester, keyDark, 'home_populated_390x844_dark');

      final keyScale = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: HomeScreen(onNavigate: (_) {}),
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
      await _captureScreen(tester, keyScale, 'home_populated_390x844_scale13');
    });

    testWidgets('Populated State - Compact & Wide Viewports', (tester) async {
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

      addTearDown(() {
        catalog.dispose();
        profile.dispose();
        transcript.dispose();
        auth.dispose();
        chat.dispose();
      });

      // 360x640
      final key360 = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: HomeScreen(onNavigate: (_) {}),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: key360,
          viewport: const Size(360, 640),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _captureScreen(tester, key360, 'home_populated_360x640_light');

      // 630x900
      final key630 = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: HomeScreen(onNavigate: (_) {}),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: key630,
          viewport: const Size(630, 900),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _captureScreen(tester, key630, 'home_populated_630x900_light');
    });

    testWidgets('Compact Viewport (360x640) & Wide Viewport (630x900) Empty State', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final catalog = CourseCatalog();
      await tester.runAsync(catalog.load);
      final profile = LearningProfileProvider();
      await profile.load();
      final transcript = TranscriptProvider();
      await transcript.load();
      final auth = AuthViewModel(TestAuthService(userName: 'Nguyễn Đăng Khôi'));
      final chat = ChatProvider(apiService: OfflineChatService(), profile: profile);

      addTearDown(() {
        catalog.dispose();
        profile.dispose();
        transcript.dispose();
        auth.dispose();
        chat.dispose();
      });

      // 360x640
      final key360 = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: HomeScreen(onNavigate: (_) {}),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: key360,
          viewport: const Size(360, 640),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _captureScreen(tester, key360, 'home_empty_360x640_light');

      // 630x900
      final key630 = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: HomeScreen(onNavigate: (_) {}),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: key630,
          viewport: const Size(630, 900),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _captureScreen(tester, key630, 'home_empty_630x900_light');
    });

    testWidgets('Loading State - Skeleton', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final catalog = CourseCatalog();
      catalog.isLoading = true;
      catalog.courses = const [];
      final profile = LearningProfileProvider();
      final transcript = TranscriptProvider();
      final auth = AuthViewModel(TestAuthService());
      final chat = ChatProvider(apiService: OfflineChatService());

      addTearDown(() {
        catalog.dispose();
        profile.dispose();
        transcript.dispose();
        auth.dispose();
        chat.dispose();
      });

      final key = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: HomeScreen(onNavigate: (_) {}),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: key,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SkeletonCard), findsWidgets);
      await _captureScreen(tester, key, 'home_loading_390x844_light');
    });

    testWidgets('Error State - EmptyState with retry', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final catalog = CourseCatalog();
      catalog.isLoading = false;
      catalog.error = 'Không thể kết nối đến máy chủ FLM.';
      catalog.courses = const [];
      final profile = LearningProfileProvider();
      final transcript = TranscriptProvider();
      final auth = AuthViewModel(TestAuthService());
      final chat = ChatProvider(apiService: OfflineChatService());

      addTearDown(() {
        catalog.dispose();
        profile.dispose();
        transcript.dispose();
        auth.dispose();
        chat.dispose();
      });

      final key = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: HomeScreen(onNavigate: (_) {}),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: key,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Không thể tải dữ liệu môn học'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
      await _captureScreen(tester, key, 'home_error_390x844_light');
    });

    testWidgets('Offline State - InlineBanner warning', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final catalog = CourseCatalog();
      await tester.runAsync(catalog.load);
      final profile = LearningProfileProvider();
      await profile.load();
      final transcript = TranscriptProvider();
      transcript.status = LoadStatus.error;
      transcript.loadError = 'Không thể kết nối đồng bộ đám mây. Đang dùng dữ liệu ngoại tuyến.';
      final auth = AuthViewModel(TestAuthService());
      final chat = ChatProvider(apiService: OfflineChatService());

      addTearDown(() {
        catalog.dispose();
        profile.dispose();
        transcript.dispose();
        auth.dispose();
        chat.dispose();
      });

      final key = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: HomeScreen(onNavigate: (_) {}),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: key,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(InlineBanner), findsOneWidget);
      expect(find.text('Không thể kết nối đồng bộ đám mây. Đang dùng dữ liệu ngoại tuyến.'), findsOneWidget);
      await _captureScreen(tester, key, 'home_offline_390x844_light');
    });
  });

  group('Phase 3a - RoadmapScreen', () {
    testWidgets('Empty State (No Transcript) - NO "Chưa xác nhận điều kiện" on course tiles', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final catalog = CourseCatalog();
      await tester.runAsync(catalog.load);
      final profile = LearningProfileProvider();
      await profile.load();
      final transcript = TranscriptProvider();
      await transcript.load(); // empty
      final auth = AuthViewModel(TestAuthService());
      final chat = ChatProvider(apiService: OfflineChatService());

      addTearDown(() {
        catalog.dispose();
        profile.dispose();
        transcript.dispose();
        auth.dispose();
        chat.dispose();
      });

      final key = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const RoadmapScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: key,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      // Top summary card removed in Phase 3d to ensure above-the-fold visibility
      expect(find.text('Chương trình đào tạo'), findsNothing);
      expect(find.textContaining('Chưa có bảng điểm'), findsOneWidget);

      // CRITICAL UX REQUIREMENT: No "Chưa xác nhận điều kiện" badge on any course tile
      expect(find.textContaining('Chưa xác nhận điều kiện'), findsNothing);

      await _captureScreen(tester, key, 'roadmap_empty_390x844_light');
    });

    testWidgets('Empty State - Dark Mode & Scale 1.3', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final catalog = CourseCatalog();
      await tester.runAsync(catalog.load);
      final profile = LearningProfileProvider();
      await profile.load();
      final transcript = TranscriptProvider();
      await transcript.load();
      final auth = AuthViewModel(TestAuthService());
      final chat = ChatProvider(apiService: OfflineChatService());

      addTearDown(() {
        catalog.dispose();
        profile.dispose();
        transcript.dispose();
        auth.dispose();
        chat.dispose();
      });

      final keyDark = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const RoadmapScreen(),
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
      await _captureScreen(tester, keyDark, 'roadmap_empty_390x844_dark');

      final keyScale = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const RoadmapScreen(),
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
      await _captureScreen(tester, keyScale, 'roadmap_empty_390x844_scale13');
    });

    testWidgets('Populated State - Multimodal StatusChips on courses', (tester) async {
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

      addTearDown(() {
        catalog.dispose();
        profile.dispose();
        transcript.dispose();
        auth.dispose();
        chat.dispose();
      });

      final key = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const RoadmapScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: key,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      // Assertions
      expect(find.text('Tiến độ toàn khóa'), findsOneWidget);
      // StatusChips are present for eligible courses in initial view (HK0)
      expect(find.text('Có thể học'), findsWidgets);

      // Filter to HK1 to view passed courses with scores
      await tester.tap(find.text('HK1'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Đã đạt'), findsWidgets);

      await _captureScreen(tester, key, 'roadmap_populated_390x844_light');
    });

    testWidgets('Populated State - Dark Mode & Scale 1.3', (tester) async {
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

      addTearDown(() {
        catalog.dispose();
        profile.dispose();
        transcript.dispose();
        auth.dispose();
        chat.dispose();
      });

      final keyDark = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const RoadmapScreen(),
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
      await _captureScreen(tester, keyDark, 'roadmap_populated_390x844_dark');

      final keyScale = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const RoadmapScreen(),
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
      await _captureScreen(tester, keyScale, 'roadmap_populated_390x844_scale13');
    });

    testWidgets('Populated State - Compact & Wide Viewports', (tester) async {
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

      addTearDown(() {
        catalog.dispose();
        profile.dispose();
        transcript.dispose();
        auth.dispose();
        chat.dispose();
      });

      // 360x640
      final key360 = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const RoadmapScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: key360,
          viewport: const Size(360, 640),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _captureScreen(tester, key360, 'roadmap_populated_360x640_light');

      // 630x900
      final key630 = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const RoadmapScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: key630,
          viewport: const Size(630, 900),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _captureScreen(tester, key630, 'roadmap_populated_630x900_light');
    });

    testWidgets('Search Empty State', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final catalog = CourseCatalog();
      await tester.runAsync(catalog.load);
      final profile = LearningProfileProvider();
      await profile.load();
      final transcript = TranscriptProvider();
      await transcript.load();
      final auth = AuthViewModel(TestAuthService());
      final chat = ChatProvider(apiService: OfflineChatService());

      addTearDown(() {
        catalog.dispose();
        profile.dispose();
        transcript.dispose();
        auth.dispose();
        chat.dispose();
      });

      final key = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const RoadmapScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: key,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      // Enter search query that doesn't match
      await tester.enterText(find.byType(TextField), 'xyznonexistent123');
      await tester.pumpAndSettle();

      expect(find.text('Không tìm thấy môn học'), findsOneWidget);
      expect(find.textContaining('Không tìm thấy môn học nào khớp với từ khóa "xyznonexistent123"'), findsOneWidget);

      await _captureScreen(tester, key, 'roadmap_search_empty_390x844_light');
    });

    testWidgets('Loading & Error States', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final catalog = CourseCatalog();
      catalog.isLoading = true;
      catalog.courses = const [];
      final profile = LearningProfileProvider();
      final transcript = TranscriptProvider();
      final auth = AuthViewModel(TestAuthService());
      final chat = ChatProvider(apiService: OfflineChatService());

      addTearDown(() {
        catalog.dispose();
        profile.dispose();
        transcript.dispose();
        auth.dispose();
        chat.dispose();
      });

      final keyLoading = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const RoadmapScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: keyLoading,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SkeletonCard), findsWidgets);
      await _captureScreen(tester, keyLoading, 'roadmap_loading_390x844_light');

      // Error state
      catalog.isLoading = false;
      catalog.error = 'Không thể tải danh sách lộ trình';
      catalog.courses = const [];

      final keyError = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const RoadmapScreen(),
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

      expect(find.text('Không thể tải lộ trình'), findsOneWidget);
      await _captureScreen(tester, keyError, 'roadmap_error_390x844_light');
    });

    testWidgets('Compact Viewport (360x640) & Wide Viewport (630x900) Empty State', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final catalog = CourseCatalog();
      await tester.runAsync(catalog.load);
      final profile = LearningProfileProvider();
      await profile.load();
      final transcript = TranscriptProvider();
      await transcript.load();
      final auth = AuthViewModel(TestAuthService());
      final chat = ChatProvider(apiService: OfflineChatService());

      addTearDown(() {
        catalog.dispose();
        profile.dispose();
        transcript.dispose();
        auth.dispose();
        chat.dispose();
      });

      final key360 = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const RoadmapScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: key360,
          viewport: const Size(360, 640),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _captureScreen(tester, key360, 'roadmap_empty_360x640_light');

      final key630 = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const RoadmapScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: key630,
          viewport: const Size(630, 900),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _captureScreen(tester, key630, 'roadmap_empty_630x900_light');
    });

    testWidgets('AskAiButton is hidden on Chat and Settings tabs', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final catalog = CourseCatalog();
      await tester.runAsync(catalog.load);
      final profile = LearningProfileProvider();
      await profile.load();
      final transcript = TranscriptProvider();
      await transcript.load();
      final auth = AuthViewModel(TestAuthService());
      final chat = ChatProvider(apiService: OfflineChatService());

      addTearDown(() {
        catalog.dispose();
        profile.dispose();
        transcript.dispose();
        auth.dispose();
        chat.dispose();
      });

      // Pump AppShell starting on Home tab
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const flm_app.AppShell(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
        ),
      );
      await tester.pumpAndSettle();

      // Home tab has AskAiButton
      expect(find.byType(AskAiButton), findsOneWidget);

      // Navigate to Chat tab (Tab index 2: "Trợ lý")
      await tester.tap(find.text('Trợ lý'));
      await tester.pumpAndSettle();
      expect(find.byType(AskAiButton), findsNothing);

      // Navigate to Settings tab (Tab index 4: "Cài đặt")
      await tester.tap(find.text('Cài đặt'));
      await tester.pumpAndSettle();
      expect(find.byType(AskAiButton), findsNothing);
    });
  });
}
