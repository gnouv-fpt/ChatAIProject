import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'app_telemetry.dart';

class FirebaseAppTelemetry implements AppTelemetry {
  FirebaseAppTelemetry(this._analytics, this._crashlytics);

  final FirebaseAnalytics _analytics;
  final FirebaseCrashlytics _crashlytics;

  static const allowedEvents = <String>{
    'login',
    'logout',
    'search',
    'view_course',
    'view_curriculum',
    'transcript_import',
    'transcript_import_error',
    'advising_request',
    'export_report',
    'upload_report',
    'notification_open',
  };

  Future<void> setUser(String? uid) async {
    await _analytics.setUserId(id: uid);
    await _crashlytics.setUserIdentifier(uid ?? 'signed-out');
  }

  @override
  Future<void> event(String name, Map<String, Object?> properties) async {
    if (!allowedEvents.contains(name)) {
      throw ArgumentError.value(
        name,
        'name',
        'Sự kiện chưa có trong analytics-plan.',
      );
    }
    final sanitized = <String, Object>{};
    for (final entry in properties.entries) {
      final value = entry.value;
      if (value is String) {
        sanitized[entry.key] = value.substring(0, value.length.clamp(0, 100));
      } else if (value is num) {
        sanitized[entry.key] = value;
      }
    }
    await _analytics.logEvent(name: name, parameters: sanitized);
  }

  Future<void> nonFatal(
    Object error,
    StackTrace stack, {
    required String flow,
  }) async {
    await _crashlytics.setCustomKey('flow', flow);
    await _crashlytics.recordError(error, stack, fatal: false, reason: flow);
  }

  Future<void> testCrash() async {
    await _crashlytics.setCustomKey('flow', 'lab3_demo');
    _crashlytics.crash();
  }
}
