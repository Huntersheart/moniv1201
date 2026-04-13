import 'package:flutter/material.dart';

/// Dark green → black vertical gradient (main app shell behind dashboard).
class SignaraDashboardBackground extends StatelessWidget {
  const SignaraDashboardBackground({super.key});

  static const Color _top = Color(0xFF1A2B1F);
  static const Color _bottom = Color(0xFF0A0A0A);

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            _top,
            _bottom,
          ],
        ),
      ),
    );
  }
}
