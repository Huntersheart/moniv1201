import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// App-wide gold primary CTA — Figma: fill `#D4AF37`, 48×fill height, radius 12,
/// padding 12h / 8v, dual gold shadows (±4 offset, blur 5 / 4, 25% opacity).
class SignaraPrimaryButton extends StatelessWidget {
  const SignaraPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = (enabled && !isLoading) ? onPressed : null;
    const gold = AppColors.signaraGold; // #D4AF37
    final shadowTint = gold.withValues(alpha: 0.25);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: shadowTint,
            offset: const Offset(4, 4),
            blurRadius: 5,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: shadowTint,
            offset: const Offset(-4, -4),
            blurRadius: 4,
            spreadRadius: 0,
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: effectiveOnPressed,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shadowColor: Colors.transparent,
            backgroundColor: gold,
            foregroundColor: Colors.black,
            disabledBackgroundColor: gold.withValues(alpha: 100),
            disabledForegroundColor: Colors.black.withValues(alpha: 0.45),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            minimumSize: const Size.fromHeight(48),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
        ),
      ),
    );
  }
}

/// White outline label on dark backgrounds (Skip, Back, etc.).
class SignaraLightOutlineButton extends StatelessWidget {
  const SignaraLightOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Colors.white, width: 1),
        ),
      ),
      child: icon == null
          ? Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
                fontSize: 15,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
    );
  }
}
