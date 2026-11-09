import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flm_courses/data/personal_preferences.dart';
import 'package:flm_courses/services/auth_service.dart';
import 'package:flm_courses/state/auth_view_model.dart';
import 'package:flm_courses/state/learning_profile_provider.dart';
import 'package:flm_courses/state/transcript_provider.dart';
import 'package:flm_courses/models/transcript_entry.dart';

class TestAuth implements AuthService {
  final controller = StreamController<AuthAccount?>.broadcast();
  bool failSignOut = false;
  AuthFailure? signInError;
  @override
  Stream<AuthAccount?> get changes => controller.stream;
  @override
  Future<void> signIn() async {
    if (signInError != null) throw signInError!;
    controller.add(const AuthAccount(uid: 'A'));
  }

  @override
  Future<void> signOut() async {
    if (failSignOut) throw const AuthFailure('Không thể đăng xuất.');
    controller.add(null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('profile and transcript never cross account namespaces', () async {
    final storageA = PersonalPreferences(uid: 'A');
    final a = LearningProfileProvider(storage: storageA);
    await a.update(courseGoal: 'high_score');
    final gradesA = TranscriptProvider(storage: storageA);
    await gradesA.save([
      TranscriptEntry(
        courseCode: 'PRO192',
        score: 8,
        credits: 3,
        semester: 1,
        isPassed: true,
      ),
    ]);
    final b = LearningProfileProvider(storage: PersonalPreferences(uid: 'B'));
    final gradesB = TranscriptProvider(storage: PersonalPreferences(uid: 'B'));
    await b.load();
    await gradesB.load();
    expect(b.courseGoal, isNull);
    expect(gradesB.entries, isEmpty);
    final reopened = TranscriptProvider(storage: PersonalPreferences(uid: 'A'));
    await reopened.load();
    expect(reopened.entries.single.courseCode, 'PRO192');
    a.dispose();
    b.dispose();
    gradesA.dispose();
    gradesB.dispose();
    reopened.dispose();
  });

  test(
    'legacy data is preserved but never adopted by a Google account',
    () async {
      final legacy = await PersonalPreferences().open();
      await legacy.setString(
        'flm_learning_profile_v1',
        '{"course_goal":"pass"}',
      );
      final signedIn = LearningProfileProvider(
        storage: PersonalPreferences(uid: 'A'),
      );
      await signedIn.load();
      expect(signedIn.courseGoal, isNull);
      expect(legacy.getString('flm_learning_profile_v1'), contains('pass'));
      signedIn.dispose();
    },
  );

  test(
    'clearing account blocks stale writes and preserves other accounts',
    () async {
      final storage = PersonalPreferences(uid: 'A');
      final a = await storage.open();
      final b = await PersonalPreferences(uid: 'B').open();
      await a.setString('chat', 'private');
      await b.setString('chat', 'other');
      final pending = a.setString('chat', 'stale');
      await storage.clearAccount();
      await pending;
      expect(await a.setString('chat', 'late response'), isFalse);
      expect(a.getString('chat'), isNull);
      expect(b.getString('chat'), 'other');
    },
  );

  test(
    'auth state, cancellation and logout clear only the active account',
    () async {
      final service = TestAuth();
      final vm = AuthViewModel(service);
      service.controller.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(vm.status, AuthStatus.signedOut);
      service.signInError = const AuthFailure('Bạn đã hủy đăng nhập.');
      await vm.signIn();
      expect(vm.message, contains('hủy'));
      expect(vm.account, isNull);
      service.signInError = null;
      await vm.signIn();
      await Future<void>.delayed(Duration.zero);
      expect(vm.account!.uid, 'A');
      final cache = await vm.storage!.open();
      await cache.setString('chat', 'private');
      await vm.signOut();
      await Future<void>.delayed(Duration.zero);
      expect(vm.status, AuthStatus.signedOut);
      expect(cache.getString('chat'), isNull);
      vm.dispose();
      await service.controller.close();
    },
  );

  test('failed logout keeps account cache writable for retry', () async {
    final service = TestAuth()..failSignOut = true;
    final vm = AuthViewModel(service);
    await vm.signIn();
    await Future<void>.delayed(Duration.zero);
    final cache = await vm.storage!.open();
    await cache.setString('chat', 'private');
    await vm.signOut();
    expect(vm.account!.uid, 'A');
    expect(cache.getString('chat'), 'private');
    expect(await cache.setString('chat', 'retry'), isTrue);
    expect(vm.message, contains('đăng xuất'));
    vm.dispose();
    await service.controller.close();
  });
}
