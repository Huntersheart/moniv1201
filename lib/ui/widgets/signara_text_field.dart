import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';

/// Dark-theme outlined field — **one style app-wide** (white border, label above).
class SignaraTextField extends StatelessWidget {
  const SignaraTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.obscureText = false,
    this.onVisibilityToggle,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.autofillHints,
    this.enabled = true,
    this.labelTextAlign = TextAlign.center,
    this.maxLines = 1,
    this.maxLength,
    this.inputFormatters,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final bool obscureText;
  final VoidCallback? onVisibilityToggle;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final Iterable<String>? autofillHints;
  final bool enabled;
  /// Form screens often use [TextAlign.start]; auth screens may keep [TextAlign.center].
  final TextAlign labelTextAlign;
  /// Use `> 1` for multi-line notes (e.g. Additional Notes).
  final int maxLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;

  static const double _radius = 10;

  @override
  Widget build(BuildContext context) {
    final showEye = obscureText && onVisibilityToggle != null;

    final effectiveKeyboardType = keyboardType ??
        (maxLines > 1 ? TextInputType.multiline : TextInputType.text);
    final effectiveAction = textInputAction ??
        (maxLines > 1 ? TextInputAction.newline : TextInputAction.next);

    final field = TextFormField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      keyboardType: effectiveKeyboardType,
      textInputAction: effectiveAction,
      maxLines: maxLines,
      minLines: maxLines > 1 ? 3 : null,
      autofillHints: autofillHints,
      validator: validator,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      cursorColor: AppColors.signaraGold,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.45),
          fontSize: 16,
        ),
        filled: true,
        fillColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        counterText: maxLength != null ? '' : null,
        border: _border(Colors.white.withValues(alpha: 0.55)),
        enabledBorder: _border(Colors.white.withValues(alpha: 0.55)),
        focusedBorder: _border(Colors.white.withValues(alpha: 0.95)),
        errorBorder: _border(Colors.redAccent.withValues(alpha: 0.8)),
        focusedErrorBorder: _border(Colors.redAccent),
        suffixIcon: showEye
            ? IconButton(
                onPressed: onVisibilityToggle,
                icon: Icon(
                  obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 22,
                ),
              )
            : null,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          textAlign: labelTextAlign,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        field,
      ],
    );
  }

  OutlineInputBorder _border(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(_radius),
      borderSide: BorderSide(color: color, width: 1),
    );
  }
}
