import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../ui/controllers/auth_controller.dart';
import '../../widgets/signara_centered_screen_body.dart';
import '../../widgets/signara_logo_mark.dart';
import '../../widgets/signara_primary_button.dart';
import '../../widgets/signara_text_field.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  late final AuthController _auth;

  @override
  void initState() {
    super.initState();
    _auth = Get.find<AuthController>();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
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
          showBack: false,
          children: [
            const SignaraBrandLogoMark(size: 96),
            const SizedBox(height: 40),
            SignaraTextField(
              label: 'Email',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 20),
            SignaraTextField(
              label: 'Password',
              controller: _password,
              obscureText: _obscure,
              onVisibilityToggle: () => setState(() => _obscure = !_obscure),
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Get.toNamed(AppRoutes.forgotPassword),
                child: Text(
                  'Forgot password?',
                  style: TextStyle(
                    color: AppColors.signaraGold,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Obx(
              () => SignaraPrimaryButton(
                label: 'Login',
                isLoading: _auth.isLoading.value,
                onPressed: () => _auth.login(
                  email: _email.text,
                  password: _password.text,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Access is provided by invitation only',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
