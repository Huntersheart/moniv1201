import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'data/remote/firebase_service.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void _capturePasswordResetFromUri(Uri? uri) {
  if (uri == null) return;
  final mode = uri.queryParameters['mode'];
  final oobCode = uri.queryParameters['oobCode'];
  if (mode == 'resetPassword' && oobCode != null && oobCode.isNotEmpty) {
    FirebaseService.pendingPasswordResetOobCode = oobCode;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.initialize();
  if (FirebaseService.isInitialized) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    try {
      final initial = await AppLinks().getInitialLink();
      _capturePasswordResetFromUri(initial);
    } catch (_) {}
  }
  runApp(const App());
}
