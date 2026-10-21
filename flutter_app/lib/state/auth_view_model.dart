import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/personal_preferences.dart';
import '../services/auth_service.dart';

enum AuthStatus { loading, signedOut, signedIn, error }

class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._service) {
    _subscription = _service.changes.listen(
      (account) {
        if (this.account?.uid != account?.uid) {
          storage = account == null
              ? null
              : PersonalPreferences(uid: account.uid);
        }
        this.account = account;
        status = account == null ? AuthStatus.signedOut : AuthStatus.signedIn;
        notifyListeners();
      },
      onError: (Object error) {
        account = null;
        status = AuthStatus.error;
        message = 'Không thể kiểm tra phiên đăng nhập. Vui lòng thử lại.';
        notifyListeners();
      },
    );
  }

  final AuthService _service;
  late final StreamSubscription<AuthAccount?> _subscription;
  AuthAccount? account;
  PersonalPreferences? storage;
  AuthStatus status = AuthStatus.loading;
  String? message;
  bool busy = false;
  bool _disposed = false;

  Future<void> signIn() => _run(_service.signIn);

  Future<void> signOut() => _run(() async {
    final previousStorage = storage;
    previousStorage?.seal();
    try {
      await _service.signOut();
    } catch (_) {
      previousStorage?.reopen();
      rethrow;
    }
    await previousStorage?.clearAccount();
  });

  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    busy = true;
    message = null;
    notifyListeners();
    try {
      await action();
    } on AuthFailure catch (error) {
      message = error.message;
    } catch (_) {
      message = 'Không thể hoàn tất thao tác. Vui lòng thử lại.';
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
