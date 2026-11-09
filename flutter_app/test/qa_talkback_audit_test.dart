import 'package:flm_courses/features/chat/providers/chat_provider.dart';
import 'package:flm_courses/screens/home_screen.dart';
import 'package:flm_courses/screens/roadmap_screen.dart';
import 'package:flm_courses/screens/transcript_screen.dart';
import 'package:flm_courses/screens/settings_screen.dart';
import 'package:flm_courses/features/chat/views/chat_screen.dart';
import 'package:flm_courses/state/auth_view_model.dart';
import 'package:flm_courses/state/course_catalog.dart';
import 'package:flm_courses/state/learning_profile_provider.dart';
import 'package:flm_courses/state/transcript_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/phase3a_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TalkBack & Semantics Comprehensive Audit across 5 tabs', () {
    testWidgets('Audit Semantics on Home, Roadmap, Transcript, Chat, and Settings', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final catalog = CourseCatalog();
      await tester.runAsync(catalog.load);
      final profile = LearningProfileProvider();
      await profile.load();
      final transcript = TranscriptProvider();
      await transcript.load();
      final auth = AuthViewModel(TestAuthService(userName: 'Khôi'));
      final chat = ChatProvider(apiService: OfflineChatService());

      addTearDown(() {
        catalog.dispose();
        profile.dispose();
        transcript.dispose();
        auth.dispose();
        chat.dispose();
      });

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.reset());

      final tabs = <String, Widget>{
        'Trang chủ': HomeScreen(onNavigate: (_) {}),
        'Lộ trình': const RoadmapScreen(),
        'Bảng điểm': const TranscriptScreen(),
        'Trợ lý': const ChatScreen(),
        'Cài đặt': const SettingsScreen(),
      };

      for (final entry in tabs.entries) {
        await tester.pumpWidget(
          wrapWithTestProviders(
            child: entry.value,
            catalog: catalog,
            profile: profile,
            transcript: transcript,
            auth: auth,
            chat: chat,
          ),
        );
        await tester.pumpAndSettle();

        // 1. Check all icon buttons have tooltip or semantic label
        final iconButtons = find.byType(IconButton);
        for (final element in iconButtons.evaluate()) {
          final widget = element.widget as IconButton;
          final tooltip = widget.tooltip;
          // In M3 IconButton should have tooltip or ancestor Semantics
          if (tooltip == null) {
            final hasSemantics = element.findAncestorWidgetOfExactType<Semantics>() != null;
            expect(hasSemantics || tooltip != null, isTrue,
                reason: '${entry.key}: IconButton without tooltip or Semantics label found');
          }
        }

        // 2. Check no raw debug/technical strings in semantic labels
        final semanticsOwner = tester.binding.rootPipelineOwner.semanticsOwner;
        if (semanticsOwner != null) {
          final root = semanticsOwner.rootSemanticsNode;
          if (root != null) {
            void visit(SemanticsNode node) {
              final label = node.label.toLowerCase();
              expect(label.contains('bit_se_k19b:'), isFalse,
                  reason: 'Found raw scopeId in semantics label: ${node.label}');
              expect(label.contains('firestore'), isFalse,
                  reason: 'Found internal database name in semantics label: ${node.label}');
              node.visitChildren((child) {
                visit(child);
                return true;
              });
            }
            visit(root);
          }
        }
      }
    });
  });
}
