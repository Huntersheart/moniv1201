import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'data/remote/firebase_service.dart';

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
    try {
      final initial = await AppLinks()
          .getInitialLink()
          .timeout(const Duration(seconds: 5));
      _capturePasswordResetFromUri(initial);
    } on TimeoutException {
      // Avoid blocking launch if the platform never completes the initial link.
    } catch (_) {}
  }
  runApp(const App());
}
