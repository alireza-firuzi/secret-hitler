import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return const FirebaseOptions(
        apiKey: String.fromEnvironment('FIREBASE_API_KEY', defaultValue: 'YOUR_API_KEY'),
        authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN', defaultValue: 'YOUR_AUTH_DOMAIN'),
        projectId: String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'YOUR_PROJECT_ID'),
        storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: 'YOUR_STORAGE_BUCKET'),
        messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: 'YOUR_MESSAGING_SENDER_ID'),
        appId: String.fromEnvironment('FIREBASE_APP_ID', defaultValue: 'YOUR_APP_ID'),
      );
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions are not configured for this platform.',
    );
  }
}
