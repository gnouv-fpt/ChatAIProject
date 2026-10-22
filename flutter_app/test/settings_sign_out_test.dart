import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flm_courses/features/chat/providers/chat_provider.dart';
import 'package:flm_courses/features/chat/services/chat_api_service.dart';
import 'package:flm_courses/models/load_status.dart';
import 'package:flm_courses/screens/settings_screen.dart';
import 'package:flm_courses/services/auth_service.dart';
import 'package:flm_courses/state/auth_view_model.dart';
import 'package:flm_courses/state/learning_profile_provider.dart';

class OfflineChat extends ChatApiService {
  @override
  Future<bool> checkHealth() async => false;
}

class SignedInService implements AuthService {
  int signOutCalls = 0;
  @override
  Stream<AuthAccount?> get changes =>
      Stream.value(const AuthAccount(uid: 'test'));
  @override
  Future<void> signIn() async {}
  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}

void main() {
  for (final status in [LoadStatus.loading, LoadStatus.error]) {
    testWidgets('sign out remains usable while profile is $status', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final service = SignedInService();
      final auth = AuthViewModel(service);
      final profile = LearningProfileProvider()..status = status;
      final chat = ChatProvider(apiService: OfflineChat());
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: profile),
            ChangeNotifierProvider.value(value: chat),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();
      expect(find.text('Đăng xuất'), findsOneWidget);
      await tester.tap(find.text('Đăng xuất'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(service.signOutCalls, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
      profile.dispose();
      chat.dispose();
    });
  }
}
