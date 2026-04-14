import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../widgets/signara_centered_screen_body.dart';
import '../../widgets/signara_primary_button.dart';
import '../../widgets/signara_text_field.dart';

/// Shown after the user opens the password-reset link from email (`oobCode`).
class CreatePasswordView extends StatefulWidget {
  const CreatePasswordView({super.key});

  @override
  State<CreatePasswordView> createState() => _CreatePasswordViewState();
}

class _CreatePasswordViewState extends State<CreatePasswordView> {
  final _newPass = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;

  late final AuthController _auth;

  @override
  void initState() {
    super.initState();
    _auth = Get.find<AuthController>();
  }

  @override
  void dispose() {
    _newPass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? get _oobCode {
    final oob = Get.parameters['oobCode']?.trim();
    if (oob == null || oob.isEmpty) return null;
    return oob;
  }

  void _onSubmit() {
    _auth.setNewPassword(
      _newPass.text,
      _confirm.text,
      oobCode: _oobCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCode = _oobCode != null;
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
              'Create New Password',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasCode
                  ? 'Choose a new password (min. 6 characters).'
                  : 'Open the reset link from your email first. If you are already signed in, you can change your password after logging in.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 14,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 24),
            SignaraTextField(
              label: 'New Password',
              controller: _newPass,
              obscureText: _obscure1,
              onVisibilityToggle: () => setState(() => _obscure1 = !_obscure1),
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
            ),
            const SizedBox(height: 20),
            SignaraTextField(
              label: 'Confirm Password',
              controller: _confirm,
              obscureText: _obscure2,
              onVisibilityToggle: () => setState(() => _obscure2 = !_obscure2),
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
            ),
            const SizedBox(height: 28),
            Obx(() => SignaraPrimaryButton(
                  label: 'Set Password',
                  isLoading: _auth.isLoading.value,
                  onPressed: _onSubmit,
                )),
          ],
        ),
      ),
    );
  }
}
