import 'package:flutter/material.dart';

/// Hunter’s Heart–style mark: green heart + leaves + gold paw (scales with [size]).
class SignaraBrandLogoMark extends StatelessWidget {
  const SignaraBrandLogoMark({
    super.key,
    this.size = 72,
  });

  final double size;

  static const Color _green = Color(0xFF0D1B2A);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            left: size * 0.02,
            top: size * 0.22,
            child: Icon(Icons.eco, size: size * 0.22, color: _green.withValues(alpha: 0.9)),
          ),
          Positioned(
            left: size * 0.08,
            top: size * 0.28,
            child: Icon(Icons.eco, size: size * 0.16, color: _green.withValues(alpha: 0.85)),
          ),
          // Icon(Icons.favorite_border, size: heart, color: _green),

          Image.asset("assets/images/splash_image.png"),
         
        ],
      ),
    );
  }
}
