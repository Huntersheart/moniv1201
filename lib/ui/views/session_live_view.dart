import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../controllers/ble_controller.dart';
import '../controllers/vest_ble_controller.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/session_live_controller.dart';

const Color _kCardBg = Color(0xFF0D1B2A);
/// Selected calming rating (reference UI).
const Color _kCalmingSelectedGold = Color(0xFFB08D31);
const Color _kMovement = Color(0xFF16D351);
const Color _kComfort = Color(0xFF8B44F7);
const Color _kEnergy = Color(0xFFD4AF37);
const Color _kRingGreen = Color(0xFF00E5FF); // cyan — matches Signara logo ECG line

// Vest sensor card accent colors
const Color _kHrColor    = Color(0xFFFF4C6A);
const Color _kSpo2Color  = Color(0xFF00BFFF);
const Color _kTempColor  = Color(0xFFFFB347);
const Color _kFsrColor   = Color(0xFF9B59B6);
const Color _kImuColor   = Color(0xFF1ABC9C);

// ── Pain Assessment logic ─────────────────────────────────────────────────────

enum PainLevel { none, possible, likely }

class _PainAssessment {
  final PainLevel level;
  final String headline;    // "No pain signs" / "Compensating right shoulder"
  final String detail;      // plain-English explanation
  final String shoulderLoad; // "Symmetric 3%" / "Off right 21%"
  final String temperature;  // "Normal" / "Elevated"
  final String heartRate;    // "Normal" / "High"
  final String activity;     // "Resting" / "Active" / "Agitated"
  final bool fsrAvailable;
  final double fsrLeftPct;   // 0.0–1.0 for bar
  final double fsrRightPct;
  final bool rightOffloading;

  const _PainAssessment({
    required this.level,
    required this.headline,
    required this.detail,
    required this.shoulderLoad,
    required this.temperature,
    required this.heartRate,
    required this.activity,
    required this.fsrAvailable,
    required this.fsrLeftPct,
    required this.fsrRightPct,
    required this.rightOffloading,
  });

  Color get borderColor {
    switch (level) {
      case PainLevel.none:     return const Color(0xFF16D351);
      case PainLevel.possible: return const Color(0xFFFFB347);
      case PainLevel.likely:   return const Color(0xFFFF4C6A);
    }
  }

  Color get accentColor => borderColor;

  String get badgeText {
    switch (level) {
      case PainLevel.none:     return 'No signs';
      case PainLevel.possible: return 'Possible';
      case PainLevel.likely:   return 'Likely';
    }
  }

