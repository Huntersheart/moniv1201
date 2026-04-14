import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../data/models/session_model.dart';
import '../../data/repositories/dog_repository.dart';
import '../../data/repositories/session_repository.dart';
import 'auth_controller.dart';
import 'dashboard_controller.dart';

class SessionLiveController extends GetxController {
  final SessionRepository _sessionRepo;
  final DogRepository _dogRepo;

  SessionLiveController(this._sessionRepo, this._dogRepo);

  final isLoading = false.obs;
  final Rxn<SessionModel> activeSession = Rxn<SessionModel>();

  final elapsedSeconds = 0.obs;
  Timer? _timer;
  Timer? _firestoreSyncTimer;
  bool _bootstrapped = false;

  final hapticOn = true.obs;
  final hapticPresetIndex = 0.obs;
  final intensity = 3.0.obs;

  final movement = 3.0.obs;
  final comfort = 3.0.obs;
  final energy = 3.0.obs;

  final limpLevel = 0.obs;
  final responseLevel = 0.obs;
  final calmingLevel = 3.obs;

  final noteController = TextEditingController();
  final photoUrl = ''.obs;
  final videoUrl = ''.obs;

  /// Matches live session UI chips: Calm / Moderate / Strong.
  static const List<String> hapticPresets = ['Calm', 'Moderate', 'Strong'];

  static const Duration _firestoreSyncInterval = Duration(seconds: 12);

