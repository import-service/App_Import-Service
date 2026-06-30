import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Конфиг из Firebase Console / google-services.json (project import-service-f736b).
/// После добавления SHA-1 в консоли — перекачайте google-services.json и сверьте appId/apiKey.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web FCM не настроен.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'Firebase не настроен для $defaultTargetPlatform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD8IHK34e44iRTGUj2f4DsFpaU3_Kyc7pw',
    appId: '1:709308120184:android:499437c6795989b10a418d',
    messagingSenderId: '709308120184',
    projectId: 'import-service-f736b',
    storageBucket: 'import-service-f736b.firebasestorage.app',
  );

  /// iOS app import-service-f736b (GoogleService-Info.plist).
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCa_jjflaDsD7kkBC14ZO9_Yw7vfRg-uGk',
    appId: '1:709308120184:ios:a6a2527990ee4b170a418d',
    messagingSenderId: '709308120184',
    projectId: 'import-service-f736b',
    storageBucket: 'import-service-f736b.firebasestorage.app',
    iosBundleId: 'com.importservice.app',
  );
}
