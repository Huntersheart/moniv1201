import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/session_model.dart';
import '../controllers/session_summary_controller.dart';
import '../widgets/signara_dashboard_background.dart';

/// Completed session detail — data from Firestore via [SessionSummaryController]
/// (`arguments['session']` or `arguments['sessionId']`).
class SessionSummaryView extends GetView<SessionSummaryController> {
  const SessionSummaryView({super.key});

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
            const SignaraDashboardBackground(),
            SafeArea(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.signaraGold),
                  );
                }
                final s = controller.session.value;
                if (s == null) {
                  return _EmptySummary(onBack: () => Get.back<void>());
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 16, 8),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Get.back<void>(),
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                          ),
                          const Expanded(
                            child: Text(
                              'Session Summary',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: _SummaryContent(session: s),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: () => Get.offAllNamed<void>(AppRoutes.home),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.signaraGold,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text(
                            'Back to Dashboard',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, decoration: TextDecoration.none),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySummary extends StatelessWidget {
  const _EmptySummary({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Session not found',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 16),
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: onBack, child: const Text('Back')),
        ],
      ),
    );
  }
}

class _SummaryContent extends StatelessWidget {
  const _SummaryContent({required this.session});

  final SessionModel session;

  static const Color _cardBg = Color(0xFF1E1E1E);
  static const Color _valueGreen = Color(0xFF66BB6A);

  @override
  Widget build(BuildContext context) {
    final s = session;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cardBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s.dateDisplay,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.none,
                ),
              ),
              if (s.dogName.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                _labelValue(
                  label: 'Dog',
                  value: s.dogName.trim(),
                  valueColor: Colors.white70,
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _labelValue(
                      label: 'Duration',
                      value: s.durationDisplay,
                      valueColor: _valueGreen,
                    ),
                  ),
                  Expanded(
                    child: _labelValue(
                      label: 'Device',
                      value: s.deviceDisplayName,
                      valueColor: _valueGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _labelValue(
                      label: 'Haptic Control',
                      value: s.hapticPreset,
                      valueColor: _valueGreen,
                    ),
                  ),
                  Expanded(
                    child: _labelValue(
                      label: 'Intensity',
                      value: '${s.intensityScore10}/10',
                      valueColor: _valueGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _labelValue(
                      label: 'Session Type',
                      value: s.sessionTypeDisplay,
                      valueColor: _valueGreen,
                    ),
                  ),
                  Expanded(
                    child: _labelValue(
                      label: 'Haptic on',
                      value: s.hapticOn ? 'Yes' : 'No',
                      valueColor: Colors.white70,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _labelValue(
                label: 'Overall Calming Effect',
                value: '${s.calmingEffectDisplayLabel} (${s.calmingLevel}/5)',
                valueColor: AppColors.signaraGold,
              ),
              const SizedBox(height: 14),
              _labelValue(
                label: 'Response to Haptic',
                value: s.responseDisplayLabel,
                valueColor: _valueGreen,
              ),
              const SizedBox(height: 8),
              _labelValue(
                label: 'Limp',
                value: s.limpDisplayLabel,
                valueColor: Colors.white70,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _cardBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Session Scores',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 16),
              _avgBar(
                label: 'Movement',
                value: s.movementScore10,
                color: AppColors.sessionMovementGreen,
              ),
              const SizedBox(height: 14),
              _avgBar(
                label: 'Comfort',
                value: s.comfortScore10,
                color: AppColors.sessionComfortPurple,
              ),
              const SizedBox(height: 14),
              _avgBar(
                label: 'Energy',
                value: s.energyScore10,
                color: AppColors.signaraGold,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _cardBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Notes',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                ),
                child: Text(
                  s.notes.isEmpty ? 'No notes for this session.' : s.notes,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                    height: 1.45,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (s.photoUrl.trim().isNotEmpty || s.videoUrl.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          _cardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Media',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 12),
                if (s.photoUrl.trim().isNotEmpty)
                  _labelValue(
                    label: 'Photo URL',
                    value: s.photoUrl.trim(),
                    valueColor: _valueGreen,
                  ),
                if (s.photoUrl.trim().isNotEmpty && s.videoUrl.trim().isNotEmpty)
                  const SizedBox(height: 12),
                if (s.videoUrl.trim().isNotEmpty)
                  _labelValue(
                    label: 'Video URL',
                    value: s.videoUrl.trim(),
                    valueColor: _valueGreen,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _cardBox({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: child,
    );
  }

  Widget _labelValue({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }

  Widget _avgBar({
    required String label,
    required int value,
    required Color color,
  }) {
    final t = (value / 10).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
                decoration: TextDecoration.none,
              ),
            ),
            Text(
              '$value/10',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final fillW = (w * t).clamp(0.0, w);
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 10,
                  width: w,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                Container(
                  height: 10,
                  width: fillW,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
