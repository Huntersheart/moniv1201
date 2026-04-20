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
                enabled: !_auth.isGoogleLoginLoading.value,
                isLoading: _auth.isEmailLoginLoading.value,
                onPressed: () => _auth.login(
                  email: _email.text,
                  password: _password.text,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Divider(
                    color: Colors.white.withValues(alpha: 0.25),
                    thickness: 1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: Colors.white.withValues(alpha: 0.25),
                    thickness: 1,
                  ),
                ),
              ],
            ),
            // // const SizedBox(height: 20),
            // Obx(
            //   () => _GoogleSignInButton(
            //     isLoading: _auth.isGoogleLoginLoading.value,
            //     enabled: !_auth.isEmailLoginLoading.value,
            //     onPressed: _auth.loginWithGoogle,
            //   ),
            // ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Don't have an account? ",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 15,
                  ),
                ),
                GestureDetector(
                  onTap: () => Get.toNamed(AppRoutes.register),
                  child: Text(
                    'Sign Up',
                    style: TextStyle(
                      color: AppColors.signaraGold,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
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

// class _GoogleSignInButton extends StatelessWidget {
//   const _GoogleSignInButton({
//     required this.isLoading,
//     required this.enabled,
//     required this.onPressed,
//   });

//   final bool isLoading;
//   final bool enabled;
//   final VoidCallback onPressed;

//   @override
//   Widget build(BuildContext context) {
//     final effectiveOnPressed =
//         (enabled && !isLoading) ? onPressed : null;
//     return SizedBox(
//       width: double.infinity,
//       height: 52,
//       child: OutlinedButton(
//         onPressed: effectiveOnPressed,
//         style: OutlinedButton.styleFrom(
//           foregroundColor: Colors.white,
//           side: BorderSide(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(16),
//           ),
//           backgroundColor: Colors.white.withValues(alpha: 0.06),
//         ),
//         child: isLoading
//             ? const SizedBox(
//                 width: 22,
//                 height: 22,
//                 child: CircularProgressIndicator(
//                   strokeWidth: 2.5,
//                   valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                 ),
//               )
//             : Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Container(
//                     width: 22,
//                     height: 22,
//                     alignment: Alignment.center,
//                     decoration: const BoxDecoration(
//                       color: Colors.white,
//                       shape: BoxShape.circle,
//                     ),
//                     child: const Text(
//                       'G',
//                       style: TextStyle(
//                         color: Color(0xFFEA4335),
//                         fontSize: 13,
//                         fontWeight: FontWeight.w700,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(width: 10),
//                   const Text(
//                     'Continue with Google',
//                     style: TextStyle(
//                       fontSize: 15,
//                       fontWeight: FontWeight.w600,
//                       letterSpacing: 0.2,
//                     ),
//                   ),
//                 ],
//               ),
//       ),
//     );
//   }
// }