  static _PainAssessment from(VestStatus s, {String dogName = 'Dog'}) {
    // ── Asymmetry ───────────────────────────────────────────
    final asym = s.scapularAsymmetry;
    final total = s.fsrLeft + s.fsrRight;
    final fsrAvail = total > 200; // skip floating-input noise

    String shoulderLoad;
    int asymScore = 0;
    bool rightOffloading = false;
    double fsrL = 0, fsrR = 0;
    if (!fsrAvail) {
      shoulderLoad = '—';
    } else {
      final pct = (asym * 100).round();
      rightOffloading = s.fsrLeft > s.fsrRight;
      fsrL = (s.fsrLeft / 20000).clamp(0.0, 1.0);
      fsrR = (s.fsrRight / 20000).clamp(0.0, 1.0);
      if (asym < 0.10) {
        shoulderLoad = 'Symmetric  $pct%';
      } else {
        final side = rightOffloading ? 'right' : 'left';
        shoulderLoad = 'Off $side  $pct%';
        asymScore = asym < 0.25 ? 1 : 2;
      }
    }

    // ── Temperature ─────────────────────────────────────────
    String tempLabel;
    int tempScore = 0;
    if (s.tempBody <= -900) {
      tempLabel = '—';
    } else if (s.tempBody < 39.0) {
      tempLabel = 'Normal';
    } else if (s.tempBody < 39.5) {
      tempLabel = 'Elevated';
      tempScore = 1;
    } else {
      tempLabel = 'High — ${s.tempBody.toStringAsFixed(1)} °C';
      tempScore = 2;
    }

    // ── Heart rate ──────────────────────────────────────────
    String hrLabel;
    int hrScore = 0;
    if (s.heartRate < 0 || !s.hrValid) {
      hrLabel = '—';
    } else if (s.heartRate <= 100) {
      hrLabel = 'Normal';
    } else if (s.heartRate <= 120) {
      hrLabel = 'Elevated — ${s.heartRate} BPM';
      hrScore = 1;
    } else {
      hrLabel = 'High — ${s.heartRate} BPM';
      hrScore = 2;
    }

    // ── Activity (IMU magnitude) ─────────────────────────────
    final aMag = _vec3Mag(s.ax, s.ay, s.az);
    final gMag = _vec3Mag(s.gx, s.gy, s.gz);
    String actLabel;
    int actScore = 0;
    if (aMag < 11 && gMag < 0.3) {
      actLabel = 'Resting';
    } else if (aMag < 14 && gMag < 1.0) {
      actLabel = 'Active';
    } else {
      actLabel = 'Agitated';
      actScore = 1;
    }

    // ── Overall pain level ──────────────────────────────────
    final totalScore = asymScore + tempScore + hrScore + actScore;
    PainLevel level;
    String headline;
    String detail;

    if (totalScore == 0) {
      level = PainLevel.none;
      headline = '$dogName feels good';
      detail = 'Symmetric shoulder load · Vitals normal';
    } else if (asymScore >= 2 || totalScore >= 3) {
      level = PainLevel.likely;
      if (asymScore >= 2) {
        final side = rightOffloading ? 'right' : 'left';
        headline = 'Strong $side shoulder avoidance';
        detail = 'Heavy load shift — consider resting $dogName';
      } else {
        headline = 'Multiple pain indicators';
        detail = 'Elevated vitals + movement changes — consider resting $dogName';
      }
    } else {
      level = PainLevel.possible;
      if (asymScore >= 1) {
        final side = rightOffloading ? 'right' : 'left';
        headline = 'Compensating $side shoulder';
        detail = '$dogName is shifting weight off the $side side — could indicate discomfort';
      } else {
        headline = 'Some discomfort signs';
        detail = 'Mild elevated vitals — keep monitoring';
      }
    }

    return _PainAssessment(
      level: level,
      headline: headline,
      detail: detail,
      shoulderLoad: shoulderLoad,
      temperature: tempLabel,
      heartRate: hrLabel,
      activity: actLabel,
      fsrAvailable: fsrAvail,
      fsrLeftPct: fsrL,
      fsrRightPct: fsrR,
      rightOffloading: rightOffloading,
    );
  }

  static double _vec3Mag(double x, double y, double z) {
    final v = x * x + y * y + z * z;
    if (v <= 0) return 0;
    double r = v;
    double last;
    do { last = r; r = (r + v / r) / 2; } while ((r - last).abs() > 1e-6);
    return r;
  }
}

