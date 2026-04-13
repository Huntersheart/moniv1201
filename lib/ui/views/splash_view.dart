import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../data/remote/firebase_service.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  static const Color _background = Color(0xFF0B0B0B);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(seconds: 2), _navigate);
    });
  }

  void _navigate() {
    if (!mounted) return;

    final resetCode = FirebaseService.pendingPasswordResetOobCode;
    if (resetCode != null && resetCode.isNotEmpty) {
      FirebaseService.pendingPasswordResetOobCode = null;
      Get.offAllNamed(
        AppRoutes.createPassword,
        parameters: {'oobCode': resetCode},
      );
      return;
    }

    if (!FirebaseService.isInitialized) {
      // Firebase not configured yet — show onboarding
      Get.offNamed(AppRoutes.onboarding);
      return;
    }

    // Firebase ready — check if user is already logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      Get.offAllNamed(AppRoutes.home);
    } else {
      Get.offNamed(AppRoutes.onboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Image.asset(
              'assets/images/splash_image.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
