import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../../firebase_options.dart';

class FirebaseService {
  FirebaseService._();

  static bool isInitialized = false;

  /// Set from a cold-start app link before [SplashView] routes (password reset).
  static String? pendingPasswordResetOobCode;

  /// Registers an App Check provider so Storage / other Firebase SDKs stop logging
  /// `No AppCheckProvider installed`. Debug builds use the debug provider; release
  /// uses Play Integrity (Android) / Device Check (Apple).
  ///
  /// If you see **403** / API errors, enable **Firebase App Check API** for the project:
  /// https://console.developers.google.com/apis/api/firebaseappcheck.googleapis.com/overview?project=190818522498
  /// Then in Firebase Console → App Check, register the **debug token** printed on
  /// first run (Logcat: `AppCheck debug token:`) when using enforcement.
  static Future<void> _activateAppCheck() async {
    if (kIsWeb) {
      // Add ReCaptchaEnterpriseProvider / ReCaptchaV3Provider here if you ship web.
      return;
    }
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider:
            kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        appleProvider:
            kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
      );
    } catch (e) {
      debugPrint('[Firebase] App Check activate failed: $e');
    }
  }

  static Future<void> initialize() async {
    // Skip init if the options are still placeholders
    final opts = DefaultFirebaseOptions.currentPlatform;
    if (opts.projectId.startsWith('YOUR_') ||
        opts.projectId.isEmpty ||
        opts.apiKey.startsWith('YOUR_')) {
      debugPrint(
        '[Firebase] Placeholder credentials detected — skipping init.\n'
        'Run: dart pub global activate flutterfire_cli && flutterfire configure',
      );
      return;
    }

    try {
      await Firebase.initializeApp(options: opts);
      await _activateAppCheck();
      isInitialized = true;
      debugPrint('[Firebase] Initialized successfully.');
    } catch (e) {
      isInitialized = false;
      debugPrint('[Firebase] Initialization failed: $e');
    }
  }
}
