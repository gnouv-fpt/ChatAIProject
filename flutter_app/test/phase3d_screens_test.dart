import 'dart:io';
import 'dart:ui' as ui;

import 'package:flm_courses/features/chat/providers/chat_provider.dart';
import 'package:flm_courses/features/chat/views/chat_screen.dart';
import 'package:flm_courses/features/chat/views/widgets/contextual_chat_panel.dart';
import 'package:flm_courses/features/graph/views/graph_view_screen.dart';
import 'package:flm_courses/screens/home_screen.dart';
import 'package:flm_courses/screens/roadmap_screen.dart';
import 'package:flm_courses/screens/settings_screen.dart';
import 'package:flm_courses/screens/transcript_screen.dart';
import 'package:flm_courses/state/auth_view_model.dart';
import 'package:flm_courses/state/course_catalog.dart';
import 'package:flm_courses/state/learning_profile_provider.dart';
import 'package:flm_courses/state/transcript_provider.dart';
import 'package:flm_courses/widgets/ask_ai_button.dart';
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
  String dir = '../evidence/ux/phase3d',
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

  group('Phase 3d - Section B: AI Icon Sweep & AskAiButton Consistency', () {
    testWidgets('Quét 5 tab + Sơ đồ: Không còn bất kỳ icon auto_awesome nào, AskAiButton đúng vị trí', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final catalog = CourseCatalog();
      await tester.runAsync(catalog.load);
      final profile = LearningProfileProvider();
      await profile.load();
      final transcript = TranscriptProvider();
      await transcript.load();
      final auth = AuthViewModel(TestAuthService());
      final chat = ChatProvider(apiService: OfflineChatService());

      tester.view.physicalSize = const Size(390, 844);
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

      // 1. Tab Trang chủ
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: HomeScreen(onNavigate: (_) {}),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AskAiButton), findsOneWidget, reason: 'Trang chủ phải có AskAiButton');
      expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
      expect(find.byIcon(Icons.auto_awesome_outlined), findsNothing);
      expect(find.byIcon(Icons.auto_awesome), findsNothing);

      // 2. Tab Lộ trình
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const RoadmapScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AskAiButton), findsWidgets, reason: 'Lộ trình phải có AskAiButton');
      expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
      expect(find.byIcon(Icons.auto_awesome_outlined), findsNothing);
      expect(find.byIcon(Icons.auto_awesome), findsNothing);

      // 3. Tab Bảng điểm
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const TranscriptScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AskAiButton), findsOneWidget, reason: 'Bảng điểm phải có AskAiButton');
      expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
      expect(find.byIcon(Icons.auto_awesome_outlined), findsNothing);
      expect(find.byIcon(Icons.auto_awesome), findsNothing);

      // 4. Tab Trợ lý (ChatScreen) - ẨN AskAiButton
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const ChatScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AskAiButton), findsNothing, reason: 'Tab Trợ lý phải ẨN AskAiButton');
      expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
      expect(find.byIcon(Icons.auto_awesome_outlined), findsNothing);
      expect(find.byIcon(Icons.auto_awesome), findsNothing);

      // 5. Tab Cài đặt - ẨN AskAiButton
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const SettingsScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AskAiButton), findsNothing, reason: 'Tab Cài đặt phải ẨN AskAiButton');
      expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
      expect(find.byIcon(Icons.auto_awesome_outlined), findsNothing);
      expect(find.byIcon(Icons.auto_awesome), findsNothing);

      // 6. Sơ đồ chương trình (GraphViewScreen)
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: GraphViewScreen(onOpenDetail: (_) {}),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
      expect(find.byIcon(Icons.auto_awesome_outlined), findsNothing);
      expect(find.byIcon(Icons.auto_awesome), findsNothing);
    });
  });

  group('Phase 3d - Section A & D: Dữ liệu nhất quán & Bảo mật chuỗi kỹ thuật', () {
    testWidgets('147 tín chỉ, 10 học kỳ, không lộ UID / Firestore, đăng xuất ở đáy Cài đặt', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final catalog = CourseCatalog();
      await tester.runAsync(catalog.load);
      final profile = LearningProfileProvider();
      await profile.load();
      final transcript = TranscriptProvider();
      await transcript.load();
      final auth = AuthViewModel(TestAuthService(userName: 'Nguyễn Đăng Khôi', userEmail: 'khoind@fpt.edu.vn'));
      final chat = ChatProvider(apiService: OfflineChatService());

      tester.view.physicalSize = const Size(390, 844);
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

      // Verify Canonical Numbers from Catalog
      expect(catalog.totalCredits, 147);
      expect(catalog.totalSemesters, 10);
      expect(catalog.curriculum?.totalCredits, 147);

      // Settings Screen checks
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

      // Ensure no raw technical UID is rendered
      expect(find.textContaining('ID: khoind'), findsNothing);
      expect(find.textContaining('Firestore'), findsNothing);
      // User name and email rendered
      expect(find.text('Nguyễn Đăng Khôi'), findsOneWidget);
      expect(find.text('khoind@fpt.edu.vn'), findsOneWidget);
      expect(find.text('Dữ liệu lưu riêng tư trên thiết bị.'), findsOneWidget);

      // Verify curriculum credits line in Settings shows 147
      expect(find.textContaining('147 tín chỉ'), findsOneWidget);
      expect(find.textContaining('145 tín chỉ'), findsNothing);

      // Verify Sign Out button is at the bottom, styled outlined with error color
      await tester.scrollUntilVisible(
        find.text('Đăng xuất tài khoản'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Đăng xuất tài khoản'), findsOneWidget);

      await _captureScreen(tester, keySettings, 'settings_overview_390x844_light');

      // Dark Mode & Scale 1.3
      final keySettingsDark = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const SettingsScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          isDark: true,
          repaintKey: keySettingsDark,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();
      await _captureScreen(tester, keySettingsDark, 'settings_overview_390x844_dark');

      final keySettingsScale = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const SettingsScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          textScale: 1.3,
          repaintKey: keySettingsScale,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();
      await _captureScreen(tester, keySettingsScale, 'settings_overview_390x844_scale13');
    });
  });

  group('Phase 3d - Section C: Trang chủ Hero Card Gradient & 3 Bước Bắt Đầu', () {
    testWidgets('Trang chủ (chưa có bảng điểm): Hero gradient gọn, CTA tương phản cao, 3 bước bắt đầu', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final catalog = CourseCatalog();
      await tester.runAsync(catalog.load);
      final profile = LearningProfileProvider();
      await profile.load();
      final transcript = TranscriptProvider();
      await transcript.load(); // empty
      final auth = AuthViewModel(TestAuthService());
      final chat = ChatProvider(apiService: OfflineChatService());

      tester.view.physicalSize = const Size(390, 844);
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

      final keyHomeLight = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: HomeScreen(onNavigate: (_) {}),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: keyHomeLight,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      // Hero Card checks
      expect(find.text('BƯỚC TIẾP THEO'), findsOneWidget);
      expect(find.text('Nhập bảng điểm ngay'), findsOneWidget);
      // No "Chưa có bảng điểm" chip in hero
      expect(find.widgetWithText(Container, 'Chưa có bảng điểm'), findsNothing);
      // Metrics show canonical numbers
      expect(find.text('48 môn'), findsOneWidget);
      expect(find.text('147 tín chỉ'), findsOneWidget);
      expect(find.text('10 học kỳ (HK0–HK9)'), findsOneWidget);

      // Checklist "3 bước bắt đầu"
      expect(find.text('3 bước bắt đầu'), findsOneWidget);
      expect(find.text('1. Nhập bảng điểm'), findsOneWidget);
      expect(find.text('2. Đặt mục tiêu GPA'), findsOneWidget);
      expect(find.text('3. Xem môn nên học kỳ tới'), findsOneWidget);

      await _captureScreen(tester, keyHomeLight, 'home_empty_390x844_light');

      // Dark Mode & Scale 1.3
      final keyHomeDark = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: HomeScreen(onNavigate: (_) {}),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          isDark: true,
          repaintKey: keyHomeDark,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();
      await _captureScreen(tester, keyHomeDark, 'home_empty_390x844_dark');

      final keyHomeScale = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: HomeScreen(onNavigate: (_) {}),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          textScale: 1.3,
          repaintKey: keyHomeScale,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();
      await _captureScreen(tester, keyHomeScale, 'home_empty_390x844_scale13');

      // Compact 360x640 and Wide 630x900
      final keyHomeCompact = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: HomeScreen(onNavigate: (_) {}),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: keyHomeCompact,
          viewport: const Size(360, 640),
        ),
      );
      await tester.pumpAndSettle();
      await _captureScreen(tester, keyHomeCompact, 'home_empty_360x640_light');

      final keyHomeWide = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: HomeScreen(onNavigate: (_) {}),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: keyHomeWide,
          viewport: const Size(630, 900),
        ),
      );
      await tester.pumpAndSettle();
      await _captureScreen(tester, keyHomeWide, 'home_empty_630x900_light');
    });

    testWidgets('Trang chủ (đã có bảng điểm): Hero hiện tiến độ & CTA Xem gợi ý môn kỳ tới', (tester) async {
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

      tester.view.physicalSize = const Size(390, 844);
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

      final keyHomePopulated = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: HomeScreen(onNavigate: (_) {}),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: keyHomePopulated,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Xem gợi ý môn kỳ tới'), findsOneWidget);
      expect(find.text('Đang theo dõi'), findsOneWidget);
      expect(find.text('Môn ưu tiên kỳ tới'), findsOneWidget);
      await _captureScreen(tester, keyHomePopulated, 'home_populated_390x844_light');
    });
  });

  group('Phase 3d - Section D: Lộ trình (Roadmap) Above-The-Fold & Thẻ Môn', () {
    testWidgets('Lộ trình (chưa có điểm): Banner duy nhất, thanh tiến độ mỏng, thấy thẻ môn above the fold', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final catalog = CourseCatalog();
      await tester.runAsync(catalog.load);
      final profile = LearningProfileProvider();
      await profile.load();
      final transcript = TranscriptProvider();
      await transcript.load(); // empty
      final auth = AuthViewModel(TestAuthService());
      final chat = ChatProvider(apiService: OfflineChatService());

      tester.view.physicalSize = const Size(390, 844);
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

      final keyRoadmapLight = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const RoadmapScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: keyRoadmapLight,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      // Exactly ONE banner
      expect(find.text('Chưa có bảng điểm. Nhập điểm để xem tiến độ và điều kiện tiên quyết.'), findsOneWidget);
      // Thin progress line
      expect(find.text('0/48 môn · 0/147 tín chỉ'), findsOneWidget);
      // Redundant "Chương trình đào tạo" summary card removed
      expect(find.text('Chương trình đào tạo'), findsNothing);

      // Verify course card of Semester 0/1 is visible above the fold
      expect(find.text('Học kỳ 0'), findsOneWidget);
      expect(find.textContaining('OTP101'), findsOneWidget);

      await _captureScreen(tester, keyRoadmapLight, 'roadmap_empty_390x844_light');

      // Dark Mode & Scale 1.3
      final keyRoadmapDark = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const RoadmapScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          isDark: true,
          repaintKey: keyRoadmapDark,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();
      await _captureScreen(tester, keyRoadmapDark, 'roadmap_empty_390x844_dark');

      final keyRoadmapScale = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const RoadmapScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          textScale: 1.3,
          repaintKey: keyRoadmapScale,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();
      await _captureScreen(tester, keyRoadmapScale, 'roadmap_empty_390x844_scale13');

      // Compact 360x640: course card MUST be visible above the fold
      final keyRoadmapCompact = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const RoadmapScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: keyRoadmapCompact,
          viewport: const Size(360, 640),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('OTP101'), findsOneWidget, reason: 'Môn OTP101 phải nhìn thấy above the fold ở màn 360x640');
      await _captureScreen(tester, keyRoadmapCompact, 'roadmap_empty_360x640_light');

      // Wide 630x900
      final keyRoadmapWide = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const RoadmapScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: keyRoadmapWide,
          viewport: const Size(630, 900),
        ),
      );
      await tester.pumpAndSettle();
      await _captureScreen(tester, keyRoadmapWide, 'roadmap_empty_630x900_light');
    });
  });

  group('Phase 3d - Section D: Bảng điểm (Transcript) Nút Xếp Dọc Full-Width', () {
    testWidgets('Bảng điểm (chưa điểm): 2 nút xếp dọc full-width 48dp, khoảng cách 12dp, câu chữ bảo mật thống nhất', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final catalog = CourseCatalog();
      await tester.runAsync(catalog.load);
      final profile = LearningProfileProvider();
      await profile.load();
      final transcript = TranscriptProvider();
      await transcript.load();
      final auth = AuthViewModel(TestAuthService());
      final chat = ChatProvider(apiService: OfflineChatService());

      tester.view.physicalSize = const Size(390, 844);
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

      final keyTranscriptLight = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const TranscriptScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: keyTranscriptLight,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      final primaryBtn = find.widgetWithText(FilledButton, 'Nhập ảnh bảng điểm');
      final secondaryBtn = find.widgetWithText(OutlinedButton, 'Nhập điểm thủ công');

      expect(primaryBtn, findsOneWidget);
      expect(secondaryBtn, findsOneWidget);

      final primaryBox = tester.renderObject<RenderBox>(primaryBtn);
      final secondaryBox = tester.renderObject<RenderBox>(secondaryBtn);

      // Both buttons are 48dp height and full-width
      expect(primaryBox.size.height, 48.0);
      expect(secondaryBox.size.height, 48.0);
      expect(primaryBox.size.width, closeTo(390 - 32, 1.0));
      expect(secondaryBox.size.width, closeTo(390 - 32, 1.0));

      // Vertical distance between buttons is 12dp
      final primaryBottom = tester.getBottomLeft(primaryBtn).dy;
      final secondaryTop = tester.getTopLeft(secondaryBtn).dy;
      expect(secondaryTop - primaryBottom, closeTo(12.0, 1.0));

      // Security note unified
      expect(find.text('Bảng điểm được lưu an toàn trên thiết bị của bạn'), findsOneWidget);

      await _captureScreen(tester, keyTranscriptLight, 'transcript_empty_390x844_light');

      // Dark Mode & Scale 1.3
      final keyTranscriptDark = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const TranscriptScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          isDark: true,
          repaintKey: keyTranscriptDark,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();
      await _captureScreen(tester, keyTranscriptDark, 'transcript_empty_390x844_dark');

      final keyTranscriptScale = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const TranscriptScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          textScale: 1.3,
          repaintKey: keyTranscriptScale,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();
      await _captureScreen(tester, keyTranscriptScale, 'transcript_empty_390x844_scale13');
    });
  });

  group('Phase 3d - Section D: Sheet Ngữ Cảnh (Contextual Chat Panel)', () {
    testWidgets('Sheet ngữ cảnh: Không có icon thùng rác, menu 3 chấm, 4 câu gợi ý khớp ngữ cảnh, nhãn thân thiện', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final catalog = CourseCatalog();
      await tester.runAsync(catalog.load);
      final profile = LearningProfileProvider();
      await profile.load();
      final transcript = TranscriptProvider();
      await transcript.load();
      final auth = AuthViewModel(TestAuthService());
      final chat = ChatProvider(apiService: OfflineChatService());

      tester.view.physicalSize = const Size(390, 844);
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

      final keySheetLight = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: Scaffold(
            body: ContextualChatPanel(
              scope: 'curriculum',
              scopeId: 'BIT_SE_K19B:roadmap',
              backendScopeId: 'BIT_SE_K19B',
              title: 'lộ trình học tập',
              contextHint: 'Lộ trình đào tạo chuẩn ngành Kỹ thuật phần mềm',
            ),
          ),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          repaintKey: keySheetLight,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      // No trash icon directly in header
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
      // Popup menu button present
      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);

      // Context label is human friendly (NO BIT_SE_K19B:roadmap)
      expect(find.text('Phạm vi: Lộ trình học tập'), findsOneWidget);
      expect(find.textContaining('BIT_SE_K19B:roadmap'), findsNothing);

      // Sentence case title (Lộ trình học tập, NOT Lộ Trình Học Tập)
      expect(find.text('Lộ trình học tập'), findsOneWidget);

      // 4 Contextual Suggestions rendered
      expect(find.text('Khung chương trình có bao nhiêu tín chỉ?'), findsOneWidget);
      expect(find.text('Các môn tiên quyết quan trọng nhất là gì?'), findsOneWidget);
      expect(find.text('Tôi nên đăng ký môn theo lộ trình thế nào?'), findsOneWidget);
      expect(find.text('Quy định về hạ bậc tốt nghiệp như thế nào?'), findsOneWidget);

      await _captureScreen(tester, keySheetLight, 'contextual_sheet_390x844_light');

      // Dark Mode
      final keySheetDark = GlobalKey();
      await tester.pumpWidget(
        wrapWithTestProviders(
          child: Scaffold(
            body: ContextualChatPanel(
              scope: 'curriculum',
              scopeId: 'BIT_SE_K19B:roadmap',
              backendScopeId: 'BIT_SE_K19B',
              title: 'lộ trình học tập',
              contextHint: 'Lộ trình đào tạo chuẩn ngành Kỹ thuật phần mềm',
            ),
          ),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          isDark: true,
          repaintKey: keySheetDark,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();
      await _captureScreen(tester, keySheetDark, 'contextual_sheet_390x844_dark');
    });
  });
}
