import 'package:flutter/material.dart';

/// Subtle radial glow on very dark base — matches SIGNARA auth / onboarding screens.
class SignaraDarkBackground extends StatelessWidget {
  const SignaraDarkBackground({super.key});

  static const Color _base = Color(0xFF0A0F1E);
  static const Color _glow = Color(0xFF0D1B2A);

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: _base,
        gradient: RadialGradient(
          center: Alignment(0, -0.25),
          radius: 1.15,
          colors: <Color>[
            _glow,
            _base,
          ],
          stops: <double>[0.0, 1.0],
        ),
      ),
    );
  }
}
