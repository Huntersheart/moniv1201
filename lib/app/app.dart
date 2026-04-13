import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../data/remote/firebase_service.dart';
import 'bindings/initial_binding.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  StreamSubscription<Uri>? _appLinkSub;
  final AppLinks _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _listenAppLinks();
  }

  void _listenAppLinks() {
    if (!FirebaseService.isInitialized) return;
    _appLinkSub = _appLinks.uriLinkStream.listen(
      _handleAuthUri,
      onError: (_) {},
    );
  }

  void _handleAuthUri(Uri uri) {
    final mode = uri.queryParameters['mode'];
    final oobCode = uri.queryParameters['oobCode'];
    if (mode != 'resetPassword' || oobCode == null || oobCode.isEmpty) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final route = Get.currentRoute;
      if (route == AppRoutes.splash || route == '/') {
        FirebaseService.pendingPasswordResetOobCode = oobCode;
        return;
      }
      Get.toNamed(AppRoutes.createPassword, parameters: {'oobCode': oobCode});
    });
  }

  @override
  void dispose() {
    _appLinkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialBinding: InitialBinding(),
      initialRoute: AppRoutes.splash,
      getPages: AppPages.routes,
    );
  }
}
