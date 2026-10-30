import 'dart:io';
import 'dart:ui' as ui;

import 'package:flm_courses/features/chat/models/chat_message.dart';
import 'package:flm_courses/features/chat/providers/chat_provider.dart';
import 'package:flm_courses/features/chat/views/chat_screen.dart';
import 'package:flm_courses/features/chat/views/widgets/chat_bubble.dart';
import 'package:flm_courses/features/chat/views/widgets/contextual_chat_panel.dart';
import 'package:flm_courses/features/graph/views/graph_view_screen.dart';
import 'package:flm_courses/pages/course_detail_page.dart';
import 'package:flm_courses/pages/curriculum_detail_page.dart';
import 'package:flm_courses/screens/home_screen.dart';
import 'package:flm_courses/screens/roadmap_screen.dart';
import 'package:flm_courses/screens/settings_screen.dart';
import 'package:flm_courses/screens/sign_in_screen.dart';
import 'package:flm_courses/state/auth_view_model.dart';
import 'package:flm_courses/state/learning_profile_provider.dart';
import 'package:flm_courses/state/transcript_provider.dart';
import 'package:flm_courses/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'curriculum_ux_test.dart' show fixtureCatalog, openCurriculum;
import 'settings_sign_out_test.dart' show OfflineChat, SignedInService;
import 'feedback_ui_test.dart' show loadEvidenceFont;

const captureMobileAudit = bool.fromEnvironment('MOBILE_AUDIT_EVIDENCE');

// Paragraph selection is an inline text gesture, not a standalone control.
// Keep the standard 48dp check for buttons, editable fields and other actions.
class MobileControlTargetGuideline extends MinimumTapTargetGuideline {
  const MobileControlTargetGuideline()
    : super(
        size: const Size(48, 48),
        link:
            'https://developer.android.com/guide/topics/ui/accessibility/apps',
      );

  @override
  bool shouldSkipNode(SemanticsNode node) {
    final data = node.getSemanticsData();
    if (data.flagsCollection.isReadOnly &&
        data.flagsCollection.isTextField &&
        !data.hasAction(ui.SemanticsAction.tap)) {
      return true;
    }
    return super.shouldSkipNode(node);
  }
}

