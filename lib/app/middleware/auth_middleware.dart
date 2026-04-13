import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../data/remote/firebase_service.dart';
import '../routes/app_routes.dart';

/// Requires Firebase Auth session for protected routes.
class AuthMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    if (!FirebaseService.isInitialized) {
      return null;
    }
    if (FirebaseAuth.instance.currentUser == null) {
      return const RouteSettings(name: AppRoutes.login);
    }
    return null;
  }
}