/// Session Log row icons (pulse / moon / lightning).
abstract final class _SessionLogIcons {
  static const String movement = 'assets/icons/session_log_movement.png';
  static const String comfort  = 'assets/icons/session_log_comfort.png';
  static const String energy   = 'assets/icons/session_log_energy.png';
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
                  // ── BLE status bar (Collar only) ─────────────────────
                  if (Get.isRegistered<BleController>() && _hideHapticQuestionnaire(_c) == false)
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
                      return _BleStatusBar(dot: dot, label: label);
                    }),
                  // ── BLE status bar (Vest only) ───────────────────────
                  if (Get.isRegistered<VestBleController>())
                    Obx(() {
                      final args = Get.arguments;
                      final isVest = args is Map && (args['moduleTitle'] as String? ?? '').toLowerCase().contains('vest');
                      if (!isVest) return const SizedBox.shrink();
                      final ble = Get.find<VestBleController>();
                      final s = ble.status.value;
                      Color dot;
                      String label;
                      switch (s) {
                        case VestBleStatus.connected:
                          dot = const Color(0xFF16D351);
                          label = 'Vest connected';
                          break;
                        case VestBleStatus.connecting:
                          dot = Colors.orange;
                          label = 'Connecting vest...';
                          break;
                        case VestBleStatus.scanning:
                          dot = Colors.orange;
                          label = 'Looking for vest...';
                          break;
                        case VestBleStatus.disconnected:
                          dot = Colors.red.shade400;
                          label = 'Vest not found — make sure it\'s on';
                          break;
                      }
                      return _BleStatusBar(dot: dot, label: label);
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
                            // ── Per-module session log ───────────────────
                            Obx(() {
                              final moduleType = _c.activeSession.value?.moduleType
                                  ?? (() {
                                final args = Get.arguments;
                                if (args is Map && args['moduleTitle'] is String) {
                                  final t = (args['moduleTitle'] as String).toLowerCase();
                                  if (t.contains('vest')) return 'vest';
                                  if (t.contains('hip')) return 'hip';
                                }
                                return 'collar';
                              })();
                              if (moduleType == 'vest') {
                                if (!Get.isRegistered<VestBleController>()) {
                                  return const SizedBox.shrink();
                                }
                                return Obx(() {
                                  final ble = Get.find<VestBleController>();
                                  final vs = ble.vestStatus.value;
                                  if (!ble.isConnected || vs == null) {
                                    return const SizedBox.shrink();
                                  }
                                  final pa = _PainAssessment.from(vs, dogName: dog?.name ?? 'Dog');
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      _VestPainCard(pa: pa),
                                      const SizedBox(height: 14),
                                      _VestSensorCollapsible(ble: ble, vs: vs),
                                    ],
                                  );
                                });
                              }
                              if (moduleType == 'hip') {
                                return _HipLogCard(
                                  mobility: _c.hipMobility.value,
                                  onMobility: (v) => _c.hipMobility.value = v,
                                  painSigns: _c.hipPainSigns.value,
                                  onPainSigns: (v) => _c.hipPainSigns.value = v,
                                  satStoodAlone: _c.hipSatStoodAlone.value,
                                  onSatStoodAlone: (v) => _c.hipSatStoodAlone.value = v,
                                );
                              }
                              // Collar (default) — live gait + sensor cards
                              if (!Get.isRegistered<BleController>()) {
                                return const SizedBox.shrink();
                              }
                              return Obx(() {
                                final ble = Get.find<BleController>();
                                final cs  = ble.collarStatus.value;
                                if (!ble.isConnected || cs == null) {
                                  return const SizedBox.shrink();
                                }
                                final ga = _GaitAssessment.from(cs,
                                    dogName: dog?.name ?? 'Dog');
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    if (cs.stormMode)
                                      _StormShieldCard(pressure: cs.pressure),
                                    if (cs.stormMode) const SizedBox(height: 14),
                                    _CollarGaitCard(ga: ga),
                                    const SizedBox(height: 14),
                                    _CollarSensorCollapsible(cs: cs),
                                  ],
                                );
                              });
                            }),
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

// ── Vest Pain Assessment Card ─────────────────────────────────────────────────

class _VestPainCard extends StatelessWidget {
  const _VestPainCard({required this.pa});
  final _PainAssessment pa;

  Color _sigColor(String val) {
    if (val == 'Normal' || val == 'Symmetric' || val.startsWith('Symmetric')) {
      return const Color(0xFF16D351);
    }
    if (val.startsWith('High') || val.startsWith('Strong') || val.startsWith('Likely')) {
      return const Color(0xFFFF4C6A);
    }
    if (val == '—' || val == 'Resting' || val == 'Active') return Colors.white70;
    return const Color(0xFFFFB347);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pa.borderColor.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header row ───────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PAIN',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  decoration: TextDecoration.none,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: pa.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: pa.accentColor.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(
                        color: pa.accentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      pa.badgeText,
                      style: TextStyle(
                        color: pa.accentColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ── Headline ─────────────────────────────────────
          Text(
            pa.headline,
            style: TextStyle(
              color: pa.accentColor,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            pa.detail,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 13,
              height: 1.4,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 14),
          // ── Signal rows ───────────────────────────────────
          _PainSignalRow(label: 'Shoulder load', value: pa.shoulderLoad, valueColor: _sigColor(pa.shoulderLoad)),
          _PainSignalRow(label: 'Temperature',   value: pa.temperature,  valueColor: _sigColor(pa.temperature)),
          _PainSignalRow(label: 'Heart rate',    value: pa.heartRate,    valueColor: _sigColor(pa.heartRate)),
          _PainSignalRow(label: 'Activity',      value: pa.activity,     valueColor: _sigColor(pa.activity)),
          // ── Shoulder balance bars ─────────────────────────
          if (pa.fsrAvailable) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Colors.white12),
            const SizedBox(height: 10),
            Text(
              'SHOULDER BALANCE',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 8),
            _ShoulderBar(label: 'Left',  value: pa.fsrLeftPct,  offloading: !pa.rightOffloading),
            const SizedBox(height: 5),
            _ShoulderBar(label: 'Right', value: pa.fsrRightPct, offloading: pa.rightOffloading),
          ],
        ],
      ),
    );
  }
}