Future<void> captureAudit(
  WidgetTester tester,
  String name,
  Key boundaryKey,
) async {
  if (!captureMobileAudit) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundaryKey),
    );
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('../evidence/ux/2026-10-30-mobile-audit/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  testWidgets(
    'invalid connection address keeps dialog open with a correction',
    (tester) async {
      await openCurriculum(tester, width: 360, home: const ChatScreen());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Cài đặt kết nối'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'khong-phai-dia-chi');
      await tester.tap(find.text('Lưu & Kết nối'));
      await tester.pumpAndSettle();
      expect(
        find.text('Nhập địa chỉ bắt đầu bằng http:// hoặc https://.'),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('canceling deletion retains the current conversation', (
    tester,
  ) async {
    await openCurriculum(
      tester,
      width: 360,
      home: const Scaffold(
        body: ContextualChatPanel(
          scope: 'subject',
          scopeId: 'PRF192',
          title: 'Trợ lý môn học',
        ),
      ),
    );
    await tester.pumpAndSettle();
    final chat = tester
        .element(find.byType(ContextualChatPanel))
        .read<ChatProvider>();
    final ids = chat.messages.map((message) => message.id).toList();
    await tester.tap(find.byTooltip('Xóa hội thoại'));
    await tester.pumpAndSettle();
    expect(find.text('Xóa hội thoại này?'), findsOneWidget);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(chat.messages.map((message) => message.id), ids);
  });

  testWidgets('graph respects reduced motion', (tester) async {
    await openCurriculum(
      tester,
      width: 360,
      home: Scaffold(
        body: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const GraphViewScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.text('Danh sách môn'), findsOneWidget);
  });
  test('small status text colors meet 4.5:1 contrast', () {
    final pairs = [
      (AppTheme.peBadgeText, AppTheme.peBadgeBg),
      (AppTheme.gpaBadgeText, AppTheme.gpaBadgeBg),
      (AppTheme.nonGpaBadgeText, AppTheme.nonGpaBadgeBg),
      (AppTheme.primaryBlue, AppTheme.primaryLight),
      (AppTheme.slate600, Colors.white),
      (AppTheme.warning, AppTheme.warningSurface),
      (AppTheme.danger, AppTheme.dangerSurface),
      (AppTheme.success, AppTheme.successSurface),
      (Colors.white, AppTheme.primaryBlue),
    ];
    for (final (foreground, background) in pairs) {
      final light = [
        foreground.computeLuminance(),
        background.computeLuminance(),
      ]..sort();
      expect(
        (light.last + 0.05) / (light.first + 0.05),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  testWidgets(
    'graph has a labeled list alternative and usable course details',
    (tester) async {
      await openCurriculum(
        tester,
        width: 360,
        scale: 2,
        home: const Scaffold(body: GraphViewScreen()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Danh sách môn'));
      await tester.pumpAndSettle();
      expect(find.text('Môn học trong sơ đồ'), findsOneWidget);
      await tester.tap(find.textContaining('PRF192 ·'));
      await tester.pumpAndSettle();
      expect(find.text('Tiên quyết: Không có'), findsOneWidget);
      expect(find.text('Môn phụ thuộc: Không có'), findsOneWidget);
      await tester.tap(find.byTooltip('Đóng thông tin môn'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('course advisor composer stays above keyboard and can close', (
    tester,
  ) async {
    if (captureMobileAudit) await tester.runAsync(loadEvidenceFont);
    await openCurriculum(
      tester,
      width: 360,
      scale: 1.3,
      home: const CourseDetailPage(code: 'PRF192'),
    );
    tester.view.physicalSize = const Size(360, 640);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tư vấn môn này'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hỏi AI chi tiết'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    final input = find.descendant(
      of: find.byType(ContextualChatPanel),
      matching: find.byType(TextField),
    );
    await tester.enterText(input, 'Tôi nên học môn này như thế nào?');
    await tester.pumpAndSettle();
    expect(tester.getBottomRight(input).dy, lessThanOrEqualTo(360));
    expect(find.byTooltip('Gửi câu hỏi').hitTestable(), findsOneWidget);
    await captureAudit(
      tester,
      'course-chat-keyboard-360',
      const Key('ux-capture'),
    );
    await tester.tap(find.byTooltip('Đóng Trợ lý AI'));
    await tester.pumpAndSettle();
    expect(find.byType(ContextualChatPanel), findsNothing);
  });

  final screens = <String, Widget>{
    'home': HomeScreen(onNavigate: (_) {}),
    'roadmap': const RoadmapScreen(),
    'settings': const SettingsScreen(),
    'sign in': const SignInScreen(),
    'chat': const ChatScreen(),
    'curriculum': const CurriculumDetailPage(curriculumId: 'TEST'),
    'course detail': const CourseDetailPage(code: 'PRF192'),
    'contextual chat': const Scaffold(
      body: ContextualChatPanel(
        scope: 'subject',
        scopeId: 'PRF192',
        title: 'Trợ lý môn PRF192',
      ),
    ),
    'message': Scaffold(
      body: ChatBubble(
        message: ChatMessage(
          id: 'audit',
          text: 'Nội dung tư vấn học tập.',
          sender: ChatSender.ai,
          timestamp: DateTime(2026, 10, 30),
        ),
      ),
    ),
  };
  for (final entry in screens.entries) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '${entry.key}: labeled 48dp controls and reflow at ${scale}x',
        (tester) async {
          tester.view.physicalSize = const Size(360, 640);
          tester.view.devicePixelRatio = 1;
          if (captureMobileAudit) await tester.runAsync(loadEvidenceFont);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final semantics = tester.ensureSemantics();
          try {
            SharedPreferences.setMockInitialValues({});
            final catalog = fixtureCatalog();
            final profile = LearningProfileProvider();
            final transcript = TranscriptProvider();
            await profile.load();
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
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider.value(value: catalog),
                  ChangeNotifierProvider.value(value: profile),
                  ChangeNotifierProvider.value(value: transcript),
                  ChangeNotifierProvider.value(value: auth),
                  ChangeNotifierProvider.value(value: chat),
                ],
                child: MaterialApp(
                  theme: AppTheme.lightTheme(),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: RepaintBoundary(
                      key: const Key('mobile-audit'),
                      child: child!,
                    ),
                  ),
                  home: entry.value,
                ),
              ),
            );
            await tester.pumpAndSettle();
            if (entry.key == 'roadmap' || entry.key == 'contextual chat') {
              await captureAudit(
                tester,
                '${entry.key.replaceAll(' ', '-')}-${scale}x',
                const Key('mobile-audit'),
              );
            }
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            if (entry.key == 'message') {
              // Selectable text has a long-press action, but is not a button.
              // Measure the explicit copy control instead of each text line.
              final size = tester.getSize(find.byTooltip('Sao chép tin nhắn'));
              expect(size.width, greaterThanOrEqualTo(48));
              expect(size.height, greaterThanOrEqualTo(48));
            } else {
              await expectLater(
                tester,
                meetsGuideline(const MobileControlTargetGuideline()),
              );
            }
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }
}