  String get elapsedDisplay {
    final h = elapsedSeconds.value ~/ 3600;
    final m = (elapsedSeconds.value % 3600) ~/ 60;
    final s = elapsedSeconds.value % 60;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  @override
  void onClose() {
    _timer?.cancel();
    _firestoreSyncTimer?.cancel();
    noteController.dispose();
    _bootstrapped = false;
    super.onClose();
  }

  String _moduleTypeFromTitle(String title) {
    final t = title.toLowerCase();
    if (t.contains('collar')) return 'collar';
    if (t.contains('vest')) return 'vest';
    if (t.contains('hip')) return 'hip';
    return 'other';
  }

  Future<String> _resolveDogName(String userId, String dogId) async {
    if (Get.isRegistered<DashboardController>()) {
      final dash = Get.find<DashboardController>();
      final sel = dash.selectedDog;
      if (sel != null && sel.dogId == dogId) return sel.name;
      for (final d in dash.dogs) {
        if (d.dogId == dogId) return d.name;
      }
    }
    final doc = await _dogRepo.getDog(userId: userId, dogId: dogId);
    return doc?.name ?? '';
  }

  void _startFirestoreSyncTimer() {
    _firestoreSyncTimer?.cancel();
    _firestoreSyncTimer = Timer.periodic(_firestoreSyncInterval, (_) {
      unawaited(_pushActiveProgressToFirestore());
    });
  }

  void _stopFirestoreSyncTimer() {
    _firestoreSyncTimer?.cancel();
    _firestoreSyncTimer = null;
  }

  Future<void> _pushActiveProgressToFirestore() async {
    final s = activeSession.value;
    if (s == null || s.status != 'active') return;
    try {
      final presetIdx = hapticPresetIndex.value.clamp(0, hapticPresets.length - 1);
      await _sessionRepo.syncActiveSessionProgress(
        sessionId: s.sessionId,
        durationSeconds: elapsedSeconds.value,
        movement: movement.value,
        comfort: comfort.value,
        energy: energy.value,
        limpLevel: limpLevel.value,
        responseLevel: responseLevel.value,
        calmingLevel: calmingLevel.value,
        hapticPreset: hapticPresets[presetIdx],
        intensity: intensity.value,
        hapticOn: hapticOn.value,
        notes: noteController.text.trim(),
        photoUrl: photoUrl.value,
        videoUrl: videoUrl.value,
      );
    } catch (e) {
      debugPrint('[SessionLive] Firestore sync: $e');
    }
  }

  /// Call once when [SessionLiveView] opens (uses route [Get.arguments]).
  Future<void> bootstrapFromRoute(dynamic rawArgs) async {
    if (_bootstrapped) return;
    _bootstrapped = true;

    final Map<String, dynamic> map;
    if (rawArgs is Map) {
      map = Map<String, dynamic>.from(rawArgs);
    } else {
      map = <String, dynamic>{};
    }
    var dogId = map['dogId'] as String? ?? '';
    if (dogId.isEmpty && Get.isRegistered<DashboardController>()) {
      dogId = Get.find<DashboardController>().selectedDog?.dogId ?? '';
    }
    if (dogId.isEmpty) {
      _bootstrapped = false;
      _snack('Dog required', 'Select a dog on the home screen first.');
      Get.back<void>();
      return;
    }

    final deviceLabel = map['moduleTitle'] as String? ?? 'SIGNARA™ Collar';
    await startSession(
      dogId: dogId,
      deviceLabel: deviceLabel,
      moduleType: _moduleTypeFromTitle(deviceLabel),
    );
    if (activeSession.value == null) {
      _bootstrapped = false;
    }
  }

  Future<void> abandonSession() async {
    _stopFirestoreSyncTimer();
    _timer?.cancel();
    final session = activeSession.value;
    if (session != null && session.status == 'active') {
      try {
        await _sessionRepo.deleteSession(session.sessionId);
      } catch (e) {
        debugPrint('[SessionLive] abandon delete: $e');
      }
    }
    activeSession.value = null;
    _bootstrapped = false;
  }

  Future<void> startSession({
    required String dogId,
    required String deviceLabel,
    String moduleType = 'training',
  }) async {
    final uid = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>().currentUser.value?.uid ?? ''
        : '';
    if (uid.isEmpty) {
      _snack('Not signed in', 'Please sign in before starting a session.');
      return;
    }

    isLoading.value = true;
    try {
      photoUrl.value = '';
      videoUrl.value = '';
      final dogName = await _resolveDogName(uid, dogId);
      final now = DateTime.now();
      final session = SessionModel(
        sessionId: '',
        userId: uid,
        dogId: dogId,
        dogName: dogName,
        deviceLabel: deviceLabel,
        moduleType: moduleType,
        status: 'active',
        startTime: now,
        createdAt: now,
      );
      activeSession.value = await _sessionRepo.createSession(session);
      _startTimer();
      _startFirestoreSyncTimer();
      unawaited(_pushActiveProgressToFirestore());
    } catch (e) {
      debugPrint('[SessionLive] start error: $e');
      _snack('Error', 'Could not start session. Check your connection.');
    } finally {
      isLoading.value = false;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    elapsedSeconds.value = 0;
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => elapsedSeconds.value++,
    );
  }

  Future<void> endSession() async {
    _stopFirestoreSyncTimer();
    _timer?.cancel();
    final session = activeSession.value;
    if (session == null) {
      Get.offAllNamed(AppRoutes.home);
      return;
    }

    isLoading.value = true;
    try {
      final presetIdx = hapticPresetIndex.value.clamp(0, hapticPresets.length - 1);
      final completed = await _sessionRepo.endSession(
        sessionId: session.sessionId,
        durationSeconds: elapsedSeconds.value,
        movement: movement.value,
        comfort: comfort.value,
        energy: energy.value,
        limpLevel: limpLevel.value,
        responseLevel: responseLevel.value,
        calmingLevel: calmingLevel.value,
        hapticPreset: hapticPresets[presetIdx],
        intensity: intensity.value,
        hapticOn: hapticOn.value,
        notes: noteController.text.trim(),
        photoUrl: photoUrl.value,
        videoUrl: videoUrl.value,
      );
      activeSession.value = completed;
      Get.offNamed(AppRoutes.sessionSummary, arguments: {'session': completed});
    } catch (e) {
      debugPrint('[SessionLive] end error: $e');
      _snack('Error', 'Could not save session. Try again.');
    } finally {
      isLoading.value = false;
    }
  }

  void _snack(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      backgroundColor: const Color(0xFF2A2A2A),
      colorText: Colors.white,
    );
  }
}
