import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flm_courses/theme/app_theme.dart';
import 'package:flm_courses/state/theme_provider.dart';
import 'package:flm_courses/screens/settings_screen.dart';
import 'package:flm_courses/state/course_catalog.dart';
import 'package:flm_courses/state/learning_profile_provider.dart';
import 'package:flm_courses/state/transcript_provider.dart';
import 'package:flm_courses/state/auth_view_model.dart';
import 'package:flm_courses/features/chat/providers/chat_provider.dart';
import 'fixtures/phase3a_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeProvider Unit & Settings UI Tests', () {
    test('0. ThemeData.lerp between light and dark does not throw', () {
      expect(
        () => ThemeData.lerp(AppTheme.lightTheme(), AppTheme.darkTheme(), 0.5),
        returnsNormally,
      );
    });

    test('1. Default mode is system and persists when changed', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ThemeProvider();
      expect(provider.themeMode, ThemeMode.system);

      await provider.setThemeMode(ThemeMode.dark);
      expect(provider.themeMode, ThemeMode.dark);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('flm_app_theme_mode'), 'dark');

      final reloaded = ThemeProvider();
      await reloaded.load();
      expect(reloaded.themeMode, ThemeMode.dark);

      await reloaded.setThemeMode(ThemeMode.light);
      expect(reloaded.themeMode, ThemeMode.light);
      expect(prefs.getString('flm_app_theme_mode'), 'light');
    });

    testWidgets('2. SettingsScreen displays SegmentedButton and toggles theme', (tester) async {
      SharedPreferences.setMockInitialValues({'flm_app_theme_mode': 'light'});
      final themeProvider = ThemeProvider();
      await themeProvider.load();

      final catalog = CourseCatalog();
      await tester.runAsync(catalog.load);
      final profile = LearningProfileProvider();
      await profile.load();
      final transcript = TranscriptProvider();
      await transcript.load();
      final auth = AuthViewModel(TestAuthService());
      final chat = ChatProvider(profile: profile);

      await tester.binding.setSurfaceSize(const Size(400, 3200));

      await tester.pumpWidget(
        wrapWithTestProviders(
          child: const SettingsScreen(),
          catalog: catalog,
          profile: profile,
          transcript: transcript,
          auth: auth,
          chat: chat,
          viewport: const Size(400, 3200),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Appearance section exists
      expect(find.text('Giao diện'), findsOneWidget);
      expect(find.text('Chế độ hiển thị'), findsOneWidget);
      expect(find.byType(SegmentedButton<ThemeMode>), findsOneWidget);

      // Segments exist
      expect(find.text('Hệ thống'), findsOneWidget);
      expect(find.text('Sáng'), findsOneWidget);
      expect(find.text('Tối'), findsOneWidget);

      // Tap on 'Tối'
      await tester.tap(find.text('Tối'));
      await tester.pumpAndSettle();

      await tester.binding.setSurfaceSize(null);
    });
  });
}
