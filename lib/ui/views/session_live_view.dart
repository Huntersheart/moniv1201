import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../controllers/ble_controller.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/session_live_controller.dart';

const Color _kCardBg = Color(0xFF0D1B2A);
/// Selected calming rating (reference UI).
const Color _kCalmingSelectedGold = Color(0xFFB08D31);
const Color _kMovement = Color(0xFF16D351);
const Color _kComfort = Color(0xFF8B44F7);
const Color _kEnergy = Color(0xFFD4AF37);
const Color _kRingGreen = Color(0xFF3D6B4F);

/// Session Log row icons (pulse / moon / lightning).
abstract final class _SessionLogIcons {
  static const String movement = 'assets/icons/session_log_movement.png';
  static const String comfort = 'assets/icons/session_log_comfort.png';
  static const String energy = 'assets/icons/session_log_energy.png';
}

class _SessionBg extends StatelessWidget {
  const _SessionBg();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF050605)),
        Positioned(
          top: -100,
          left: -60,
          right: -60,
          child: IgnorePointer(
            child: Container(
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF1E2E22).withValues(alpha: 0.55),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Live session UI — status, haptics, sliders, questionnaires, notes, end session.
class SessionLiveView extends StatefulWidget {
  const SessionLiveView({super.key});

  @override
  State<SessionLiveView> createState() => _SessionLiveViewState();
}

class _SessionLiveViewState extends State<SessionLiveView> {
  late final SessionLiveController _c;

  String get _moduleTitle {
    final args = Get.arguments;
    if (args is Map && args['moduleTitle'] is String) {
      return args['moduleTitle'] as String;
    }
    return 'SIGNARA™ Collar';
  }

  /// Vest/Hip: hide haptic + "Response to Haptic" + "Overall Calming Effect" (per product spec).
  bool _hideHapticQuestionnaire(SessionLiveController c) {
    final s = c.activeSession.value;
    if (s != null) return s.isVestOrHipModule;
    final args = Get.arguments;
    if (args is Map && args['moduleTitle'] is String) {
      final t = (args['moduleTitle'] as String).toLowerCase();
      return t.contains('vest') || t.contains('hip');
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _c = Get.find<SessionLiveController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _c.bootstrapFromRoute(Get.arguments);
    });
  }

  Future<void> _onBack() async {
    await _c.abandonSession();
    if (mounted) Get.back<void>();
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
            const _SessionBg(),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 16, 8),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _onBack,
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                        ),
                        Expanded(
                          child: Text(
                            _moduleTitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  // ── BLE status bar ──────────────────────────────
                  if (Get.isRegistered<BleController>())
                    Obx(() {
                      final ble = Get.find<BleController>();
                      final s = ble.status.value;
                      Color dot;
                      String label;
                      switch (s) {
                        case BleStatus.connected:
                          dot = const Color(0xFF16D351);
                          label = 'Collar connected';
                          break;
                        case BleStatus.connecting:
                          dot = Colors.orange;
                          label = 'Connecting collar...';
                          break;
                        case BleStatus.scanning:
                          dot = Colors.orange;
                          label = 'Looking for collar...';
                          break;
                        case BleStatus.disconnected:
                          dot = Colors.red.shade400;
                          label = 'Collar not found — make sure it\'s on';
                          break;
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: dot.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: dot.withValues(alpha: 0.5), width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7, height: 7,
                                  decoration: BoxDecoration(
                                    color: dot,
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: dot.withValues(alpha: 0.8), blurRadius: 6)],
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  label,
                                  style: TextStyle(
                                    color: dot,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.none,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  Expanded(
                    child: Obx(() {
                      _c.elapsedSeconds.value;
                      _c.activeSession.value;
                      final hideHaptic = _hideHapticQuestionnaire(_c);
                      final dog = Get.isRegistered<DashboardController>()
                          ? Get.find<DashboardController>().selectedDog
                          : null;
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _SessionStatusCard(
                              elapsedLabel: _c.elapsedDisplay,
                              dogName: dog?.name ?? 'Dog',
                              breed: (dog?.breed.isNotEmpty ?? false) ? dog!.breed : 'Dog',
                              ageLine: 'Age: ${dog?.ageDisplay ?? '—'}',
                              photoUrl: dog?.photoUrl,
                            ),
                            if (!hideHaptic) ...[
                              const SizedBox(height: 16),
                              _HapticCard(
                                hapticOn: _c.hapticOn.value,
                                onHapticChanged: (v) => _c.hapticOn.value = v,
                                preset: _c.hapticPresetIndex.value,
                                onPreset: (i) => _c.hapticPresetIndex.value = i,
                                intensity: _c.intensity.value,
                                onIntensity: (v) => _c.intensity.value = v,
                              ),
                            ],
                            const SizedBox(height: 22),
                            const Text(
                              'Session Log',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _SessionLogCard(
                              movement: _c.movement.value,
                              comfort: _c.comfort.value,
                              energy: _c.energy.value,
                              onMovement: (v) => _c.movement.value = v,
                              onComfort: (v) => _c.comfort.value = v,
                              onEnergy: (v) => _c.energy.value = v,
                            ),
                            const SizedBox(height: 18),
                            _LimpCard(
                              value: _c.limpLevel.value,
                              onChanged: (v) => _c.limpLevel.value = v,
                            ),
                            if (!hideHaptic) ...[
                              const SizedBox(height: 14),
                              _ResponseCard(
                                value: _c.responseLevel.value,
                                onChanged: (v) => _c.responseLevel.value = v,
                              ),
                              const SizedBox(height: 14),
                              _CalmingCard(
                                value: _c.calmingLevel.value,
                                onChanged: (v) => _c.calmingLevel.value = v,
                              ),
                            ],
                            const SizedBox(height: 14),
                            _NotesUploadCard(session: _c),
                            const SizedBox(height: 24),
                          ],
                        ),
                      );
                    }),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Obx(
                      () => _EndSessionButton(
                        onPressed: _c.isLoading.value ? null : () => _c.endSession(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoldBorderCard extends StatelessWidget {
  const _GoldBorderCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.signaraGold.withValues(alpha: 0.65), width: 1.2),
      ),
      child: child,
    );
  }
}

class _SessionStatusCard extends StatelessWidget {
  const _SessionStatusCard({
    required this.elapsedLabel,
    required this.dogName,
    required this.breed,
    required this.ageLine,
    this.photoUrl,
  });

  final String elapsedLabel;
  final String dogName;
  final String breed;
  final String ageLine;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl?.trim();
    return _GoldBorderCard(
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Session Running...',
              style: TextStyle(
                color: Colors.green.shade400,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _kRingGreen.withValues(alpha: 0.55),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipOval(
              child: url != null && url.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      width: 96,
                      height: 96,
                      errorWidget: (context, imageUrl, error) => Image.asset(
                        'assets/icons/dog_icon.png',
                        fit: BoxFit.cover,
                        width: 96,
                        height: 96,
                      ),
                    )
                  : Image.asset(
                      'assets/icons/dog_icon.png',
                      fit: BoxFit.cover,
                      width: 96,
                      height: 96,
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            dogName,
            style: const TextStyle(
              color: AppColors.signaraGold,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            breed,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            ageLine,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            elapsedLabel,
            style: const TextStyle(
              color: AppColors.signaraGold,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              decoration: TextDecoration.none,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _HapticCard extends StatelessWidget {
  const _HapticCard({
    required this.hapticOn,
    required this.onHapticChanged,
    required this.preset,
    required this.onPreset,
    required this.intensity,
    required this.onIntensity,
  });

  final bool hapticOn;
  final ValueChanged<bool> onHapticChanged;
  final int preset;
  final ValueChanged<int> onPreset;
  final double intensity;
  final ValueChanged<double> onIntensity;

  @override
  Widget build(BuildContext context) {
    return _GoldBorderCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Haptic Control',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Haptic Active',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'You have haptic working',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: hapticOn,
                onChanged: onHapticChanged,
                thumbColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) return AppColors.signaraGold;
                  return Colors.grey.shade600;
                }),
                trackColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppColors.signaraGold.withValues(alpha: 0.4);
                  }
                  return Colors.white24;
                }),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _PresetChip(
                  label: 'Calm',
                  selected: preset == 0,
                  onTap: () => onPreset(0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PresetChip(
                  label: 'Moderate',
                  selected: preset == 1,
                  onTap: () => onPreset(1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PresetChip(
                  label: 'Strong',
                  selected: preset == 2,
                  onTap: () => onPreset(2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Intensity',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              Text(
                intensity.round().toString(),
                style: const TextStyle(color: AppColors.signaraGold, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _kMovement,
              inactiveTrackColor: Colors.white24,
              thumbColor: _kMovement,
              overlayColor: _kMovement.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: intensity.clamp(1.0, 3.0),
              min: 1,
              max: 3,
              divisions: 2,
              onChanged: onIntensity,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1(Low)', style: _sliderCaption),
              Text('2(Medium)', style: _sliderCaption),
              Text('3(High)', style: _sliderCaption),
            ],
          ),
        ],
      ),
    );
  }

  static final TextStyle _sliderCaption = TextStyle(
    color: Colors.white.withValues(alpha: 0.4),
    fontSize: 11,
    decoration: TextDecoration.none,
  );
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: selected ? AppColors.signaraGold : const Color(0xFF0A0F1E),
            border: Border.all(
              color: selected ? AppColors.signaraGold : Colors.white.withValues(alpha: 0.80),
              width: 1.2,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.black : Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionLogCard extends StatelessWidget {
  const _SessionLogCard({
    required this.movement,
    required this.comfort,
    required this.energy,
    required this.onMovement,
    required this.onComfort,
    required this.onEnergy,
  });

  final double movement;
  final double comfort;
  final double energy;
  final ValueChanged<double> onMovement;
  final ValueChanged<double> onComfort;
  final ValueChanged<double> onEnergy;

  @override
  Widget build(BuildContext context) {
    return _GoldBorderCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MetricSlider(
            label: 'Movement',
            iconAsset: _SessionLogIcons.movement,
            color: _kMovement,
            value: movement,
            onChanged: onMovement,
            low: '1 Very low',
            mid: '5 Normal',
            high: '10 Very high',
          ),
          const Divider(height: 28, color: Colors.white12),
          _MetricSlider(
            label: 'Comfort',
            iconAsset: _SessionLogIcons.comfort,
            color: _kComfort,
            value: comfort,
            onChanged: onComfort,
            low: '1 Very uncomfortable',
            mid: '5 Stable',
            high: '10 Very comfortable',
          ),
          const Divider(height: 28, color: Colors.white12),
          _MetricSlider(
            label: 'Energy',
            iconAsset: _SessionLogIcons.energy,
            color: _kEnergy,
            value: energy,
            onChanged: onEnergy,
            low: '1 Very low',
            mid: '5 Normal',
            high: '10 Very high',
          ),
        ],
      ),
    );
  }
}

class _MetricSlider extends StatelessWidget {
  const _MetricSlider({
    required this.label,
    required this.iconAsset,
    required this.color,
    required this.value,
    required this.onChanged,
    required this.low,
    required this.mid,
    required this.high,
  });

  final String label;
  final String iconAsset;
  final Color color;
  final double value;
  final ValueChanged<double> onChanged;
  final String low;
  final String mid;
  final String high;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(1.0, 10.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: Image.asset(
                iconAsset,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
                decoration: TextDecoration.none,
              ),
            ),
            const Spacer(),
            Text(
              '${v.round()}/10',
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            inactiveTrackColor: Colors.white24,
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.2),
          ),
          child: Slider(
            value: v,
            min: 1,
            max: 10,
            divisions: 9,
            onChanged: onChanged,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(low, style: _cap),
            Text(mid, style: _cap),
            Text(high, style: _cap),
          ],
        ),
      ],
    );
  }

  static final TextStyle _cap = TextStyle(
    color: Colors.white.withValues(alpha: 0.4),
    fontSize: 9,
    decoration: TextDecoration.none,
    height: 1.2,
  );
}

