// File generated for Firebase project rizz-4d335.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDSN3RMnB-B0SDnYdlrGbM3r0HZofaDqzw',
    appId: '1:837305453018:android:6a877fe21bbfddfb1958e3',
    messagingSenderId: '837305453018',
    projectId: 'rizz-4d335',
    storageBucket: 'rizz-4d335.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDSN3RMnB-B0SDnYdlrGbM3r0HZofaDqzw',
    appId: '1:837305453018:ios:6a877fe21bbfddfb1958e3',
    messagingSenderId: '837305453018',
    projectId: 'rizz-4d335',
    storageBucket: 'rizz-4d335.firebasestorage.app',
    iosBundleId: 'com.kvstudio.rizz',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDSN3RMnB-B0SDnYdlrGbM3r0HZofaDqzw',
    appId: '1:837305453018:web:6a877fe21bbfddfb1958e3',
    messagingSenderId: '837305453018',
    projectId: 'rizz-4d335',
    storageBucket: 'rizz-4d335.firebasestorage.app',
  );
}
