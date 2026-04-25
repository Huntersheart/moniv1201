import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../data/models/user_model.dart';
import '../../data/remote/firebase_service.dart';
import '../../data/repositories/auth_repository.dart';

class AuthController extends GetxController {
  final AuthRepository _repo;

  AuthController(this._repo);

  final isLoading = false.obs;
  /// Email/password login only — so Google button does not show a spinner.
  final isEmailLoginLoading = false.obs;
  /// Google sign-in only — so Login button does not show a spinner.
  final isGoogleLoginLoading = false.obs;
  /// Email/password registration only.
  final isRegisterLoading = false.obs;
  final Rxn<UserModel> currentUser = Rxn<UserModel>();

  StreamSubscription<User?>? _authStateSub;
  StreamSubscription<UserModel?>? _profileSub;
  bool _isRecoveringProfilePermission = false;

  @override
  void onInit() {
    super.onInit();
    try {
      _authStateSub?.cancel();
      _authStateSub = _repo.authStateChanges.listen((firebaseUser) async {
        if (firebaseUser != null) {
          // Force a token refresh so subsequent Firestore calls pass auth rules.
          try {
            await firebaseUser.getIdToken(true);
          } catch (_) {}
          try {
            final profile = await _repo.getCurrentUserProfile();
            currentUser.value =
                profile ?? _repo.fallbackUserFromAuth(firebaseUser);
          } catch (e, st) {
            debugPrint('[Auth] Firestore profile sync failed: $e\n$st');
            currentUser.value = _repo.fallbackUserFromAuth(firebaseUser);
          }
          // Subscribe to live Firestore profile so any change in `users/{uid}`
          // is reflected in the app instantly.
          _profileSub?.cancel();
          _profileSub = _repo.watchUserProfile(firebaseUser.uid).listen(
            (profile) {
              if (profile != null) currentUser.value = profile;
            },
            onError: (Object e) {
              debugPrint('[Auth] live profile error: $e');
              if (_isPermissionDenied(e)) {
                _recoverProfileStreamAfterPermissionDenied(firebaseUser);
              }
            },
          );
        } else {
          _profileSub?.cancel();
          _profileSub = null;
          currentUser.value = null;
        }
      });
    } catch (e) {
      // Firebase not initialized yet — UI-only mode
    }
  }

  /// Live Firestore stream for the current user's profile document.
  /// Use with [StreamBuilder] anywhere you need real-time user data.
  Stream<UserModel?> get userProfileStream {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return const Stream.empty();
    return _repo.watchUserProfile(uid);
  }

  @override
  void onClose() {
    _authStateSub?.cancel();
    _profileSub?.cancel();
    super.onClose();
  }

  bool _isPermissionDenied(Object e) =>
      e.toString().toLowerCase().contains('permission-denied');

  void _recoverProfileStreamAfterPermissionDenied(User firebaseUser) {
    if (_isRecoveringProfilePermission) return;
    _isRecoveringProfilePermission = true;
    Future<void>(() async {
      try {
        await firebaseUser.getIdToken(true);
      } catch (_) {
        return;
      } finally {
        _isRecoveringProfilePermission = false;
      }
      if (FirebaseAuth.instance.currentUser?.uid != firebaseUser.uid) return;
      _profileSub?.cancel();
      _profileSub = _repo.watchUserProfile(firebaseUser.uid).listen(
        (profile) {
          if (profile != null) currentUser.value = profile;
        },
        onError: (Object e) => debugPrint('[Auth] live profile retry error: $e'),
      );
    });
  }

  /// Creates the account, signs out immediately, then the UI shows success and
  /// routes to login so the user signs in explicitly.
  Future<bool> register({
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _snack('Validation', 'Email and both password fields are required.');
      return false;
    }
    if (password != confirmPassword) {
      _snack('Validation', 'Passwords do not match.');
      return false;
    }
    if (password.length < 6) {
      _snack('Validation', 'Password must be at least 6 characters.');
      return false;
    }
    if (!FirebaseService.isInitialized) {
      _snack('Not Configured',
          'Firebase is not set up yet. Run: flutterfire configure');
      return false;
    }
    isRegisterLoading.value = true;
    try {
      await _repo.signUp(email: trimmed, password: password);
      await _repo.signOut();
      currentUser.value = null;
      return true;
    } catch (e) {
      _snack('Registration Failed', _friendlyError(e));
      return false;
    } finally {
      isRegisterLoading.value = false;
    }
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
    isEmailLoginLoading.value = true;
    try {
      final user = await _repo.signIn(email: email, password: password);
      currentUser.value = user;
      Get.offAllNamed(AppRoutes.home);
    } catch (e) {
      _snack('Login Failed', _friendlyError(e));
    } finally {
      isEmailLoginLoading.value = false;
    }
  }

  Future<void> loginWithGoogle() async {
    if (!FirebaseService.isInitialized) {
      _snack('Not Configured',
          'Firebase is not set up yet. Run: flutterfire configure');
      return;
    }
    isGoogleLoginLoading.value = true;
    try {
      final user = await _repo.signInWithGoogle();
      currentUser.value = user;
      Get.offAllNamed(AppRoutes.home);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('cancelled')) return;
      _snack('Google Sign-In Failed', _friendlyError(e));
    } finally {
      isGoogleLoginLoading.value = false;
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
      _snack(
        'Email sent',
        'Check your inbox and tap the link to set a new password.',
      );
      Get.offAllNamed(AppRoutes.login);
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
    _profileSub?.cancel();
    _profileSub = null;
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
