import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../models/cloud_notification.dart';
import 'app_telemetry.dart';

class PushService extends ChangeNotifier {
  PushService(this._messaging, this._auth, this._db, this._telemetry);

  final FirebaseMessaging _messaging;
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final AppTelemetry _telemetry;
  final List<CloudNotification> _items = [];
  StreamSubscription<RemoteMessage>? _foreground;
  StreamSubscription<RemoteMessage>? _opened;
  String? token;
  String? error;

  List<CloudNotification> get items => List.unmodifiable(_items);

  Future<void> start() async {
    _foreground ??= FirebaseMessaging.onMessage.listen(_receive);
    _opened ??= FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _receive(message, opened: true),
    );
    final initial = await _messaging.getInitialMessage();
    if (initial != null) await _receive(initial, opened: true);
  }

  Future<NotificationSettings> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      final registration = _messaging.onRegistered.first.timeout(
        const Duration(seconds: 20),
      );
      await _messaging.register();
      token = await registration;
    }
    notifyListeners();
    return settings;
  }

  Future<void> _receive(RemoteMessage message, {bool opened = false}) async {
    final uid = _auth.currentUser?.uid;
    final item = CloudNotification(
      id: message.messageId ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: message.notification?.title ?? 'Thông báo FLM',
      body: message.notification?.body ?? '',
      receivedAt: message.sentTime ?? DateTime.now(),
      destination: message.data['destination']?.toString(),
      courseCode: message.data['course_code']?.toString(),
      read: opened,
    );
    _items.removeWhere((value) => value.id == item.id);
    _items.insert(0, item);
    notifyListeners();
    if (uid != null) {
      try {
        await _db
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .doc(item.id)
            .set(item.toJson());
      } catch (_) {
        error = 'Đã nhận thông báo nhưng chưa đồng bộ được lịch sử.';
        notifyListeners();
      }
    }
    if (opened) {
      await _telemetry.event('notification_open', {
        'destination': item.destination ?? 'unknown',
      });
    }
  }

  @override
  void dispose() {
    _foreground?.cancel();
    _opened?.cancel();
    super.dispose();
  }
}