class _PainSignalRow extends StatelessWidget {
  const _PainSignalRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });
  final String label;
  final String value;
  final Color  valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white12, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13, decoration: TextDecoration.none)),
          Text(value,  style: TextStyle(color: valueColor, fontSize: 13, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
        ],
      ),
    );
  }
}

class _ShoulderBar extends StatelessWidget {
  const _ShoulderBar({required this.label, required this.value, required this.offloading});
  final String label;
  final double value;
  final bool   offloading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 38,
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kFsrColor.withValues(alpha: 0.9), decoration: TextDecoration.none)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 9,
              backgroundColor: Colors.white.withValues(alpha: 0.07),
              valueColor: AlwaysStoppedAnimation<Color>(
                offloading ? _kFsrColor.withValues(alpha: 0.35) : _kFsrColor,
              ),
            ),
          ),
        ),
        if (offloading) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB347).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFFFB347).withValues(alpha: 0.4)),
            ),
            child: const Text(
              'offloading',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFFFFB347), decoration: TextDecoration.none),
            ),
          ),
        ] else
          const SizedBox(width: 70),
      ],
    );
  }
}

// ── Collapsible sensor data ───────────────────────────────────────────────────

class _VestSensorCollapsible extends StatefulWidget {
  const _VestSensorCollapsible({required this.ble, required this.vs});
  final VestBleController ble;
  final VestStatus vs;

  @override
  State<_VestSensorCollapsible> createState() => _VestSensorCollapsibleState();
}

class _VestSensorCollapsibleState extends State<_VestSensorCollapsible>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    _open ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final ble = widget.ble;
    final vs  = widget.vs;
    final aMag = _PainAssessment._vec3Mag(vs.ax, vs.ay, vs.az);
    final gMag = _PainAssessment._vec3Mag(vs.gx, vs.gy, vs.gz);

    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Toggle row ──────────────────────────────────
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ver datos',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 260),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        color: Colors.white.withValues(alpha: 0.3), size: 20),
                  ),
                ],
              ),
            ),
          ),
          // ── Expandable body ─────────────────────────────
          SizeTransition(
            sizeFactor: _anim,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(height: 1, color: Colors.white12),
                  const SizedBox(height: 12),
                  // ── Vitals grid ──────────────────────────
                  Row(children: [
                    Expanded(child: _DataTile(label: 'Heart Rate', value: ble.hrValid ? '${ble.heartRate} BPM' : '—', color: _kHrColor)),
                    const SizedBox(width: 8),
                    Expanded(child: _DataTile(label: 'SpO₂',      value: ble.spo2Valid ? '${ble.spo2}%' : '—',       color: _kSpo2Color)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _DataTile(label: 'Body Temp', value: vs.tempBody > -900 ? '${vs.tempBody.toStringAsFixed(1)} °C' : '—', color: _kTempColor)),
                    const SizedBox(width: 8),
                    Expanded(child: _DataTile(label: 'Ambient',   value: vs.tempAmbient > -900 ? '${vs.tempAmbient.toStringAsFixed(1)} °C  ${vs.humidity.toStringAsFixed(0)}%' : '—', color: Colors.white38)),
                  ]),
                  const SizedBox(height: 12),
                  // ── Movement ─────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _kImuColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: _kImuColor.withValues(alpha: 0.18)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Movement', style: TextStyle(color: _kImuColor.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
                        const SizedBox(height: 4),
                        Text(
                          '|a| ${aMag.toStringAsFixed(2)} m/s²   |ω| ${gMag.toStringAsFixed(2)} rad/s',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700, decoration: TextDecoration.none),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ax ${vs.ax.toStringAsFixed(2)}  ay ${vs.ay.toStringAsFixed(2)}  az ${vs.az.toStringAsFixed(2)}',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10, decoration: TextDecoration.none),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // ── Raw FSR ───────────────────────────────
                  Text(
                    'Shoulder pressure — raw',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.4, decoration: TextDecoration.none),
                  ),
                  const SizedBox(height: 6),
                  _RawRow(label: 'Left',       value: '${vs.fsrLeft}  /  32767'),
                  _RawRow(label: 'Right',      value: '${vs.fsrRight}  /  32767'),
                  _RawRow(label: 'Asymmetry',  value: '${(vs.scapularAsymmetry * 100).round()}%'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DataTile extends StatelessWidget {
  const _DataTile({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 10, decoration: TextDecoration.none)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color == Colors.white38 ? Colors.white70 : Colors.white, fontSize: 14, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
        ],
      ),
    );
  }
}

