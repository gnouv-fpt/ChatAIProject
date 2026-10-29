import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthAccount {
  const AuthAccount({required this.uid, this.name});
  final String uid;
  final String? name;
}

abstract interface class AuthService {
  Stream<AuthAccount?> get changes;
  Future<void> signIn();
  Future<void> signOut();
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
}

class FirebaseAuthService implements AuthService {
  FirebaseAuthService(this._auth);
  final FirebaseAuth _auth;
  Future<void>? _googleInitialization;

  @override
  Stream<AuthAccount?> get changes => _auth.authStateChanges().map(
    (user) => user == null
        ? null
        : AuthAccount(uid: user.uid, name: user.displayName),
  );

  @override
  Future<void> signIn() async {
    try {
      if (kIsWeb) {
        await _auth.signInWithPopup(GoogleAuthProvider());
      } else {
        const clientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
        await (_googleInitialization ??= GoogleSignIn.instance.initialize(
          serverClientId: clientId.isEmpty ? null : clientId,
        ));
        final account = await GoogleSignIn.instance.authenticate();
        final token = account.authentication.idToken;
        if (token == null) {
          throw const AuthFailure('Google chưa trả token. Vui lòng thử lại.');
        }
        await _auth.signInWithCredential(
          GoogleAuthProvider.credential(idToken: token),
        );
      }
    } on GoogleSignInException catch (error) {
      debugPrint('[AuthService] Google sign-in failed: ${error.code.name}');
      if (error.code == GoogleSignInExceptionCode.canceled) {
        // Android also reports canceled when the device has no Google account.
        throw const AuthFailure(
          'Đăng nhập đã bị hủy. Nếu máy chưa có tài khoản Google, '
          'hãy thêm tài khoản trong Cài đặt rồi thử lại.',
        );
      }
      throw const AuthFailure('Không thể đăng nhập Google. Vui lòng thử lại.');
    } on FirebaseAuthException catch (error) {
      // Codes only: Firebase messages may echo account details.
      debugPrint('[AuthService] Firebase sign-in failed: ${error.code}');
      if (kDebugMode) debugPrint('[AuthService] detail: ${error.message}');
      throw AuthFailure(switch (error.code) {
        'popup-closed-by-user' ||
        'cancelled-popup-request' => 'Bạn đã hủy đăng nhập.',
        'network-request-failed' => 'Mất kết nối. Kiểm tra mạng rồi thử lại.',
        'operation-not-allowed' => 'Google Sign-In chưa được bật cho project.',
        'unauthorized-domain' => 'Tên miền chưa được cấp quyền đăng nhập.',
        _ => 'Không thể đăng nhập. Vui lòng thử lại.',
      });
    }
  }

  @override
  Future<void> signOut() async {
    // Firebase is the application identity; revoke it even if Google cleanup fails.
    await _auth.signOut();
    if (!kIsWeb && _googleInitialization != null) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // The app session is already closed.
      }
    }
  }
}
