import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/firestore_personal_data_repository.dart';
import '../data/personal_data_repository.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../firebase_options.dart';
import '../screens/sign_in_screen.dart';
import '../services/auth_service.dart';
import '../services/firebase_app_telemetry.dart';
import '../services/push_service.dart';
import '../services/report_service.dart';
import '../state/auth_view_model.dart';
import '../state/feature_config.dart';
import '../theme/app_theme.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  final database = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'flm-app',
  );
  final id =
      message.messageId ?? DateTime.now().microsecondsSinceEpoch.toString();
  await database
      .collection('users')
      .doc(user.uid)
      .collection('notifications')
      .doc(id)
      .set({
        'id': id,
        'title': message.notification?.title ?? 'Thông báo FLM',
        'body': message.notification?.body ?? '',
        'receivedAt': (message.sentTime ?? DateTime.now())
            .toUtc()
            .toIso8601String(),
        'destination': message.data['destination']?.toString(),
        'courseCode': message.data['course_code']?.toString(),
        'read': false,
      });
}

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
      final app = await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await _configureCrashReporting();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      return app;
    }
    final app = await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        projectId: projectId,
        messagingSenderId: senderId,
        authDomain: domain == '' ? null : domain,
      ),
    );
    await _configureCrashReporting();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    return app;
  }

  Future<void> _configureCrashReporting() async {
    if (kIsWeb) return;
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb && Uri.base.queryParameters.containsKey('demo')) {
      return const FlmApp();
    }
    return FutureBuilder<FirebaseApp>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final database = FirebaseFirestore.instanceFor(
            app: snapshot.data!,
            databaseId: 'flm-app',
          );
          database.settings = const Settings(persistenceEnabled: false);
          final telemetry = FirebaseAppTelemetry(
            FirebaseAnalytics.instanceFor(app: snapshot.data!),
            FirebaseCrashlytics.instance,
          );
          final featureConfig = FeatureConfig(
            FirebaseRemoteConfig.instanceFor(app: snapshot.data!),
          )..initialize();
          final push = PushService(
            FirebaseMessaging.instance,
            FirebaseAuth.instanceFor(app: snapshot.data!),
            database,
            telemetry,
          )..start();
          return MultiProvider(
            providers: [
              Provider<FirebaseAppTelemetry>.value(value: telemetry),
              Provider<ReportService>(
                create: (_) => ReportService(
                  FirebaseStorage.instanceFor(app: snapshot.data!),
                  database,
                ),
              ),
              ChangeNotifierProvider<FeatureConfig>.value(value: featureConfig),
              ChangeNotifierProvider<PushService>.value(value: push),
              Provider<PersonalDataFactory>(
                create: (_) =>
                    (uid) => FirestorePersonalDataRepository(database, uid),
              ),
              ChangeNotifierProvider(
                create: (_) => AuthViewModel(
                  FirebaseAuthService(
                    FirebaseAuth.instanceFor(app: snapshot.data!),
                  ),
                  onIdentityChanged: (uid) async {
                    await telemetry.setUser(uid);
                    if (uid != null) {
                      await telemetry.event('login', {'method': 'google'});
                    }
                  },
                  beforeSignOut: () => telemetry.event('logout', const {}),
                ),
              ),
            ],
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
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    if (auth.status == AuthStatus.signedIn && auth.account != null) {
      return FlmApp(
        key: ValueKey(auth.account!.uid),
        storage: auth.storage,
        personalData: context.read<PersonalDataFactory?>()?.call(
          auth.account!.uid,
        ),
        telemetry: context.read<FirebaseAppTelemetry?>(),
      );
    }
    return MaterialApp(
      theme: AppTheme.lightTheme(),
      home: auth.status == AuthStatus.loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : const SignInScreen(),
    );
  }
}