class _RawRow extends StatelessWidget {
  const _RawRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.35), decoration: TextDecoration.none)),
          Text(value,  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5),  fontFamily: 'monospace', decoration: TextDecoration.none)),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// The rest of the file is UNCHANGED from the original session_live_view.dart
// ──────────────────────────────────────────────────────────────────────────────

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

// ── Hip Session Log ───────────────────────────────────────────────────────────
class _HipLogCard extends StatelessWidget {
  const _HipLogCard({
    required this.mobility,
    required this.onMobility,
    required this.painSigns,
    required this.onPainSigns,
    required this.satStoodAlone,
    required this.onSatStoodAlone,
  });

  final int mobility;
  final ValueChanged<int> onMobility;
  final int painSigns;
  final ValueChanged<int> onPainSigns;
  final int satStoodAlone;
  final ValueChanged<int> onSatStoodAlone;

  @override
  Widget build(BuildContext context) {
    return _GoldBorderCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ScoreRow(
            label: 'Mobility',
            value: mobility,
            max: 5,
            color: const Color(0xFF8B44F7),
            low: 'Very limited',
            high: 'Full mobility',
            onChanged: onMobility,
          ),
          const Divider(height: 28, color: Colors.white12),
          _OptionRow(
            label: 'Pain Signs',
            options: const ['None', 'Mild', 'Moderate', 'Severe'],
            selected: painSigns,
            onChanged: onPainSigns,
          ),
          const Divider(height: 28, color: Colors.white12),
          _OptionRow(
            label: 'Sat/Stood alone',
            options: const ['—', 'Yes', 'No'],
            selected: satStoodAlone,
            onChanged: onSatStoodAlone,
          ),
        ],
      ),
    );
  }
}

