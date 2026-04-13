import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class FcmService {
  // Getter — only accessed after Firebase.initializeApp() succeeds
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  static bool get _isApplePlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  /// iOS/macOS: FCM `getToken()` throws if APNS device token is not registered yet.
  Future<bool> _waitForApnsToken() async {
    const attempts = 40;
    const delay = Duration(milliseconds: 250);
    for (var i = 0; i < attempts; i++) {
      final apns = await _messaging.getAPNSToken();
      if (apns != null) return true;
      await Future<void>.delayed(delay);
    }
    return false;
  }

  Future<String?> initialize() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      return null;
    }

    if (_isApplePlatform) {
      final ready = await _waitForApnsToken();
      if (!ready) {
        if (kDebugMode) {
          debugPrint(
            '[FCM] APNS not ready; skipped getToken (normal on Simulator / '
            'before Push + APNs key setup). Token may arrive via onTokenRefresh.',
          );
        }
        return null;
      }
    }

    try {
      final token = await _messaging.getToken();
      if (kDebugMode && token != null && token.isNotEmpty) {
        final t = token;
        final preview = t.length > 24
            ? '${t.substring(0, 8)}…${t.substring(t.length - 6)} (${t.length} chars)'
            : '(${t.length} chars)';
        debugPrint('[FCM] Token registered $preview');
      }
      return token;
    } catch (e, st) {
      debugPrint('[FCM] getToken failed (will retry on token refresh): $e\n$st');
      return null;
    }
  }

  Stream<String> get tokenRefreshStream => _messaging.onTokenRefresh;

  void handleForegroundMessages(void Function(RemoteMessage) handler) {
    FirebaseMessaging.onMessage.listen(handler);
  }

  Future<RemoteMessage?> getInitialMessage() {
    return _messaging.getInitialMessage();
  }
}
