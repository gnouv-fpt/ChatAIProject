import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../screens/sign_in_screen.dart';
import '../services/auth_service.dart';
import '../state/auth_view_model.dart';
import '../theme/app_theme.dart';

/// Production entry always passes through authentication, including deep links.
class FirebaseEntry extends StatefulWidget {
  const FirebaseEntry({super.key});
  @override
  State<FirebaseEntry> createState() => _FirebaseEntryState();
}

class _FirebaseEntryState extends State<FirebaseEntry> {
  late Future<FirebaseApp> _initialization = _initialize();

  Future<FirebaseApp> _initialize() async {
    if (Firebase.apps.isNotEmpty) return Firebase.app();
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    const domain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
    if ([apiKey, appId, projectId, senderId].any((value) => value.isEmpty)) {
      throw StateError('Firebase configuration is missing.');
    }
    return Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        projectId: projectId,
        messagingSenderId: senderId,
        authDomain: domain == '' ? null : domain,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<FirebaseApp>(
    future: _initialization,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return ChangeNotifierProvider(
          create: (_) => AuthViewModel(
            FirebaseAuthService(FirebaseAuth.instanceFor(app: snapshot.data!)),
          ),
          child: const AuthGate(),
        );
      }
      return MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: snapshot.hasError
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Chưa kết nối được Firebase. Kiểm tra cấu hình project và kết nối mạng.',
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => setState(() {
                            _initialization = _initialize();
                          }),
                          child: const Text('Thử lại'),
                        ),
                      ],
                    )
                  : const CircularProgressIndicator(),
            ),
          ),
        ),
      );
    },
  );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    if (auth.status == AuthStatus.signedIn && auth.account != null) {
      return FlmApp(key: ValueKey(auth.account!.uid), storage: auth.storage);
    }
    return MaterialApp(
      theme: AppTheme.lightTheme(),
      home: auth.status == AuthStatus.loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : const SignInScreen(),
    );
  }
}