// ── Shared subwidgets ─────────────────────────────────────────────────────────

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
    required this.low,
    required this.high,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int max;
  final Color color;
  final String low;
  final String high;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.none,
              ),
            ),
            Text(
              '$value / $max',
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(max, (i) {
            final score = i + 1;
            final selected = score == value;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < max - 1 ? 6 : 0),
                child: GestureDetector(
                  onTap: () => onChanged(score),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? color : const Color(0xFF0A0F1E),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected ? color : Colors.white.withValues(alpha: 0.25),
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      '$score',
                      style: TextStyle(
                        color: selected ? Colors.black : Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(low, style: _caption),
            Text(high, style: _caption),
          ],
        ),
      ],
    );
  }

  static final _caption = TextStyle(
    color: Colors.white.withValues(alpha: 0.4),
    fontSize: 11,
    decoration: TextDecoration.none,
  );
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(options.length, (i) {
            final sel = i == selected;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < options.length - 1 ? 8 : 0),
                child: GestureDetector(
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: sel ? AppColors.signaraGold : const Color(0xFF0A0F1E),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: sel ? AppColors.signaraGold : Colors.white.withValues(alpha: 0.25),
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      options[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: sel ? Colors.black : Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _BleStatusBar extends StatelessWidget {
  const _BleStatusBar({required this.dot, required this.label});
  final Color dot;
  final String label;

  @override
  Widget build(BuildContext context) {
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
      icon: const Icon(Icons.upload_file_outlined, color: Colors.white, size: 20),
      label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.white, width: 1.2),
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

// ══════════════════════════════════════════════════════════════════════════════
// COLLAR — GAIT ASSESSMENT (espejo de _PainAssessment del vest)
// ══════════════════════════════════════════════════════════════════════════════

enum _GaitLevel { good, watch, alert }

class _GaitAssessment {
  final _GaitLevel level;
  final String headline;
  final String detail;
  final String gaitBalance;   // "Symmetric 3%" / "Asymmetric 18%"
  final String heartRate;     // "Normal" / "Elevated — 118 BPM"
  final String spo2;          // "Normal" / "Low — 92%"
  final String temperature;   // "Normal" / "Elevated 39.2 °C"
  final String cadence;       // "94 steps/min" / "—"
  final double asymmetryPct;  // 0.0–1.0 para barra
  final int    coughCount;

  const _GaitAssessment({
    required this.level,
    required this.headline,
    required this.detail,
    required this.gaitBalance,
    required this.heartRate,
    required this.spo2,
    required this.temperature,
    required this.cadence,
    required this.asymmetryPct,
    required this.coughCount,
  });

  Color get borderColor {
    switch (level) {
      case _GaitLevel.good:  return const Color(0xFF16D351);
      case _GaitLevel.watch: return const Color(0xFFFFB347);
      case _GaitLevel.alert: return const Color(0xFFFF4C6A);
    }
  }

  Color get accentColor => borderColor;

  String get badgeText {
    switch (level) {
      case _GaitLevel.good:  return 'Good';
      case _GaitLevel.watch: return 'Watch';
      case _GaitLevel.alert: return 'Alert';
    }
  }

  static _GaitAssessment from(CollarStatus s, {String dogName = 'Dog'}) {
    int score = 0;

    // ── Head-bob asymmetry ────────────────────────────────
    String gaitBalance;
    int asymScore = 0;
    double asymPct = 0;
    if (!s.hasGaitData || s.headBobAsymmetry < 0) {
      gaitBalance = '—';
    } else {
      asymPct = s.headBobAsymmetry.clamp(0.0, 1.0);
      final pctInt = (asymPct * 100).round();
      if (asymPct < 0.10) {
        gaitBalance = 'Symmetric  $pctInt%';
      } else if (asymPct < 0.25) {
        gaitBalance = 'Asymmetric  $pctInt%';
        asymScore = 1;
      } else {
        gaitBalance = 'Asymmetric  $pctInt%';
        asymScore = 2;
      }
    }
    score += asymScore;

    // ── Heart rate ────────────────────────────────────────
    String hrLabel;
    int hrScore = 0;
    if (s.heartRate < 0 || !s.hrValid) {
      hrLabel = '—';
    } else if (s.heartRate <= 100) {
      hrLabel = 'Normal';
    } else if (s.heartRate <= 120) {
      hrLabel = 'Elevated — ${s.heartRate} BPM';
      hrScore = 1;
    } else {
      hrLabel = 'High — ${s.heartRate} BPM';
      hrScore = 2;
    }
    score += hrScore;

    // ── SpO2 ──────────────────────────────────────────────
    String spo2Label;
    int spo2Score = 0;
    if (s.spo2 < 0 || !s.spo2Valid) {
      spo2Label = '—';
    } else if (s.spo2 >= 95) {
      spo2Label = 'Normal';
    } else if (s.spo2 >= 90) {
      spo2Label = 'Low — ${s.spo2}%';
      spo2Score = 1;
    } else {
      spo2Label = 'Very low — ${s.spo2}%';
      spo2Score = 2;
    }
    score += spo2Score;

    // ── Temperature ───────────────────────────────────────
    String tempLabel;
    int tempScore = 0;
    if (s.tempBody <= 0) {
      tempLabel = '—';
    } else if (s.tempBody < 39.0) {
      tempLabel = 'Normal';
    } else if (s.tempBody < 39.5) {
      tempLabel = 'Elevated  ${s.tempBody.toStringAsFixed(1)} °C';
      tempScore = 1;
    } else {
      tempLabel = 'High  ${s.tempBody.toStringAsFixed(1)} °C';
      tempScore = 2;
    }
    score += tempScore;

    // ── Cadence ───────────────────────────────────────────
    final cadenceLabel = s.gaitCadence >= 0
        ? '${s.gaitCadence.toStringAsFixed(0)} steps/min'
        : '—';

    // ── Overall level ─────────────────────────────────────
    _GaitLevel level;
    String headline;
    String detail;

    if (score == 0) {
      level    = _GaitLevel.good;
      headline = '$dogName\'s gait looks good';
      detail   = 'Symmetric stride · Vitals normal';
    } else if (asymScore >= 2 || score >= 3) {
      level    = _GaitLevel.alert;
      if (asymScore >= 2) {
        headline = 'Significant gait asymmetry';
        detail   = 'Head bob detected — may indicate lameness';
      } else {
        headline = 'Multiple indicators elevated';
        detail   = 'Gait + vitals out of range — consider stopping';
      }
    } else {
      level    = _GaitLevel.watch;
      if (asymScore >= 1) {
        headline = 'Mild gait asymmetry';
        detail   = '$dogName is compensating — keep monitoring';
      } else {
        headline = 'Some indicators elevated';
        detail   = 'Mild changes in vitals — keep monitoring';
      }
    }

    return _GaitAssessment(
      level:        level,
      headline:     headline,
      detail:       detail,
      gaitBalance:  gaitBalance,
      heartRate:    hrLabel,
      spo2:         spo2Label,
      temperature:  tempLabel,
      cadence:      cadenceLabel,
      asymmetryPct: asymPct,
      coughCount:   s.coughEvents,
    );
  }
}

// ── Collar Gait Card ──────────────────────────────────────────────────────────

class _CollarGaitCard extends StatelessWidget {
  const _CollarGaitCard({required this.ga});
  final _GaitAssessment ga;

  Color _sigColor(String val) {
    if (val == 'Normal' || val.startsWith('Symmetric') || val == 'Good') {
      return const Color(0xFF16D351);
    }
    if (val.startsWith('High') || val.startsWith('Very') || val.startsWith('Alert') ||
        val.startsWith('Significant')) {
      return const Color(0xFFFF4C6A);
    }
    if (val == '—' || val == 'Resting') return Colors.white70;
    return const Color(0xFFFFB347);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ga.borderColor.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header row ──────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'GAIT',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  decoration: TextDecoration.none,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: ga.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: ga.accentColor.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(
                        color: ga.accentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      ga.badgeText,
                      style: TextStyle(
                        color: ga.accentColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ── Headline ─────────────────────────────────────
          Text(
            ga.headline,
            style: TextStyle(
              color: ga.accentColor,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            ga.detail,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 13,
              height: 1.4,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 14),
          // ── Signal rows ───────────────────────────────────
          _PainSignalRow(label: 'Gait balance', value: ga.gaitBalance,  valueColor: _sigColor(ga.gaitBalance)),
          _PainSignalRow(label: 'Heart rate',   value: ga.heartRate,    valueColor: _sigColor(ga.heartRate)),
          _PainSignalRow(label: 'SpO₂',         value: ga.spo2,         valueColor: _sigColor(ga.spo2)),
          _PainSignalRow(label: 'Temperature',  value: ga.temperature,  valueColor: _sigColor(ga.temperature)),
          _PainSignalRow(label: 'Cadence',      value: ga.cadence,      valueColor: Colors.white70),
          if (ga.coughCount > 0)
            _PainSignalRow(
              label: 'Vocalizations',
              value: '${ga.coughCount} detected',
              valueColor: const Color(0xFFFFB347),
            ),
          // ── Asymmetry bar ─────────────────────────────────
          if (ga.asymmetryPct > 0) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Colors.white12),
            const SizedBox(height: 10),
            Text(
              'HEAD-BOB ASYMMETRY',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ga.asymmetryPct,
                    minHeight: 9,
                    backgroundColor: Colors.white.withValues(alpha: 0.07),
                    valueColor: AlwaysStoppedAnimation<Color>(ga.borderColor),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(ga.asymmetryPct * 100).round()}%',
                style: TextStyle(
                  color: ga.borderColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

// ── Collar Sensor Collapsible ─────────────────────────────────────────────────

class _CollarSensorCollapsible extends StatefulWidget {
  const _CollarSensorCollapsible({required this.cs});
  final CollarStatus cs;

  @override
  State<_CollarSensorCollapsible> createState() => _CollarSensorCollapsibleState();
}

class _CollarSensorCollapsibleState extends State<_CollarSensorCollapsible>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    _open ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Toggle row ──────────────────────────────────
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ver datos',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 260),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        color: Colors.white.withValues(alpha: 0.3), size: 20),
                  ),
                ],
              ),
            ),
          ),
          // ── Expandable body ─────────────────────────────
          SizeTransition(
            sizeFactor: _anim,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(height: 1, color: Colors.white12),
                  const SizedBox(height: 12),
                  // ── Vitals grid ──────────────────────────
                  Row(children: [
                    Expanded(child: _DataTile(
                      label: 'Heart Rate',
                      value: cs.hrValid ? '${cs.heartRate} BPM' : '—',
                      color: _kHrColor,
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: _DataTile(
                      label: 'SpO₂',
                      value: cs.spo2Valid ? '${cs.spo2}%' : '—',
                      color: _kSpo2Color,
                    )),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _DataTile(
                      label: 'Body Temp',
                      value: cs.tempBody > 0 ? '${cs.tempBody.toStringAsFixed(1)} °C' : '—',
                      color: _kTempColor,
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: _DataTile(
                      label: 'Ambient',
                      value: cs.tempAmbient > 0
                          ? '${cs.tempAmbient.toStringAsFixed(1)} °C  ${cs.humidity.toStringAsFixed(0)}%'
                          : '—',
                      color: Colors.white38,
                    )),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _DataTile(
                      label: 'Pressure',
                      value: cs.pressure > 0 ? '${cs.pressure.toStringAsFixed(1)} hPa' : '—',
                      color: const Color(0xFF7B68EE),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: _DataTile(
                      label: 'LDT',
                      value: '${cs.ldtValue}',
                      color: _kImuColor,
                    )),
                  ]),
                  if (cs.hasGaitData) ...[
                    const SizedBox(height: 12),
                    // ── Gait raw ──────────────────────────
                    Text(
                      'Gait — raw',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _RawRow(label: 'Head-bob asym', value: '${(cs.headBobAsymmetry * 100).round()}%'),
                    if (cs.gaitCadence >= 0)
                      _RawRow(label: 'Cadence',      value: '${cs.gaitCadence.toStringAsFixed(1)} steps/min'),
                    if (cs.gaitVariability >= 0)
                      _RawRow(label: 'Variability',  value: '${(cs.gaitVariability * 100).round()}%'),
                    _RawRow(label: 'Vocalizations',  value: '${cs.coughEvents}'),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Storm Shield Card (ámbar — aparece cuando stormMode activo) ───────────────

class _StormShieldCard extends StatelessWidget {
  const _StormShieldCard({required this.pressure});
  final double pressure;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1400),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFB347).withValues(alpha: 0.7), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🌩️', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Storm Shield Active',
                  style: TextStyle(
                    color: Color(0xFFFFB347),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB347).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFB347).withValues(alpha: 0.5)),
                ),
                child: const Text(
                  'Triggered',
                  style: TextStyle(
                    color: Color(0xFFFFB347),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Rapid pressure drop detected — a storm may be approaching in 30–45 min.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 13,
              height: 1.4,
              decoration: TextDecoration.none,
            ),
          ),
          if (pressure > 0) ...[
            const SizedBox(height: 10),
            Text(
              'Current: ${pressure.toStringAsFixed(1)} hPa',
              style: const TextStyle(
                color: Color(0xFFFFB347),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
