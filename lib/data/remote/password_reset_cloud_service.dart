import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

/// Calls Cloud Functions for custom email OTP password reset.
/// Region must match [functions/index.js] (`us-central1`).
class PasswordResetCloudService {
  static const String region = 'us-central1';

  FirebaseFunctions get _fn => FirebaseFunctions.instanceFor(
        app: Firebase.app(),
        region: region,
      );

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }

  /// [sent] is false when this email is not registered in Firebase Auth (no email is sent).
  Future<({bool sent, String message})> sendOtp(String email) async {
    // Match Cloud Function `timeoutSeconds: 120` — default callable timeout is 60s.
    final callable = _fn.httpsCallable(
      'sendPasswordResetOtp',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
    );
    final res = await callable.call({'email': email.trim()});
    final data = _asMap(res.data);
    final sent = data['sent'] as bool? ?? true;
    final message = data['message'] as String? ??
        (sent
            ? 'Check your inbox for the 6-digit code.'
            : 'Could not send a code.');
    return (sent: sent, message: message);
  }

  /// Returns one-time [resetToken] for [resetPassword]; keep server-side only logic in Functions.
  Future<({String resetToken, int expiresInSeconds})> verifyOtp({
    required String email,
    required String otp,
  }) async {
    final callable = _fn.httpsCallable('verifyPasswordResetOtp');
    final res = await callable.call({
      'email': email.trim(),
      'otp': otp.trim(),
    });
    final data = _asMap(res.data);
    final token = data['resetToken'] as String?;
    if (token == null || token.isEmpty) {
      throw FirebaseFunctionsException(
        code: 'invalid-response',
        message: 'Invalid response from server.',
      );
    }
    final exp = (data['expiresInSeconds'] as num?)?.toInt() ?? 900;
    return (resetToken: token, expiresInSeconds: exp);
  }

  Future<String> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    final callable = _fn.httpsCallable('resetPasswordWithToken');
    final res = await callable.call({
      'email': email.trim(),
      'resetToken': resetToken,
      'newPassword': newPassword,
    });
    final data = _asMap(res.data);
    return data['message'] as String? ?? 'Password updated.';
  }
}
