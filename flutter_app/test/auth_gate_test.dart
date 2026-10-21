import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flm_courses/app/firebase_entry.dart';
import 'package:flm_courses/screens/sign_in_screen.dart';
import 'package:flm_courses/services/auth_service.dart';
import 'package:flm_courses/state/auth_view_model.dart';

class SignedOutAuth implements AuthService {
  final events = StreamController<AuthAccount?>.broadcast();
  @override
  Stream<AuthAccount?> get changes => events.stream;
  @override
  Future<void> signIn() async =>
      throw const AuthFailure('Bạn đã hủy đăng nhập.');
  @override
  Future<void> signOut() async => events.add(null);
}

void main() {
  for (final width in [360.0, 412.0]) {
    testWidgets(
      'signed out gate blocks app and handles cancellation at $width dp',
      (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final service = SignedOutAuth();
        final vm = AuthViewModel(service);
        await tester.pumpWidget(
          ChangeNotifierProvider.value(value: vm, child: const AuthGate()),
        );
        service.events.add(null);
        await tester.pumpAndSettle();
        expect(find.byType(SignInScreen), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);
        await tester.tap(find.text('Đăng nhập với Google'));
        await tester.pumpAndSettle();
        expect(find.text('Bạn đã hủy đăng nhập.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        vm.dispose();
        await service.events.close();
      },
    );
  }
}
