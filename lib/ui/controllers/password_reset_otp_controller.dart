import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../data/remote/firebase_service.dart';
import '../../data/remote/password_reset_cloud_service.dart';

/// GetX state for: Forgot email → OTP verify → New password (Cloud Functions + Admin SDK).
class PasswordResetOtpController extends GetxController {
  final PasswordResetCloudService _cloud = Get.find<PasswordResetCloudService>();

  final email = ''.obs;
  final resetToken = ''.obs;
  final isLoading = false.obs;
  /// Seconds until user can tap “Resend code” again (server also enforces cooldown).
  final resendCooldownSec = 0.obs;

  Timer? _cooldownTimer;

  static const int resendUiCooldownSec = 60;

  @override
  void onClose() {
    _cooldownTimer?.cancel();
    super.onClose();
  }

  void _snack(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      backgroundColor: const Color(0xFF2A2A2A),
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
    );
  }

  String _functionsMessage(Object e) {
    if (e is FirebaseFunctionsException) {
      return e.message ?? e.code;
    }
    return e.toString();
  }

  void startResendCooldown() {
    _cooldownTimer?.cancel();
    resendCooldownSec.value = resendUiCooldownSec;
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (resendCooldownSec.value <= 1) {
        resendCooldownSec.value = 0;
        t.cancel();
      } else {
        resendCooldownSec.value--;
      }
    });
  }

  Future<void> sendOtp(String rawEmail) async {
    final trimmed = rawEmail.trim();
    if (trimmed.isEmpty) {
      _snack('Validation', 'Please enter your email.');
      return;
    }
    if (!FirebaseService.isInitialized) {
      _snack('Not configured', 'Firebase is not set up yet.');
      return;
    }
    isLoading.value = true;
    try {
      final out = await _cloud.sendOtp(trimmed);
      if (!out.sent) {
        _snack('No account', out.message);
        return;
      }
      email.value = trimmed;
      _snack('Email sent', out.message);
      startResendCooldown();
      Get.toNamed(AppRoutes.verifyCode);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') {
        _snack('Please wait', _functionsMessage(e));
      } else {
        _snack('Error', _functionsMessage(e));
      }
    } catch (e) {
      _snack('Error', _functionsMessage(e));
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> resendOtp() async {
    if (email.value.isEmpty) {
      _snack('Error', 'Go back and enter your email first.');
      return;
    }
    if (resendCooldownSec.value > 0) return;
    isLoading.value = true;
    try {
      final out = await _cloud.sendOtp(email.value);
      if (!out.sent) {
        _snack('No account', out.message);
        return;
      }
      _snack('Email sent', out.message);
      startResendCooldown();
    } on FirebaseFunctionsException catch (e) {
      _snack('Error', _functionsMessage(e));
    } catch (e) {
      _snack('Error', _functionsMessage(e));
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> verifyOtpAndContinue(String rawOtp) async {
    final otp = rawOtp.replaceAll(RegExp(r'\D'), '');
    if (email.value.isEmpty) {
      _snack('Error', 'Missing email. Start from “Forgot password”.');
      return;
    }
    if (otp.length != 6) {
      _snack('Validation', 'Enter the 6-digit code from your email.');
      return;
    }
    isLoading.value = true;
    try {
      final out = await _cloud.verifyOtp(email: email.value, otp: otp);
      resetToken.value = out.resetToken;
      Get.toNamed(AppRoutes.createPassword);
    } on FirebaseFunctionsException catch (e) {
      _snack('Verification failed', _functionsMessage(e));
    } catch (e) {
      _snack('Error', _functionsMessage(e));
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> submitNewPassword(String newPass, String confirm) async {
    if (newPass.isEmpty || confirm.isEmpty) {
      _snack('Validation', 'Both password fields are required.');
      return;
    }
    if (newPass != confirm) {
      _snack('Validation', 'Passwords do not match.');
      return;
    }
    if (newPass.length < 8) {
      _snack('Validation', 'Password must be at least 8 characters.');
      return;
    }
    if (email.value.isEmpty || resetToken.value.isEmpty) {
      _snack('Session expired', 'Verify your code again from the start.');
      return;
    }
    isLoading.value = true;
    try {
      final msg = await _cloud.resetPassword(
        email: email.value,
        resetToken: resetToken.value,
        newPassword: newPass,
      );
      resetToken.value = '';
      _snack('Success', msg);
      Get.offAllNamed(AppRoutes.login);
    } on FirebaseFunctionsException catch (e) {
      _snack('Error', _functionsMessage(e));
    } catch (e) {
      _snack('Error', _functionsMessage(e));
    } finally {
      isLoading.value = false;
    }
  }

  void clearFlow() {
    email.value = '';
    resetToken.value = '';
    resendCooldownSec.value = 0;
    _cooldownTimer?.cancel();
  }
}
