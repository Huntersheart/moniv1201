import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/password_reset_otp_controller.dart';
import '../../widgets/signara_centered_screen_body.dart';
import '../../widgets/signara_primary_button.dart';
import '../../widgets/signara_text_field.dart';

class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final _email = TextEditingController();
  late final PasswordResetOtpController _otp;

  @override
  void initState() {
    super.initState();
    _otp = Get.find<PasswordResetOtpController>();
    _otp.clearFlow();
  }

  @override
  void dispose() {
    _email.dispose();
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
              'Forgot Password?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Enter your email. We\'ll send a 6-digit code to reset your password.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 15,
                height: 1.45,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 36),
            SignaraTextField(
              label: 'Email',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 20),
            Obx(() => SignaraPrimaryButton(
                  label: 'Send code',
                  isLoading: _otp.isLoading.value,
                  onPressed: () => _otp.sendOtp(_email.text),
                )),
          ],
        ),
      ),
    );
  }
}
