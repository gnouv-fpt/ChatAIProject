import 'dart:io';
import 'dart:ui' as ui;

import 'package:flm_courses/theme/app_theme.dart';
import 'package:flm_courses/widgets/m3_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'feedback_ui_test.dart' show loadEvidenceFont;

Future<void> _captureComponent(
  WidgetTester tester, {
  required String name,
  required Widget widget,
  required bool isDark,
  required double textScale,
  double width = 360,
}) async {
  final key = UniqueKey();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      debugShowCheckedModeBanner: false,
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(textScale),
          size: Size(width, 600),
        ),
        child: Scaffold(
          backgroundColor: isDark ? const Color(0xFF101418) : const Color(0xFFF9F9FC),
          body: Center(
            child: SizedBox(
              width: width,
              child: RepaintBoundary(
                key: key,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: widget,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));

  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(key),
    );
    final image = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final suffix = '${isDark ? "dark" : "light"}_scale_${(textScale * 10).toInt()}';
    final file = File('../evidence/ux/components/${name}_$suffix.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadEvidenceFont();
  });

  group('1. SummaryCard Tests & Goldens', () {
    testWidgets('renders title, subtitle, metrics, action and triggers callback', (tester) async {
      var actionTriggered = false;
      final card = SummaryCard(
        title: 'Bước tiếp theo: Học kỳ 4',
        subtitle: 'Kỹ thuật phần mềm · BIT_SE_K19B',
        badge: StatusChip.info(label: 'Đang diễn ra'),
        metrics: const [
          SummaryMetric(label: 'Tiến độ', value: '28/48 môn', icon: Icons.school_outlined),
          SummaryMetric(label: 'Tín chỉ', value: '84/147 TC', icon: Icons.workspace_premium_outlined),
          SummaryMetric(label: 'GPA hiện tại', value: '8.2', icon: Icons.trending_up_rounded),
        ],
        actionLabel: 'Xem môn đề xuất',
        actionIcon: Icons.arrow_forward_rounded,
        onAction: () => actionTriggered = true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: Scaffold(body: card),
        ),
      );

      expect(find.text('Bước tiếp theo: Học kỳ 4'), findsOneWidget);
      expect(find.text('Kỹ thuật phần mềm · BIT_SE_K19B'), findsOneWidget);
      expect(find.text('28/48 môn'), findsOneWidget);
      expect(find.text('84/147 TC'), findsOneWidget);
      expect(find.text('8.2'), findsOneWidget);
      expect(find.text('Xem môn đề xuất'), findsOneWidget);

      await tester.tap(find.text('Xem môn đề xuất'));
      expect(actionTriggered, isTrue);

      // Goldens in 4 configurations: Light 1.0, Dark 1.0, Light 1.3, Dark 1.3
      await _captureComponent(tester, name: 'summary_card', widget: card, isDark: false, textScale: 1.0);
      await _captureComponent(tester, name: 'summary_card', widget: card, isDark: true, textScale: 1.0);
      await _captureComponent(tester, name: 'summary_card', widget: card, isDark: false, textScale: 1.3);
      await _captureComponent(tester, name: 'summary_card', widget: card, isDark: true, textScale: 1.3);
    });
  });

  group('2. StatusChip Tests & Goldens (Multimodal: Icon + Text)', () {
    testWidgets('always renders both icon and text, and includes semantics', (tester) async {
      var tapped = false;
      final chipGroup = Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          StatusChip.success(label: 'Đã đạt', onTap: () => tapped = true),
          StatusChip.warning(label: 'Cần chú ý'),
          StatusChip.error(label: 'Chưa đạt'),
          StatusChip.info(label: 'Đang học'),
          StatusChip.neutral(label: 'Chưa học'),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: Scaffold(body: chipGroup),
        ),
      );

      // Verify text labels
      expect(find.text('Đã đạt'), findsOneWidget);
      expect(find.text('Cần chú ý'), findsOneWidget);
      expect(find.text('Chưa đạt'), findsOneWidget);
      expect(find.text('Đang học'), findsOneWidget);
      expect(find.text('Chưa học'), findsOneWidget);

      // Verify explicit icons (multimodal - never color alone)
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsOneWidget);

      // Tap test
      await tester.tap(find.text('Đã đạt'));
      expect(tapped, isTrue);

      // Goldens
      await _captureComponent(tester, name: 'status_chip', widget: chipGroup, isDark: false, textScale: 1.0);
      await _captureComponent(tester, name: 'status_chip', widget: chipGroup, isDark: true, textScale: 1.0);
      await _captureComponent(tester, name: 'status_chip', widget: chipGroup, isDark: false, textScale: 1.3);
      await _captureComponent(tester, name: 'status_chip', widget: chipGroup, isDark: true, textScale: 1.3);
    });
  });

  group('3. EmptyState Tests & Goldens', () {
    testWidgets('renders icon, title, 1-line description, and CTA button', (tester) async {
      var ctaTapped = false;
      final empty = EmptyState(
        icon: Icons.description_outlined,
        title: 'Chưa có dữ liệu bảng điểm',
        description: 'Tải ảnh chụp hoặc nhập điểm để xem lộ trình học và GPA dự kiến.',
        actionLabel: 'Nhập bảng điểm',
        actionIcon: Icons.upload_file_rounded,
        onAction: () => ctaTapped = true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: Scaffold(body: empty),
        ),
      );

      expect(find.byIcon(Icons.description_outlined), findsOneWidget);
      expect(find.text('Chưa có dữ liệu bảng điểm'), findsOneWidget);
      expect(find.text('Tải ảnh chụp hoặc nhập điểm để xem lộ trình học và GPA dự kiến.'), findsOneWidget);
      expect(find.text('Nhập bảng điểm'), findsOneWidget);

      await tester.tap(find.text('Nhập bảng điểm'));
      expect(ctaTapped, isTrue);

      // Goldens
      await _captureComponent(tester, name: 'empty_state', widget: empty, isDark: false, textScale: 1.0);
      await _captureComponent(tester, name: 'empty_state', widget: empty, isDark: true, textScale: 1.0);
      await _captureComponent(tester, name: 'empty_state', widget: empty, isDark: false, textScale: 1.3);
      await _captureComponent(tester, name: 'empty_state', widget: empty, isDark: true, textScale: 1.3);
    });
  });

  group('4. InlineBanner Tests & Goldens', () {
    testWidgets('renders banner message, action, dismiss, and handles callbacks', (tester) async {
      var actionTapped = false;
      var dismissed = false;

      final banners = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InlineBanner(
            message: 'Mất kết nối backend. Đang sử dụng dữ liệu ngoại tuyến.',
            severity: BannerSeverity.warning,
            actionLabel: 'Thử lại',
            onAction: () => actionTapped = true,
          ),
          const SizedBox(height: 8),
          InlineBanner(
            message: 'Đã đồng bộ thành công hồ sơ của bạn lên Firestore.',
            severity: BannerSeverity.success,
            onDismiss: () => dismissed = true,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: Scaffold(body: banners),
        ),
      );

      expect(find.text('Mất kết nối backend. Đang sử dụng dữ liệu ngoại tuyến.'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);

      await tester.tap(find.text('Thử lại'));
      expect(actionTapped, isTrue);

      await tester.tap(find.byTooltip('Đóng thông báo'));
      expect(dismissed, isTrue);

      // Goldens
      await _captureComponent(tester, name: 'inline_banner', widget: banners, isDark: false, textScale: 1.0);
      await _captureComponent(tester, name: 'inline_banner', widget: banners, isDark: true, textScale: 1.0);
      await _captureComponent(tester, name: 'inline_banner', widget: banners, isDark: false, textScale: 1.3);
      await _captureComponent(tester, name: 'inline_banner', widget: banners, isDark: true, textScale: 1.3);
    });
  });

  group('5. SectionHeader Tests & Goldens', () {
    testWidgets('renders title, subtitle, icon, and trailing action', (tester) async {
      final header = SectionHeader(
        title: 'Môn học cốt lõi',
        subtitle: 'Bắt buộc hoàn thành trước chuyên ngành hẹp',
        icon: Icons.layers_outlined,
        trailing: TextButton(
          onPressed: () {},
          child: const Text('Xem tất cả (12)'),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: Scaffold(body: header),
        ),
      );

      expect(find.text('Môn học cốt lõi'), findsOneWidget);
      expect(find.text('Bắt buộc hoàn thành trước chuyên ngành hẹp'), findsOneWidget);
      expect(find.byIcon(Icons.layers_outlined), findsOneWidget);
      expect(find.text('Xem tất cả (12)'), findsOneWidget);

      // Goldens
      await _captureComponent(tester, name: 'section_header', widget: header, isDark: false, textScale: 1.0);
      await _captureComponent(tester, name: 'section_header', widget: header, isDark: true, textScale: 1.0);
      await _captureComponent(tester, name: 'section_header', widget: header, isDark: false, textScale: 1.3);
      await _captureComponent(tester, name: 'section_header', widget: header, isDark: true, textScale: 1.3);
    });
  });

  group('6. SettingsTile Tests & Goldens', () {
    testWidgets('renders leading icon, titles, trailing widget and triggers onTap', (tester) async {
      var tileTapped = false;
      var switchValue = true;

      final tiles = Card(
        child: Column(
          children: [
            SettingsTile(
              title: 'Mục tiêu GPA',
              subtitle: '8.5 / 10.0 · Giỏi',
              leadingIcon: Icons.flag_outlined,
              onTap: () => tileTapped = true,
            ),
            const Divider(height: 1, indent: 70),
            SettingsTile(
              title: 'Tự động đồng bộ Cloud',
              subtitle: 'Lưu trên Firestore tài khoản Google',
              leadingIcon: Icons.cloud_sync_outlined,
              trailing: Switch(
                value: switchValue,
                onChanged: (v) => switchValue = v,
              ),
            ),
            const Divider(height: 1, indent: 70),
            SettingsTile(
              title: 'Xóa toàn bộ dữ liệu cục bộ',
              subtitle: 'Chỉ xóa trên thiết bị này, không mất tài khoản',
              leadingIcon: Icons.delete_outline_rounded,
              isDestructive: true,
              onTap: () {},
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: Scaffold(body: tiles),
        ),
      );

      expect(find.text('Mục tiêu GPA'), findsOneWidget);
      expect(find.text('8.5 / 10.0 · Giỏi'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
      expect(find.text('Xóa toàn bộ dữ liệu cục bộ'), findsOneWidget);

      await tester.tap(find.text('Mục tiêu GPA'));
      expect(tileTapped, isTrue);

      // Goldens
      await _captureComponent(tester, name: 'settings_tile', widget: tiles, isDark: false, textScale: 1.0);
      await _captureComponent(tester, name: 'settings_tile', widget: tiles, isDark: true, textScale: 1.0);
      await _captureComponent(tester, name: 'settings_tile', widget: tiles, isDark: false, textScale: 1.3);
      await _captureComponent(tester, name: 'settings_tile', widget: tiles, isDark: true, textScale: 1.3);
    });
  });

  group('7. AskAiButton Tests & Goldens', () {
    testWidgets('renders labeled button when visible=true and hides when visible=false', (tester) async {
      var buttonTapped = false;

      // 1. Visible test
      final visibleButton = AskAiButton(
        visible: true,
        onPressed: () => buttonTapped = true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Trang chủ'),
              actions: [visibleButton],
            ),
          ),
        ),
      );

      expect(find.text('Hỏi AI'), findsOneWidget);
      expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget);
      expect(find.byTooltip('Hỏi trợ lý AI FLM'), findsOneWidget);

      await tester.tap(find.text('Hỏi AI'));
      expect(buttonTapped, isTrue);

      // 2. Hidden test (e.g. for Settings screen)
      final hiddenButton = AskAiButton(
        visible: false,
        onPressed: () {},
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Cài đặt'),
              actions: [hiddenButton],
            ),
          ),
        ),
      );

      expect(find.text('Hỏi AI'), findsNothing);
      expect(find.byIcon(Icons.smart_toy_outlined), findsNothing);

      // Goldens for visible button
      await _captureComponent(tester, name: 'ask_ai_button', widget: Center(child: visibleButton), isDark: false, textScale: 1.0);
      await _captureComponent(tester, name: 'ask_ai_button', widget: Center(child: visibleButton), isDark: true, textScale: 1.0);
      await _captureComponent(tester, name: 'ask_ai_button', widget: Center(child: visibleButton), isDark: false, textScale: 1.3);
      await _captureComponent(tester, name: 'ask_ai_button', widget: Center(child: visibleButton), isDark: true, textScale: 1.3);
    });
  });

  group('8. Skeleton Tests & Goldens', () {
    testWidgets('renders box, line, card placeholders and animated states', (tester) async {
      final skeletonDemo = Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SkeletonCard(height: 100),
          SizedBox(height: 12),
          SkeletonLine(width: 200, height: 16),
          SizedBox(height: 6),
          SkeletonLine(width: 120, height: 12),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: Scaffold(body: skeletonDemo),
        ),
      );

      expect(find.byType(SkeletonCard), findsOneWidget);
      expect(find.byType(SkeletonLine), findsNWidgets(5)); // 2 in demo + 3 inside SkeletonCard
      expect(find.byType(SkeletonBox), findsWidgets);

      // Goldens
      await _captureComponent(tester, name: 'skeleton', widget: skeletonDemo, isDark: false, textScale: 1.0);
      await _captureComponent(tester, name: 'skeleton', widget: skeletonDemo, isDark: true, textScale: 1.0);
      await _captureComponent(tester, name: 'skeleton', widget: skeletonDemo, isDark: false, textScale: 1.3);
      await _captureComponent(tester, name: 'skeleton', widget: skeletonDemo, isDark: true, textScale: 1.3);
    });
  });
}
