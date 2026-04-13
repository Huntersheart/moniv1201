import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../controllers/password_reset_otp_controller.dart';
import '../../widgets/signara_centered_screen_body.dart';
import '../../widgets/signara_primary_button.dart';
import '../../widgets/signara_text_field.dart';

/// Enter6-digit OTP from email; then continues to [CreatePasswordView].
class VerifyCodeView extends StatefulWidget {
  const VerifyCodeView({super.key});

  @override
  State<VerifyCodeView> createState() => _VerifyCodeViewState();
}

class _VerifyCodeViewState extends State<VerifyCodeView> {
  final _otpField = TextEditingController();
  late final PasswordResetOtpController _otp;

  @override
  void initState() {
    super.initState();
    _otp = Get.find<PasswordResetOtpController>();
  }

  @override
  void dispose() {
    _otpField.dispose();
    super.dispose();
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
        body: SignaraCenteredScreenBody(
          showBack: true,
          children: [
            const Text(
              'Enter verification code',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Obx(() {
              final em = _otp.email.value;
              final hint = em.isEmpty
                  ? 'We sent a 6-digit code to your email.'
                  : 'We sent a code to $em';
              return Text(
                hint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 15,
                  height: 1.45,
                  fontWeight: FontWeight.w400,
                ),
              );
            }),
            const SizedBox(height: 36),
            SignaraTextField(
              label: '6-digit code',
              controller: _otpField,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              maxLength: 6,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
            ),
            const SizedBox(height: 20),
            Obx(() => SignaraPrimaryButton(
                  label: 'Continue',
                  isLoading: _otp.isLoading.value,
                  onPressed: () => _otp.verifyOtpAndContinue(_otpField.text),
                )),
            const SizedBox(height: 16),
            Obx(() {
              final sec = _otp.resendCooldownSec.value;
              final canResend = sec <= 0 && !_otp.isLoading.value;
              return Column(
                children: [
                  if (sec > 0)
                    Text(
                      'Resend available in ${sec}s',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 14,
                      ),
                    ),
                  TextButton(
                    onPressed: canResend ? _otp.resendOtp : null,
                    child: Text(
                      'Resend code',
                      style: TextStyle(
                        color: canResend ? Colors.white70 : Colors.white38,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _otp.isLoading.value
                        ? null
                        : () => Get.offAllNamed(AppRoutes.login),
                    child: const Text(
                      'Back to login',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}
