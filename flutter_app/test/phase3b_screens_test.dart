import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flm_courses/features/chat/providers/chat_provider.dart';
import 'package:flm_courses/features/chat/services/chat_api_service.dart';
import 'package:flm_courses/features/chat/views/chat_screen.dart';
import 'package:flm_courses/features/chat/views/widgets/contextual_chat_panel.dart';
import 'package:flm_courses/features/chat/views/widgets/server_status_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'feedback_ui_test.dart' show loadEvidenceFont;
import 'fixtures/phase3b_fixtures.dart';

Future<void> _captureScreen(
  WidgetTester tester,
  GlobalKey key,
  String filename, {
  String dir = '../evidence/ux/phase3b',
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

  group('Phase 3b - ChatScreen', () {
    testWidgets('Empty State - Greeting, 4 prompt chips, send dimmed', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final api = MockChatApiService(isOnline: true);
      final chat = ChatProvider(apiService: api);
      addTearDown(chat.dispose);

      final key = GlobalKey();
      await tester.pumpWidget(
        wrapWithChatProviders(
          child: const ChatScreen(),
          chat: chat,
          repaintKey: key,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      // Assertions
      expect(find.text('Trợ lý AI FLM'), findsOneWidget);
      expect(find.text('Chào bạn! Tôi có thể giúp gì?'), findsOneWidget);
      expect(find.text('Tôi nên học gì ở kỳ tới?'), findsOneWidget);
      expect(find.text('Điều kiện tiên quyết của SEP490?'), findsOneWidget);
      expect(find.text('Làm sao để cải thiện GPA an toàn?'), findsOneWidget);
      expect(find.text('Quy định về hạ bậc tốt nghiệp?'), findsOneWidget);
      // No "Nguồn" on empty / welcome state
      expect(find.text('Nguồn:'), findsNothing);

      // Verify send button is dimmed / disabled when input empty
      final sendFinder = find.widgetWithIcon(IconButton, Icons.send_rounded);
      expect(sendFinder, findsOneWidget);
      final IconButton sendButton = tester.widget(sendFinder);
      expect(sendButton.onPressed, isNull);

      await _captureScreen(tester, key, 'chat_empty_390x844_light');
    });

    testWidgets('Empty State - Dark Mode & Scale 1.3', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final api = MockChatApiService(isOnline: true);
      final chat = ChatProvider(apiService: api);
      addTearDown(chat.dispose);

      final keyDark = GlobalKey();
      await tester.pumpWidget(
        wrapWithChatProviders(
          child: const ChatScreen(),
          chat: chat,
          isDark: true,
          repaintKey: keyDark,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();
      await _captureScreen(tester, keyDark, 'chat_empty_390x844_dark');

      final keyScale = GlobalKey();
      await tester.pumpWidget(
        wrapWithChatProviders(
          child: const ChatScreen(),
          chat: chat,
          textScale: 1.3,
          repaintKey: keyScale,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _captureScreen(tester, keyScale, 'chat_empty_390x844_scale13');
    });

    testWidgets('Empty State - Compact (360x640) & Wide (630x900)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final api = MockChatApiService(isOnline: true);
      final chat = ChatProvider(apiService: api);
      addTearDown(chat.dispose);

      final keyCompact = GlobalKey();
      await tester.pumpWidget(
        wrapWithChatProviders(
          child: const ChatScreen(),
          chat: chat,
          viewport: const Size(360, 640),
          repaintKey: keyCompact,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _captureScreen(tester, keyCompact, 'chat_empty_360x640_light');

      final keyWide = GlobalKey();
      await tester.pumpWidget(
        wrapWithChatProviders(
          child: const ChatScreen(),
          chat: chat,
          viewport: const Size(630, 900),
          repaintKey: keyWide,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _captureScreen(tester, keyWide, 'chat_empty_630x900_light');
    });

    testWidgets('Sending State - In-flight animation & liveRegion semantics', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final completer = Completer<ChatResponseResult>();
      final api = MockChatApiService(isOnline: true, completer: completer);
      final chat = ChatProvider(apiService: api);
      addTearDown(chat.dispose);

      final key = GlobalKey();
      await tester.pumpWidget(
        wrapWithChatProviders(
          child: const ChatScreen(),
          chat: chat,
          repaintKey: key,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on a prompt chip to start sending
      await tester.tap(find.text('Tôi nên học gì ở kỳ tới?'));
      await tester.pump(); // Start request, don't settle yet

      // Assertions
      expect(find.text('Tôi nên học gì ở kỳ tới?'), findsOneWidget);
      expect(find.text('Trợ lý đang trả lời…'), findsOneWidget);
      // liveRegion semantics
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.liveRegion == true,
        ),
        findsOneWidget,
      );

      await _captureScreen(tester, key, 'chat_sending_390x844_light');

      // Complete to unblock
      completer.complete(
        ChatResponseResult(
          answer: 'Bạn nên ưu tiên học PRM393 và SWT301.',
          sources: const ['FLM Syllabus 2026'],
          isOfflineFallback: false,
        ),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('Rich Response - Markdown, Cited Sources, SelectionArea', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final api = MockChatApiService(
        isOnline: true,
        responseResult: ChatResponseResult(
          answer: '### Chiến lược học tập môn PRM393\n\n'
              'Dưới đây là các gợi ý để bạn đạt điểm cao:\n'
              '• Nắm vững kiến thức Flutter Widgets và State Management.\n'
              '• Hoàn thành Lab 1 đến Lab 5 đúng hạn.\n'
              '• Ôn kỹ các câu hỏi PE thực hành.\n\n'
              '> Lưu ý: Môn học có tính vào điểm GPA tích lũy.',
          sources: const ['FLM Syllabus PRM393', 'Quy chế đào tạo FPTU'],
          isOfflineFallback: false,
        ),
      );
      final chat = ChatProvider(apiService: api);
      addTearDown(chat.dispose);

      final key = GlobalKey();
      await tester.pumpWidget(
        wrapWithChatProviders(
          child: const ChatScreen(),
          chat: chat,
          repaintKey: key,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Điều kiện tiên quyết của SEP490?'));
      await tester.pumpAndSettle();

      // Assertions
      expect(find.text('Điều kiện tiên quyết của SEP490?'), findsOneWidget);
      expect(find.text('Chiến lược học tập môn PRM393'), findsOneWidget);
      expect(find.text('Nguồn:'), findsOneWidget);
      expect(find.text('FLM Syllabus PRM393'), findsOneWidget);
      expect(find.text('Quy chế đào tạo FPTU'), findsOneWidget);
      // SelectionArea is present
      expect(find.byType(SelectionArea), findsWidgets);
      // Copy button is present
      expect(find.byTooltip('Sao chép tin nhắn'), findsWidgets);

      await _captureScreen(tester, key, 'chat_rich_response_390x844_light');

      // Dark mode rich response
      final keyDark = GlobalKey();
      await tester.pumpWidget(
        wrapWithChatProviders(
          child: const ChatScreen(),
          chat: chat,
          isDark: true,
          repaintKey: keyDark,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();
      await _captureScreen(tester, keyDark, 'chat_rich_response_390x844_dark');
    });

    testWidgets('Send Error - MessageStatus.error with Retry Button', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final api = MockChatApiService(
        isOnline: true,
        responseResult: ChatResponseResult(
          answer: 'Không thể kết nối đến máy chủ AI.',
          errorMessage: 'Lỗi mạng: Connection refused',
          sources: const [],
          isOfflineFallback: false,
        ),
      );
      final chat = ChatProvider(apiService: api);
      addTearDown(chat.dispose);

      final key = GlobalKey();
      await tester.pumpWidget(
        wrapWithChatProviders(
          child: const ChatScreen(),
          chat: chat,
          repaintKey: key,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Quy định về hạ bậc tốt nghiệp?'));
      await tester.pumpAndSettle();

      // Assertions
      expect(find.text('Lỗi mạng: Connection refused'), findsOneWidget);
      expect(find.text('Gửi lại'), findsOneWidget);

      await _captureScreen(tester, key, 'chat_send_error_390x844_light');
    });

    testWidgets('Offline State - Slim 1-line ServerStatusBar', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final api = MockChatApiService(isOnline: false);
      final chat = ChatProvider(apiService: api);
      addTearDown(chat.dispose);

      final key = GlobalKey();
      await tester.pumpWidget(
        wrapWithChatProviders(
          child: const ChatScreen(),
          chat: chat,
          repaintKey: key,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      // Assertions
      expect(find.text('Trợ lý ngoại tuyến'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
      // Verify ServerStatusBar is rendered
      expect(find.byType(ServerStatusBar), findsOneWidget);

      await _captureScreen(tester, key, 'chat_offline_390x844_light');
    });

    testWidgets('Keyboard Safe - ViewInsets bottom 280 applied without overflow', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final api = MockChatApiService(isOnline: true);
      final chat = ChatProvider(apiService: api);
      addTearDown(chat.dispose);

      final key = GlobalKey();
      await tester.pumpWidget(
        wrapWithChatProviders(
          child: const ChatScreen(),
          chat: chat,
          viewInsets: const EdgeInsets.only(bottom: 280),
          repaintKey: key,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      // Verify no exception / overflow
      expect(tester.takeException(), isNull);
      await _captureScreen(tester, key, 'chat_keyboard_open_390x844_light');
    });

    testWidgets('Clear History - Confirmation Dialog', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final api = MockChatApiService(isOnline: true);
      final chat = ChatProvider(apiService: api);
      addTearDown(chat.dispose);

      final key = GlobalKey();
      await tester.pumpWidget(
        wrapWithChatProviders(
          child: const ChatScreen(),
          chat: chat,
          repaintKey: key,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      // Open overflow menu
      await tester.tap(find.byTooltip('Tùy chọn hội thoại'));
      await tester.pumpAndSettle();

      // Tap 'Xóa hội thoại'
      await tester.tap(find.text('Xóa hội thoại'));
      await tester.pumpAndSettle();

      // Assertions
      expect(find.text('Xóa toàn bộ cuộc trò chuyện?'), findsOneWidget);
      expect(find.text('Hủy'), findsOneWidget);
      expect(find.text('Xóa'), findsOneWidget);

      await _captureScreen(tester, key, 'chat_delete_confirm_dialog_390x844_light');

      // Dismiss dialog
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(find.text('Xóa toàn bộ cuộc trò chuyện?'), findsNothing);
    });
  });

  group('Phase 3b - ContextualChatPanel', () {
    testWidgets('Empty State - Title Case, Drag Handle, Context Chip, 4 Suggestion Chips', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final api = MockChatApiService(isOnline: true);
      final chat = ChatProvider(apiService: api);
      addTearDown(chat.dispose);

      final key = GlobalKey();
      await tester.pumpWidget(
        wrapWithChatProviders(
          child: Scaffold(
            body: ContextualChatPanel(
              scope: 'subject',
              scopeId: 'PRM393',
              title: 'trợ lý môn PRM393',
              contextHint: 'Lập trình di động Flutter · Kỳ 5 · 3 tín chỉ',
              onClose: () {},
            ),
          ),
          chat: chat,
          repaintKey: key,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      // Assertions
      // Correct Title: "Trợ lý môn PRM393"
      expect(find.text('Trợ lý môn PRM393'), findsOneWidget);
      expect(find.text('Lập trình di động Flutter · Kỳ 5 · 3 tín chỉ'), findsOneWidget);
      expect(find.text('Môn: PRM393'), findsOneWidget);
      // 4 contextual question chips
      expect(find.text('Môn PRM393 có thi PE không?'), findsOneWidget);
      expect(find.text('Mục tiêu môn học (LOs) là gì?'), findsOneWidget);
      expect(find.text('Tư vấn cách học môn này theo mục tiêu của tôi?'), findsOneWidget);
      expect(find.text('Môn này có tính vào GPA không?'), findsOneWidget);

      await _captureScreen(tester, key, 'contextual_sheet_empty_390x844_light');
    });

    testWidgets('Empty State - Dark Mode & Scale 1.3', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final api = MockChatApiService(isOnline: true);
      final chat = ChatProvider(apiService: api);
      addTearDown(chat.dispose);

      final keyDark = GlobalKey();
      await tester.pumpWidget(
        wrapWithChatProviders(
          child: Scaffold(
            body: ContextualChatPanel(
              scope: 'subject',
              scopeId: 'PRM393',
              title: 'trợ lý môn PRM393',
              contextHint: 'Lập trình di động Flutter · Kỳ 5 · 3 tín chỉ',
              onClose: () {},
            ),
          ),
          chat: chat,
          isDark: true,
          repaintKey: keyDark,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();
      await _captureScreen(tester, keyDark, 'contextual_sheet_empty_390x844_dark');

      final keyScale = GlobalKey();
      await tester.pumpWidget(
        wrapWithChatProviders(
          child: Scaffold(
            body: ContextualChatPanel(
              scope: 'subject',
              scopeId: 'PRM393',
              title: 'trợ lý môn PRM393',
              contextHint: 'Lập trình di động Flutter · Kỳ 5 · 3 tín chỉ',
              onClose: () {},
            ),
          ),
          chat: chat,
          textScale: 1.3,
          repaintKey: keyScale,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _captureScreen(tester, keyScale, 'contextual_sheet_empty_390x844_scale13');
    });

    testWidgets('Populated State - Chips collapse to horizontal scroll row above input', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final api = MockChatApiService(
        isOnline: true,
        responseResult: ChatResponseResult(
          answer: 'Môn PRM393 có bài thi thực hành Practical Exam (PE) chiếm 30% trọng số điểm.',
          sources: const ['FLM Syllabus PRM393'],
          isOfflineFallback: false,
        ),
      );
      final chat = ChatProvider(apiService: api);
      addTearDown(chat.dispose);

      final key = GlobalKey();
      await tester.pumpWidget(
        wrapWithChatProviders(
          child: Scaffold(
            body: ContextualChatPanel(
              scope: 'subject',
              scopeId: 'PRM393',
              title: 'trợ lý môn PRM393',
              contextHint: 'Lập trình di động Flutter · Kỳ 5 · 3 tín chỉ',
              onClose: () {},
            ),
          ),
          chat: chat,
          repaintKey: key,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on a question chip
      await tester.tap(find.text('Môn PRM393 có thi PE không?'));
      await tester.pumpAndSettle();

      // In populated state:
      // 1. Message list shows user question & AI answer
      expect(find.text('Môn PRM393 có thi PE không?'), findsNWidgets(2));
      expect(find.textContaining('chiếm 30% trọng số điểm'), findsOneWidget);

      // 2. Chips collapsed into horizontal scroll row above input bar
      expect(find.descendant(of: find.byType(ActionChip), matching: find.text('Môn PRM393 có thi PE không?')), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsWidgets);

      await _captureScreen(tester, key, 'contextual_sheet_populated_390x844_light');

      // Compact 360x640
      final keyCompact = GlobalKey();
      await tester.pumpWidget(
        wrapWithChatProviders(
          child: Scaffold(
            body: ContextualChatPanel(
              scope: 'subject',
              scopeId: 'PRM393',
              title: 'trợ lý môn PRM393',
              contextHint: 'Lập trình di động Flutter · Kỳ 5 · 3 tín chỉ',
              onClose: () {},
            ),
          ),
          chat: chat,
          viewport: const Size(360, 640),
          repaintKey: keyCompact,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _captureScreen(tester, keyCompact, 'contextual_sheet_populated_360x640_light');

      // Wide 630x900
      final keyWide = GlobalKey();
      await tester.pumpWidget(
        wrapWithChatProviders(
          child: Scaffold(
            body: ContextualChatPanel(
              scope: 'subject',
              scopeId: 'PRM393',
              title: 'trợ lý môn PRM393',
              contextHint: 'Lập trình di động Flutter · Kỳ 5 · 3 tín chỉ',
              onClose: () {},
            ),
          ),
          chat: chat,
          viewport: const Size(630, 900),
          repaintKey: keyWide,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _captureScreen(tester, keyWide, 'contextual_sheet_populated_630x900_light');
    });
  });
}