class _LimpCard extends StatelessWidget {
  const _LimpCard({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return _GoldBorderCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Limp Status',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Indicate if a limp is present in the session',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 13),
          ),
          const SizedBox(height: 12),
          _RadioRow(
            label: 'No Limp',
            selected: value == 0,
            onTap: () => onChanged(0),
          ),
          _RadioRow(
            label: 'Limp Present',
            selected: value == 1,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _ResponseCard extends StatelessWidget {
  const _ResponseCard({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return _GoldBorderCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Response to Haptic',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Immediate observed response after haptic activation.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 13),
          ),
          const SizedBox(height: 12),
          _RadioRow(
            label: 'No improvement',
            selected: value == 0,
            onTap: () => onChanged(0),
          ),
          _RadioRow(
            label: 'Slight improvement',
            selected: value == 1,
            onTap: () => onChanged(1),
          ),
          _RadioRow(
            label: 'Clear improvement',
            selected: value == 2,
            onTap: () => onChanged(2),
          ),
        ],
      ),
    );
  }
}

class _RadioRow extends StatelessWidget {
  const _RadioRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? AppColors.signaraGold : Colors.white,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 15, decoration: TextDecoration.none),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalmingCard extends StatelessWidget {
  const _CalmingCard({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  static const _labels = ['None', 'Minimal', 'Moderate', 'Strong', 'Very Strong'];

  @override
  Widget build(BuildContext context) {
    final subtitleStyle = GoogleFonts.poppins(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: Colors.grey.shade400,
      decoration: TextDecoration.none,
    );
    return _GoldBorderCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Calming Effect',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Rate the overall calming effect (1-5)',
            style: subtitleStyle,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(5, (i) {
              final n = i + 1;
              final sel = value == n;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 4, right: i == 4 ? 0 : 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onChanged(n),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: sel ? _kCalmingSelectedGold : _kCardBg,
                          border: sel
                              ? null
                              : Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  width: 1,
                                ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$n',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _labels[i],
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                height: 1.15,
                                fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                                color: sel ? Colors.white : Colors.grey,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _NotesUploadCard extends StatelessWidget {
  const _NotesUploadCard({required this.session});

  final SessionLiveController session;

  @override
  Widget build(BuildContext context) {
    return _GoldBorderCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Notes',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: session.noteController,
            maxLines: 3,
            style: const TextStyle(color: Colors.white, fontSize: 15, decoration: TextDecoration.none),
            cursorColor: AppColors.signaraGold,
            decoration: InputDecoration(
              hintText: 'Add note',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.80)),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.35),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.signaraGold, width: 1.2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Obx(() {
            final busy = session.isUploadingPhoto.value;
            final pct = session.photoUploadProgress.value.clamp(0, 100);
            return _UploadButton(
              label: busy ? 'Uploading photo... $pct%' : 'Upload Photo',
              onPressed: busy ? null : () => unawaited(session.pickAndUploadPhoto()),
            );
          }),
          Obx(() {
            final busy = session.isUploadingPhoto.value;
            if (!busy) return const SizedBox.shrink();
            final pct = session.photoUploadProgress.value.clamp(0, 100);
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: pct / 100,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.signaraGold),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$pct% uploaded',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            );
          }),
          Obx(() {
            final u = session.photoUrl.value;
            if (u.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 4),
              child: Text(
                'Photo upload completed (100%)',
                style: TextStyle(
                  color: Colors.green.shade400,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          Obx(() {
            final busy = session.isUploadingVideo.value;
            final pct = session.videoUploadProgress.value.clamp(0, 100);
            return _UploadButton(
              label: busy ? 'Uploading video... $pct%' : 'Upload Video',
              onPressed: busy ? null : () => unawaited(session.pickAndUploadVideo()),
            );
          }),
          const SizedBox(height: 6),
          Text(
            'Fast upload tip: use 720p/medium quality, keep video 20-50MB, and prefer Wi-Fi.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 11,
              height: 1.3,
              decoration: TextDecoration.none,
            ),
          ),
          Obx(() {
            final busy = session.isUploadingVideo.value;
            if (!busy) return const SizedBox.shrink();
            final pct = session.videoUploadProgress.value.clamp(0, 100);
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: pct / 100,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.signaraGold),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$pct% uploaded',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            );
          }),
          Obx(() {
            final u = session.videoUrl.value;
            if (u.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Video upload completed (100%)',
                style: TextStyle(
                  color: Colors.green.shade400,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _UploadButton extends StatelessWidget {
  const _UploadButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.upload_file_outlined, color:Colors.white, size: 20),
      label: Text(label, style: const TextStyle(color: Colors.white,  fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.white,  width: 1.2),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _EndSessionButton extends StatelessWidget {
  const _EndSessionButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.signaraGoldShadow,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.signaraGold,
            foregroundColor: Colors.black,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text(
            'End Session',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, decoration: TextDecoration.none),
          ),
        ),
      ),
    );
  }
}
