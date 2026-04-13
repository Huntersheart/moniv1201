import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../widgets/signara_primary_button.dart';

/// Four onboarding screens — **#000000**, Skip, dots (**#1B3022** active), gold CTA.
/// **1:** [onbardinge1] · **2:** [onbardinge2] · **3:** comfort copy (lower-half layout) · **4:** logo + Get Started.
class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

enum _OnboardingHeroKind {
  singleImage,
  /// Screen 3: headline + subhead in lower half (mockup — no hero image).
  centeredTextOnly,
  /// Screen 4: heart logo top-left + centered copy.
  logoAndText,
}

class _OnboardingPage {
  const _OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.kind,
    this.heroAsset,
    this.subtitleMuted = false,
  });

  final String title;
  final String subtitle;
  final _OnboardingHeroKind kind;
  final String? heroAsset;
  final bool subtitleMuted;
}

class _OnboardingViewState extends State<OnboardingView> {
  static const Color _dotActive = Color(0xFF1B3022);
  static const Color _dotInactive = Color(0xFFE0E0E0);

  static const List<_OnboardingPage> _pages = <_OnboardingPage>[
    _OnboardingPage(
      kind: _OnboardingHeroKind.singleImage,
      heroAsset: 'assets/images/onbardinge1.png',
      title: 'SIGNARA™ Collar',
      subtitle: 'Calming support using haptic feedback',
    ),
    _OnboardingPage(
      kind: _OnboardingHeroKind.singleImage,
      heroAsset: 'assets/images/onbardinge2.png',
      title: 'Tested in real-world conditions',
      subtitle: 'Designed for comfort, safety, and daily use',
      subtitleMuted: true,
    ),
    _OnboardingPage(
      kind: _OnboardingHeroKind.centeredTextOnly,
      title: 'Your dog\'s comfort starts here',
      subtitle:
          'Simple daily support to help your dog feel calm and comfortable',
    ),
    _OnboardingPage(
      kind: _OnboardingHeroKind.logoAndText,
      title: 'Ready to get started',
      subtitle: 'Create your account to begin',
    ),
  ];

  final PageController _pageController = PageController();
  int _index = 0;

  void _goHome() {
    Get.offAllNamed(AppRoutes.login);
  }

  void _onNext() {
    if (_index < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _goHome();
    }
  }

  void _onBack() {
    if (_index > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          color: const Color(0xFF000000),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 2, 10, 0),
                      child: Row(
                        children: [
                          if (_index > 0)
                            SignaraLightOutlineButton(
                              label: 'Back',
                              icon: Icons.arrow_back_ios_new,
                              onPressed: _onBack,
                            )
                          else
                            const SizedBox(width: 88),
                          const Spacer(),
                          SignaraLightOutlineButton(
                            label: 'Skip',
                            onPressed: _goHome,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) {
                      final p = _pages[i];
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: _OnboardingPageBody(
                              page: p,
                              pageIndex: i,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Screens 1–2: dots above CTA; 3–4: dots inline in page. CTA column centered (max 560).
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(24, 0, 24, 16 + bottomInset),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_index < 2) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(_pages.length, (i) {
                                final active = i == _index;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.symmetric(horizontal: 5),
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: active ? _dotActive : _dotInactive,
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 20),
                          ] else
                            const SizedBox(height: 12),
                          SignaraPrimaryButton(
                            label: _index == _pages.length - 1 ? 'Get Started' : 'Next',
                            onPressed: _onNext,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingPageBody extends StatelessWidget {
  const _OnboardingPageBody({
    required this.page,
    required this.pageIndex,
  });

  final _OnboardingPage page;
  final int pageIndex;

  @override
  Widget build(BuildContext context) {
    switch (page.kind) {
      case _OnboardingHeroKind.singleImage:
        return _SingleImageHeroPage(page: page);
      case _OnboardingHeroKind.centeredTextOnly:
        return _CenteredTextOnlyPage(
          page: page,
          activeDotIndex: pageIndex,
        );
      case _OnboardingHeroKind.logoAndText:
        return _LogoAndCenteredCopy(
          page: page,
          activeDotIndex: pageIndex,
        );
    }
  }
}

// --- Screens 1–2 -------------------------------------------------------------

class _SingleImageHeroPage extends StatelessWidget {
  const _SingleImageHeroPage({required this.page});

  final _OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    final path = page.heroAsset!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxH = constraints.maxHeight * 0.68;
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxH),
                  child: Image.asset(
                    path,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    alignment: Alignment.center,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        Text(
          page.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.2,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          page.subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: page.subtitleMuted
                ? const Color(0xFFB8B8B8)
                : Colors.white.withValues(alpha: 0.95),
            fontSize: 16,
            height: 1.45,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// --- Screen 3: title → subtitle → dots (same cluster as mockup) --------------

class _CenteredTextOnlyPage extends StatelessWidget {
  const _CenteredTextOnlyPage({
    required this.page,
    required this.activeDotIndex,
  });

  final _OnboardingPage page;
  final int activeDotIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(flex: 2),
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  page.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    height: 1.28,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  page.subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 28),
                _OnboardingDotsInline(activeIndex: activeDotIndex),
              ],
            ),
          ),
        ),
        const Spacer(flex: 3),
      ],
    );
  }
}

// --- Screen 4: logo top-left → title → subtitle → dots (mockup) ------------

class _LogoAndCenteredCopy extends StatelessWidget {
  const _LogoAndCenteredCopy({
    required this.page,
    required this.activeDotIndex,
  });

  final _OnboardingPage page;
  final int activeDotIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(left: 4, top: 4),
            child: _HuntersHeartLogoMark(),
          ),
        ),
        Expanded(
          child: Column(
            children: [
              const Spacer(flex: 2),
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        page.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        page.subtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.45,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _OnboardingDotsInline(activeIndex: activeDotIndex),
                    ],
                  ),
                ),
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ],
    );
  }
}

/// Dots directly under copy on screens 3–4 (aligned with design reference).
class _OnboardingDotsInline extends StatelessWidget {
  const _OnboardingDotsInline({required this.activeIndex});

  final int activeIndex;

  static const Color _dotActive = Color(0xFF1B3022);
  static const Color _dotInactive = Color(0xFFE0E0E0);
  static const int _count = 4;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_count, (i) {
        final active = i == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? _dotActive : _dotInactive,
          ),
        );
      }),
    );
  }
}

class _HuntersHeartLogoMark extends StatelessWidget {
  const _HuntersHeartLogoMark();

  static const Color _green = Color(0xFF1B3022);
  static const Color _gold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -2,
            top: 14,
            child: Icon(
              Icons.eco,
              size: 16,
              color: _green.withValues(alpha: 0.9),
            ),
          ),
          Positioned(
            left: 2,
            top: 18,
            child: Icon(
              Icons.eco,
              size: 12,
              color: _green.withValues(alpha: 0.85),
            ),
          ),
          const Center(
            child: Icon(
              Icons.favorite_border,
              size: 40,
              color: _green,
            ),
          ),
          Positioned(
            right: 10,
            top: 12,
            child: Icon(
              Icons.pets,
              size: 18,
              color: _gold,
            ),
          ),
        ],
      ),
    );
  }
}
