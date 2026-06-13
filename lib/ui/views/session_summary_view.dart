import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

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
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17, fontWeight: FontWeight.w800, decoration: TextDecoration.none),
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

  static const Color _cardBg = Color(0xFF0D1B2A);
  static const Color _valueGreen = Color(0xff00C853);

  @override
  Widget build(BuildContext context) {
    final s = session;
    final hideHaptic = s.isVestOrHipModule;
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
              if (!hideHaptic)
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
                )
              else
                _labelValue(
                  label: 'Intensity',
                  value: '${s.intensityScore10}/10',
                  valueColor: _valueGreen,
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
              if (!hideHaptic) ...[
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
              ],
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
                  border: Border.all(color: Colors.white),
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
                _MediaImage(url: s.photoUrl.trim())
              else
                _MediaEmpty(label: 'Session Image not uploaded'),
              const SizedBox(height: 12),
              if (s.videoUrl.trim().isNotEmpty)
                _MediaVideo(
                  key: ValueKey<String>(s.videoUrl.trim()),
                  url: s.videoUrl.trim(),
                )
              else
                _MediaEmpty(label: 'Session Video not uploaded'),
              const SizedBox(height: 12),
              Text(
                'Stored in Firebase for this dog session.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 12,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
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
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            // decoration: TextDecoration.none,
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

class _MediaImage extends StatelessWidget {
  const _MediaImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Session Image',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              progressIndicatorBuilder: (context, imageUrl, progress) {
                return Container(
                  color: Colors.black26,
                  alignment: Alignment.center,
                  child: CircularProgressIndicator(
                    color: AppColors.signaraGold,
                    value: progress.progress,
                  ),
                );
              },
              errorWidget: (context, imageUrl, error) => Container(
                color: Colors.black26,
                alignment: Alignment.center,
                child: Text(
                  'Could not load image',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MediaEmpty extends StatelessWidget {
  const _MediaEmpty({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.65),
          fontSize: 13,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

class _MediaVideo extends StatefulWidget {
  const _MediaVideo({super.key, required this.url});

  final String url;

  @override
  State<_MediaVideo> createState() => _MediaVideoState();
}

class _MediaVideoState extends State<_MediaVideo> {
  static const double _videoWidth = 318;
  static const double _videoHeight = 212;

  VideoPlayerController? _controller;
  Future<void>? _initFuture;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _setupController();
  }

  @override
  void didUpdateWidget(covariant _MediaVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _controller?.dispose();
      _setupController();
      setState(() {});
    }
  }

  void _setupController() {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _initFuture = _controller!.initialize().then((_) {
      _controller?.setLooping(true);
    });
  }

  static String _fmt(Duration d) {
    final totalSeconds = d.inSeconds;
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  Future<void> _seekBy(Duration delta) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final max = c.value.duration;
    var target = c.value.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (target > max) target = max;
    await c.seekTo(target);
  }

  Future<void> _toggleMute() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (_isMuted) {
      await c.setVolume(1);
    } else {
      await c.setVolume(0);
    }
    if (mounted) setState(() => _isMuted = !_isMuted);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Session Video',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: _videoWidth,
            height: _videoHeight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: Colors.black45,
                child: FutureBuilder<void>(
                  future: _initFuture,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppColors.signaraGold),
                      );
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Text(
                          'Could not load video',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      );
                    }
                    final size = c.value.size;
                    final safeW = size.width <= 0 ? 16.0 : size.width;
                    final safeH = size.height <= 0 ? 9.0 : size.height;
                    return ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: c,
                      builder: (context, value, _) {
                        return FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width: safeW,
                            height: safeH,
                            child: VideoPlayer(c),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: c,
          builder: (context, value, _) {
            final total = value.duration;
            final position = value.position > total ? total : value.position;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: VideoProgressIndicator(
                    c,
                    allowScrubbing: true,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    colors: VideoProgressColors(
                      playedColor: AppColors.signaraGold,
                      bufferedColor: Colors.white38,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _fmt(position),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 12,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      Text(
                        _fmt(total),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 12,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => _seekBy(const Duration(seconds: -10)),
                        icon: const Icon(
                          Icons.replay_10_rounded,
                          color: AppColors.signaraGold,
                          size: 28,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          if (value.isPlaying) {
                            c.pause();
                          } else {
                            c.play();
                          }
                          setState(() {});
                        },
                        icon: Icon(
                          value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                          color: AppColors.signaraGold,
                          size: 36,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _seekBy(const Duration(seconds: 10)),
                        icon: const Icon(
                          Icons.forward_10_rounded,
                          color: AppColors.signaraGold,
                          size: 28,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _toggleMute,
                        icon: Icon(
                          _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                          color: AppColors.signaraGold,
                          size: 24,
                        ),
                      ),
                    ],
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
