import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'signara_dark_background.dart';

/// Vertically and horizontally centers scrollable content; optional top-left back.
class SignaraCenteredScreenBody extends StatelessWidget {
  const SignaraCenteredScreenBody({
    super.key,
    required this.children,
    this.showBack = false,
    this.horizontalPadding = 24,
  });

  final List<Widget> children;
  final bool showBack;
  final double horizontalPadding;

  static const double _topWhenBack = 44;
  static const double _topDefault = 16;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final topPad = showBack ? _topWhenBack : _topDefault;

    return Stack(
      fit: StackFit.expand,
      children: [
        const SignaraDarkBackground(),
        SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        topPad,
                        horizontalPadding,
                        24 + bottom,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 560),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: children,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (showBack)
                PositionedDirectional(
                  start: 8,
                  top: 0,
                  child: IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
