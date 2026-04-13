import 'package:flutter/material.dart';

/// Central palette — use these instead of hardcoded [Color] literals in UI.
abstract final class AppColors {
  static const Color primary = Color(0xFF1565C0);
  static const Color primaryLight = Color(0xFF5E92F3);
  static const Color primaryDark = Color(0xFF003C8F);

  static const Color secondary = Color(0xFF00897B);
  static const Color accent = Color(0xFFFF6F00);

  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  static const Color error = Color(0xFFC62828);
  static const Color success = Color(0xFF2E7D32);
  static const Color divider = Color(0xFFE0E0E0);

  /// Premium gold CTA (onboarding + app-wide primary actions on dark UI).
  static const Color signaraGold = Color(0xFFD4AF37);
  static const Color signaraGoldShadow = Color(0x66D4AF37);

  /// Complete Session / summary metrics (Material-style on dark UI).
  static const Color sessionMovementGreen = Color(0xFF4CAF50);
  static const Color sessionComfortPurple = Color(0xFF9C27B0);
}
