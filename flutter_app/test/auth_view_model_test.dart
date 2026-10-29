import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flm_courses/app/firebase_entry.dart';
import 'package:flm_courses/screens/sign_in_screen.dart';
import 'package:flm_courses/services/auth_service.dart';
import 'package:flm_courses/state/auth_view_model.dart';

class ScriptedAuth implements AuthService {
  final controller = StreamController<AuthAccount?>.broadcast();
  final failures = <Object>[];
  Completer<void>? pendingSignIn;
  int signInCalls = 0;

  @override
  Stream<AuthAccount?> get changes => controller.stream;

  @override
  Future<void> signIn() async {
    signInCalls++;
    if (pendingSignIn != null) await pendingSignIn!.future;
    if (failures.isNotEmpty) throw failures.removeAt(0);
    controller.add(const AuthAccount(uid: 'A', name: 'Sinh viên A'));
  }

  @override
  Future<void> signOut() async => controller.add(null);
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('starts loading until the first auth event arrives', () async {
    final service = ScriptedAuth();
    final vm = AuthViewModel(service);
    expect(vm.status, AuthStatus.loading);
    service.controller.add(null);
    await settle();
    expect(vm.status, AuthStatus.signedOut);
    vm.dispose();
    await service.controller.close();
  });

  test('cancelled sign-in reports clearly and retry succeeds', () async {
    final service = ScriptedAuth()
      ..failures.add(const AuthFailure('Bạn đã hủy đăng nhập.'));
    final vm = AuthViewModel(service);
    service.controller.add(null);
    await vm.signIn();
    await settle();
    expect(vm.status, AuthStatus.signedOut);
    expect(vm.message, 'Bạn đã hủy đăng nhập.');
    expect(vm.busy, isFalse);

    await vm.signIn();
    await settle();
    expect(vm.status, AuthStatus.signedIn);
    expect(vm.account!.uid, 'A');
    expect(vm.message, isNull);
    vm.dispose();
    await service.controller.close();
  });

  test('network failure keeps user signed out with a retryable message', () async {
    final service = ScriptedAuth()
      ..failures.add(
        const AuthFailure('Mất kết nối. Kiểm tra mạng rồi thử lại.'),
      );
    final vm = AuthViewModel(service);
    service.controller.add(null);
    await vm.signIn();
    expect(vm.account, isNull);
    expect(vm.message, contains('Mất kết nối'));
    vm.dispose();
    await service.controller.close();
  });

  test('unexpected errors never leak raw exception text', () async {
    final service = ScriptedAuth()
      ..failures.add(StateError('PlatformException(sign_in_failed, 10)'));
    final vm = AuthViewModel(service);
    await vm.signIn();
    expect(vm.message, 'Không thể hoàn tất thao tác. Vui lòng thử lại.');
    vm.dispose();
    await service.controller.close();
  });

  test('double tap starts only one Google sign-in', () async {
    final service = ScriptedAuth()..pendingSignIn = Completer<void>();
    final vm = AuthViewModel(service);
    final first = vm.signIn();
    final second = vm.signIn();
    expect(vm.busy, isTrue);
    service.pendingSignIn!.complete();
    await Future.wait([first, second]);
    expect(service.signInCalls, 1);
    vm.dispose();
    await service.controller.close();
  });

  test('auth stream error shows a message and sign-in can recover', () async {
    final service = ScriptedAuth();
    final vm = AuthViewModel(service);
    service.controller.addError(Exception('token refresh failed'));
    await settle();
    expect(vm.status, AuthStatus.error);
    expect(vm.message, isNotNull);
    await vm.signIn();
    await settle();
    expect(vm.status, AuthStatus.signedIn);
    vm.dispose();
    await service.controller.close();
  });

  testWidgets('logout replaces the app so Back cannot reopen private pages', (
    tester,
  ) async {
    final service = ScriptedAuth();
    final vm = AuthViewModel(service);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: vm, child: const AuthGate()),
    );
    service.controller.add(const AuthAccount(uid: 'A'));
    await tester.pump();
    expect(find.byType(SignInScreen), findsNothing);

    await vm.signOut();
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsOneWidget);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(await navigator.maybePop(), isFalse);
    expect(find.byType(SignInScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    vm.dispose();
    await service.controller.close();
  });
}
