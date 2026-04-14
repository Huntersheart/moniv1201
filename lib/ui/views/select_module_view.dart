import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../controllers/auth_controller.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/signara_primary_button.dart';

/// Radial green–gold glows top + bottom on charcoal (matches Select Module mock).
class _SelectModuleBackground extends StatelessWidget {
  const _SelectModuleBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF0C0E0C)),
        Positioned(
          top: -120,
          left: -80,
          right: -80,
          child: IgnorePointer(
            child: Container(
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF2A4A32).withValues(alpha: 0.45),
                    const Color(0xFF3D5220).withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -140,
          left: -100,
          right: -100,
          child: IgnorePointer(
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF2B3518).withValues(alpha: 0.4),
                    const Color(0xFF4A3D12).withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ModuleOption {
  const _ModuleOption({
    required this.assetPath,
    required this.title,
    required this.subtitle,
  });

  final String assetPath;
  final String title;
  final String subtitle;
}

/// Choose collar / vest / hip module before starting a session.
/// Admin users see all 3 modules; regular users see only SIGNARA™ Collar.
class SelectModuleView extends StatefulWidget {
  const SelectModuleView({super.key});

  @override
  State<SelectModuleView> createState() => _SelectModuleViewState();
}

class _SelectModuleViewState extends State<SelectModuleView> {
  static const List<_ModuleOption> _allModules = [
    _ModuleOption(
      assetPath: 'assets/icons/signnara_ollar.png',
      title: 'SIGNARA™ Collar',
      subtitle: 'Haptic feedback for anxiety and calming',
    ),
    _ModuleOption(
      assetPath: 'assets/icons/support_vest.png',
      title: 'Support Vest',
      subtitle: 'Core support and stability',
    ),
    _ModuleOption(
      assetPath: 'assets/icons/hip_module.png',
      title: 'Hip Module',
      subtitle: 'Hip support and mobility assistance',
    ),
  ];

  int _selectedIndex = 0;
  bool _isAdmin = false;
  Worker? _roleWorker;

  @override
  void initState() {
    super.initState();
    _initRole();
  }

  @override
  void dispose() {
    _roleWorker?.dispose();
    super.dispose();
  }

  void _initRole() {
    if (!Get.isRegistered<AuthController>()) return;
    final auth = Get.find<AuthController>();
    _isAdmin = auth.currentUser.value?.isAdmin ?? false;
    _roleWorker = ever(auth.currentUser, (user) {
      if (mounted) {
        setState(() {
          _isAdmin = user?.isAdmin ?? false;
          final max = (_isAdmin ? _allModules.length : 1) - 1;
          if (_selectedIndex > max) _selectedIndex = 0;
        });
      }
    });
  }

  String? get _dogIdFromRoute {
    final raw = Get.arguments;
    if (raw is Map && raw['dogId'] is String) {
      final id = raw['dogId'] as String;
      return id.isEmpty ? null : id;
    }
    return null;
  }

  void _onStartSession(List<_ModuleOption> modules) {
    final safeIndex = _selectedIndex.clamp(0, modules.length - 1);
    final m = modules[safeIndex];
    if (!Get.isRegistered<DashboardController>()) {
      Get.snackbar(
        'Navigation',
        'Open the home screen first, then start a session.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        backgroundColor: const Color(0xFF2A2A2A),
        colorText: Colors.white,
      );
      return;
    }
    final routeDogId = _dogIdFromRoute;
    final dashDog = Get.find<DashboardController>().selectedDog;
    final dogId = routeDogId ?? dashDog?.dogId;
    if (dogId == null || dogId.isEmpty) {
      Get.snackbar(
        'Select a dog',
        'Choose a dog on the home screen before starting a session.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        backgroundColor: const Color(0xFF2A2A2A),
        colorText: Colors.white,
      );
      return;
    }
    Get.toNamed(
      AppRoutes.sessionLive,
      arguments: <String, dynamic>{
        'moduleTitle': m.title,
        'dogId': dogId,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const _SelectModuleBackground(),
            SafeArea(
              child: Builder(
                builder: (context) {
                  final modules =
                      _isAdmin ? _allModules : [_allModules.first];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: () => Get.back<void>(),
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isAdmin ? 'Select Module' : 'Module',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isAdmin
                                  ? 'Choose which device to use for this session'
                                  : 'Which device to use for this session',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.48),
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                          itemCount: modules.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 14),
                          itemBuilder: (context, i) {
                            final m = modules[i];
                            final selected = i == _selectedIndex;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedIndex = i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOut,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1D1A),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.signaraGold
                                        : Colors.transparent,
                                    width: selected ? 1.8 : 0,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 76,
                                      height: 76,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF121412),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.all(6),
                                      child: Image.asset(
                                        m.assetPath,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            m.title,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              decoration: TextDecoration.none,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            m.subtitle,
                                            style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.52),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w400,
                                              height: 1.3,
                                              decoration: TextDecoration.none,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: SignaraPrimaryButton(
                          label: 'Start Session',
                          onPressed: () => _onStartSession(modules),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
