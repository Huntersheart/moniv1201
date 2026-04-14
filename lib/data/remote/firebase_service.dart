import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../../firebase_options.dart';

class FirebaseService {
  FirebaseService._();

  /// App Check is **disabled in debug builds** by default to avoid the
  /// "Too many attempts" rate-limit on the debug-token exchange endpoint and
  /// the resulting placeholder-token rejections from Storage.
  ///
  /// To opt in during a debug session (e.g. to test enforcement rules):
  ///   `flutter run --dart-define=USE_APP_CHECK=true`
  ///
  /// Release / profile builds always enable App Check unless you explicitly
  /// pass `--dart-define=USE_APP_CHECK=false`.
  static const bool _appCheckEnabled = kDebugMode
      ? bool.fromEnvironment('USE_APP_CHECK', defaultValue: false)
      : bool.fromEnvironment('USE_APP_CHECK', defaultValue: true);

  static bool isInitialized = false;

  /// Set from a cold-start app link before [SplashView] routes (password reset).
  static String? pendingPasswordResetOobCode;

  /// Registers an App Check provider so Storage / other Firebase SDKs stop logging
  /// `No AppCheckProvider installed`. Debug builds use the debug provider; release
  /// uses Play Integrity (Android) / Device Check (Apple).
  ///
  /// **Fix 403 `Firebase App Check API has not been used...`:**
  /// 1. Enable: https://console.developers.google.com/apis/api/firebaseappcheck.googleapis.com/overview?project=190818522498
  /// 2. Wait 2–5 minutes, then cold-restart the app.
  /// 3. Firebase Console → App Check → your Android/iOS app → for debug builds, add the
  ///    **debug token** from Logcat (`AppCheck debug token:`) if you turn on enforcement.
  static Future<void> _activateAppCheck() async {
    if (kIsWeb) {
      // Add ReCaptchaEnterpriseProvider / ReCaptchaV3Provider here if you ship web.
      return;
    }
    if (!_appCheckEnabled) {
      debugPrint(
        '[Firebase] App Check skipped (USE_APP_CHECK=false). '
        'Enable the App Check API and remove this define for production.',
      );
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
