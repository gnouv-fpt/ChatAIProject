// Public client configuration fetched from Firebase CLI. Access is enforced by rules.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    if (defaultTargetPlatform == TargetPlatform.android) return android;
    throw UnsupportedError('Firebase is configured for Android and Web only.');
  }

  static const web = FirebaseOptions(
    apiKey: 'AIzaSyDr_7LVtSOY1ZMpPQpZycMqUP1dzZ3kiDg',
    appId: '1:913094498381:web:1483e887b547305296e404',
    messagingSenderId: '913094498381',
    projectId: 'flm-prm323-20261021',
    authDomain: 'flm-prm323-20261021.firebaseapp.com',
    storageBucket: 'flm-prm323-20261021.firebasestorage.app',
  );
  static const android = FirebaseOptions(
    apiKey: 'AIzaSyBhm0lJ7kyDHy9DTj3mHR_WmNe3H_ZWP5w',
    appId: '1:913094498381:android:63cfdde887d3be1396e404',
    messagingSenderId: '913094498381',
    projectId: 'flm-prm323-20261021',
    storageBucket: 'flm-prm323-20261021.firebasestorage.app',
  );
}
