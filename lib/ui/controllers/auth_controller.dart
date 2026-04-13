import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../data/models/user_model.dart';
import '../../data/remote/fcm_service.dart';
import '../../data/remote/firebase_service.dart';
import '../../data/repositories/auth_repository.dart';

class AuthController extends GetxController {
  final AuthRepository _repo;

  AuthController(this._repo);

  final isLoading = false.obs;
  final Rxn<UserModel> currentUser = Rxn<UserModel>();

  String _pendingEmail = '';
  String get pendingEmail => _pendingEmail;

  StreamSubscription<String>? _fcmTokenSub;

  @override
  void onInit() {
    super.onInit();
    try {
      _repo.authStateChanges.listen((firebaseUser) async {
        if (firebaseUser != null) {
          try {
            final profile = await _repo.getCurrentUserProfile();
            currentUser.value =
                profile ?? _repo.fallbackUserFromAuth(firebaseUser);
          } catch (e, st) {
            debugPrint('[Auth] Firestore profile sync failed: $e\n$st');
            currentUser.value = _repo.fallbackUserFromAuth(firebaseUser);
          }
          try {
            await _registerPushForUser(firebaseUser.uid);
          } catch (e, st) {
            debugPrint('[Auth] FCM registration failed: $e\n$st');
          }
        } else {
          _cancelPushRegistration();
          currentUser.value = null;
        }
      });
    } catch (e) {
      // Firebase not initialized yet — UI-only mode
    }
  }

  @override
  void onClose() {
    _cancelPushRegistration();
    super.onClose();
  }

  Future<void> _registerPushForUser(String uid) async {
    if (!FirebaseService.isInitialized) return;
    if (!Get.isRegistered<FcmService>()) return;
    _fcmTokenSub?.cancel();
    final fcm = Get.find<FcmService>();
    final token = await fcm.initialize();
    if (token != null && token.isNotEmpty) {
      await _repo.updateFcmToken(uid, token);
    }
    _fcmTokenSub = fcm.tokenRefreshStream.listen((t) {
      if (t.isNotEmpty) {
        _repo.updateFcmToken(uid, t);
      }
    });
  }

  void _cancelPushRegistration() {
    _fcmTokenSub?.cancel();
    _fcmTokenSub = null;
  }

  Future<void> login({required String email, required String password}) async {
    if (email.trim().isEmpty || password.isEmpty) {
      _snack('Validation', 'Email and password are required.');
      return;
    }
    if (!FirebaseService.isInitialized) {
      _snack('Not Configured',
          'Firebase is not set up yet. Run: flutterfire configure');
      return;
    }
    isLoading.value = true;
    try {
      final user = await _repo.signIn(email: email, password: password);
      currentUser.value = user;
      Get.offAllNamed(AppRoutes.home);
    } catch (e) {
      _snack('Login Failed', _friendlyError(e));
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> sendPasswordReset(String email) async {
    if (email.trim().isEmpty) {
      _snack('Validation', 'Please enter your email address.');
      return;
    }
    if (!FirebaseService.isInitialized) {
      _snack('Not Configured',
          'Firebase is not set up yet. Run: flutterfire configure');
      return;
    }
    isLoading.value = true;
    try {
      await _repo.sendPasswordResetEmail(email);
      _pendingEmail = email.trim();
      Get.toNamed(AppRoutes.verifyCode);
      _snack('Email Sent', 'Check your inbox for the reset link.');
    } catch (e) {
      _snack('Error', _friendlyError(e));
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> resendPasswordResetEmail() async {
    if (_pendingEmail.isEmpty) {
      _snack('Error', 'No email on file. Go back and enter your email.');
      return;
    }
    if (!FirebaseService.isInitialized) {
      _snack('Not Configured',
          'Firebase is not set up yet. Run: flutterfire configure');
      return;
    }
    isLoading.value = true;
    try {
      await _repo.sendPasswordResetEmail(_pendingEmail);
      _snack('Email Sent', 'Check your inbox for the reset link.');
    } catch (e) {
      _snack('Error', _friendlyError(e));
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> setNewPassword(
    String newPassword,
    String confirmPassword, {
    String? oobCode,
  }) async {
    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      _snack('Validation', 'Both password fields are required.');
      return;
    }
    if (newPassword != confirmPassword) {
      _snack('Validation', 'Passwords do not match.');
      return;
    }
    if (newPassword.length < 6) {
      _snack('Validation', 'Password must be at least 6 characters.');
      return;
    }
    final code = oobCode?.trim();
    if (code != null && code.isNotEmpty) {
      if (!FirebaseService.isInitialized) {
        _snack('Not Configured',
            'Firebase is not set up yet. Run: flutterfire configure');
        return;
      }
      isLoading.value = true;
      try {
        await _repo.confirmPasswordReset(code: code, newPassword: newPassword);
        _snack('Success', 'Password updated. Please sign in.');
        Get.offAllNamed(AppRoutes.login);
      } catch (e) {
        _snack('Error', _friendlyError(e));
      } finally {
        isLoading.value = false;
      }
      return;
    }

    if (FirebaseAuth.instance.currentUser == null) {
      _snack(
        'Reset link required',
        'Open the link from your email, or sign in to change your password.',
      );
      return;
    }
    isLoading.value = true;
    try {
      await _repo.updatePassword(newPassword);
      _snack('Success', 'Password updated successfully.');
      Get.offAllNamed(AppRoutes.home);
    } catch (e) {
      _snack('Error', _friendlyError(e));
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    _cancelPushRegistration();
    await _repo.signOut();
    currentUser.value = null;
    Get.offAllNamed(AppRoutes.login);
  }

  void _snack(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      backgroundColor: const Color(0xFF2A2A2A),
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('wrong-password') || msg.contains('invalid-credential')) {
      return 'Incorrect email or password.';
    }
    if (msg.contains('user-not-found')) {
      return 'No account found with this email.';
    }
    if (msg.contains('email-already-in-use')) {
      return 'This email is already registered.';
    }
    if (msg.contains('weak-password')) return 'Password is too weak.';
    if (msg.contains('expired-action-code') ||
        msg.contains('invalid-action-code')) {
      return 'This reset link has expired. Request a new one.';
    }
    if (msg.contains('network')) return 'Network error. Check your connection.';
    if (msg.contains('too-many-requests')) {
      return 'Too many attempts. Try again later.';
    }
    return 'Something went wrong. Please try again.';
  }
}
