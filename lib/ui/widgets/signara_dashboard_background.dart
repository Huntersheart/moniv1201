import 'package:flutter/material.dart';

/// Dark green → black vertical gradient (main app shell behind dashboard).
class SignaraDashboardBackground extends StatelessWidget {
  const SignaraDashboardBackground({super.key});

  static const Color _top = Color(0xFF0D1B2A);
  static const Color _bottom = Color(0xFF060D18);

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
