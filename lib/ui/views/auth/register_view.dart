import 'dart:math' as math;
import 'dart:ui';

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

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  late final AuthController _auth;

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void initState() {
    super.initState();
    _auth = Get.find<AuthController>();
    void refresh() {
      if (mounted) setState(() {});
    }

    _email.addListener(refresh);
    _password.addListener(refresh);
    _confirm.addListener(refresh);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool _canSubmit() {
    final email = _email.text.trim();
    final p = _password.text;
    final c = _confirm.text;
    return _emailRegex.hasMatch(email) &&
        p.length >= 6 &&
        c.isNotEmpty &&
        p == c;
  }

  Future<void> _onSignUp() async {
    FocusScope.of(context).unfocus();
    final ok = await _auth.register(
      email: _email.text,
      password: _password.text,
      confirmPassword: _confirm.text,
    );
    if (!mounted || !ok) return;
    _showAccountReadyDialog();
  }

  void _showAccountReadyDialog() {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Success',
      barrierColor: Colors.transparent,
      transitionDuration: Duration.zero,
      pageBuilder: (ctx, animation, secondaryAnimation) {
        return _AccountReadyOverlay(
          onContinue: () {
            Navigator.of(ctx).pop();
            Get.offAllNamed(AppRoutes.login);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _canSubmit();

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
            const SignaraBrandLogoMark(size: 96),
            const SizedBox(height: 36),
            SignaraTextField(
              label: 'Email',
              controller: _email,
              labelTextAlign: TextAlign.start,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 20),
            SignaraTextField(
              label: 'New Password',
              controller: _password,
              labelTextAlign: TextAlign.start,
              obscureText: _obscurePassword,
              onVisibilityToggle: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
            ),
            const SizedBox(height: 20),
            SignaraTextField(
              label: 'Confirm Password',
              controller: _confirm,
              labelTextAlign: TextAlign.start,
              obscureText: _obscureConfirm,
              onVisibilityToggle: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
            ),
            const SizedBox(height: 28),
            Obx(
              () => SignaraPrimaryButton(
                label: 'Sign Up',
                enabled: canSubmit && !_auth.isRegisterLoading.value,
                isLoading: _auth.isRegisterLoading.value,
                onPressed: _onSignUp,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an account? ',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 15,
                  ),
                ),
                GestureDetector(
                  onTap: () => Get.offNamed(AppRoutes.login),
                  child: Text(
                    'Sign In',
                    style: TextStyle(
                      color: AppColors.signaraGold,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountReadyOverlay extends StatelessWidget {
  const _AccountReadyOverlay({required this.onContinue});

  final VoidCallback onContinue;

  static const Color _gold = Color(0xFFC5A459);

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF161616).withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _SuccessBadge(gold: _gold),
                        const SizedBox(height: 28),
                        Text(
                          'Your account is ready',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _gold,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 28),
                        SignaraPrimaryButton(
                          label: 'Continue',
                          onPressed: onContinue,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessBadge extends StatelessWidget {
  const _SuccessBadge({required this.gold});

  final Color gold;

  @override
  Widget build(BuildContext context) {
    const size = 120.0;
    const orbit = 64.0;
    return SizedBox(
      width: size + 32,
      height: size + 32,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          ...List.generate(8, (i) {
            final a = math.pi * 2 * i / 8;
            return Transform.translate(
              offset: Offset(
                math.cos(a) * orbit,
                math.sin(a) * orbit,
              ),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: gold.withValues(alpha: 0.95),
              boxShadow: [
                BoxShadow(
                  color: gold.withValues(alpha: 0.35),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: Colors.white,
              size: 56,
            ),
          ),
        ],
      ),
    );
  }
}
