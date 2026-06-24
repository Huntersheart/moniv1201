import 'dart:async';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/routes/app_routes.dart';
import '../../data/models/session_model.dart';
import '../../data/remote/storage_service.dart';
import '../../data/repositories/dog_repository.dart';
import '../../data/repositories/session_repository.dart';
import 'auth_controller.dart';
import 'ble_controller.dart';
import 'vest_ble_controller.dart';
import 'dashboard_controller.dart';

class SessionLiveController extends GetxController {
  final SessionRepository _sessionRepo;
  final DogRepository _dogRepo;
  final StorageService _storage;

  SessionLiveController(this._sessionRepo, this._dogRepo, this._storage);

  final isLoading = false.obs;
  final Rxn<SessionModel> activeSession = Rxn<SessionModel>();

  final elapsedSeconds = 0.obs;
  Timer? _timer;
  Timer? _firestoreSyncTimer;
  StreamSubscription<SessionModel?>? _sessionSub;
  bool _bootstrapped = false;

  final hapticOn = true.obs;
  final hapticPresetIndex = 0.obs;
  final intensity = 3.0.obs;

  @override
  void onInit() {
    super.onInit();
    // Cuando cambia el preset Y haptic está ON → activar modo continuo (storm)
    ever(hapticPresetIndex, (int idx) {
      if (hapticOn.value) {
        _sendHapticContinuous(preset: idx);
      }
    });
    // Cuando se enciende el haptic → activar modo continuo con preset actual
    // Cuando se apaga → mandar OFF al collar
    ever(hapticOn, (bool on) {
      if (on) {
        _sendHapticContinuous(preset: hapticPresetIndex.value);
      } else {
        sendHapticOff();
      }
    });
  }

  /// Activa el modo haptic continuo en el collar (repite el preset cada ~8s).
  /// Usa CMD_STORM internamente — el collar vibra de forma autónoma hasta
  /// recibir CMD_OFF. Esto es el comportamiento esperado para sesiones
  /// de calma activa y tormenta.
  void _sendHapticContinuous({required int preset}) {
    final ble = _ble;
    if (ble == null || !ble.isConnected) return;
    unawaited(ble.sendStorm(preset: preset));
  }

  // ── Collar metrics ──────────────────────────────────────
  final movement = 5.0.obs;
  final comfort = 5.0.obs;
  final energy = 5.0.obs;

  // ── Vest metrics (1–5 buttons) ─────────────────────────
  // stability: 1–5  (1=very unstable, 5=very stable)
  final vestStability = 3.obs;
  // vestWeightBearing: 0=Normal, 1=Shifting, 2=Avoiding
  final vestWeightBearing = 0.obs;
  // vestPainSigns: 0=None, 1=Mild, 2=Moderate, 3=Severe
  final vestPainSigns = 0.obs;

  // ── Hip metrics ─────────────────────────────────────────
  // mobility: 1–5  (1=very limited, 5=full mobility)
  final hipMobility = 3.obs;
  // painSigns: 0=None, 1=Mild, 2=Moderate, 3=Severe
  final hipPainSigns = 0.obs;
  // satStoodAlone: 0=unknown, 1=yes, 2=no
  final hipSatStoodAlone = 0.obs;

  final limpLevel = 0.obs;
  final responseLevel = 0.obs;
  final calmingLevel = 3.obs;

  final noteController = TextEditingController();
  final photoUrl = ''.obs;
  final videoUrl = ''.obs;
  final isUploadingPhoto = false.obs;
  final isUploadingVideo = false.obs;
  final photoUploadProgress = 0.obs;
  final videoUploadProgress = 0.obs;

  /// Matches live session UI chips: Calm / Moderate / Strong.
  static const List<String> hapticPresets = ['Calm', 'Moderate', 'Strong'];

  static const Duration _firestoreSyncInterval = Duration(seconds: 12);
  static const int _maxVideoUploadBytes = 50 * 1024 * 1024;

  String get elapsedDisplay {
    final h = elapsedSeconds.value ~/ 3600;
    final m = (elapsedSeconds.value % 3600) ~/ 60;
    final s = elapsedSeconds.value % 60;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  /// Live Firestore stream for the active session document.
  /// Use with [StreamBuilder] to reflect any server-side changes instantly.
  Stream<SessionModel?> get sessionStream {
    final id = activeSession.value?.sessionId;
    if (id == null || id.isEmpty) return const Stream.empty();
    return _sessionRepo.watchSession(id);
  }

  @override
  void onClose() {
    _timer?.cancel();
    _firestoreSyncTimer?.cancel();
    _sessionSub?.cancel();
    noteController.dispose();
    _bootstrapped = false;
    super.onClose();
  }

  // ── BLE helper ──────────────────────────────────────────
  BleController? get _ble =>
      Get.isRegistered<BleController>() ? Get.find<BleController>() : null;

  VestBleController? get _vestBle =>
      Get.isRegistered<VestBleController>() ? Get.find<VestBleController>() : null;

  /// Envía comando haptico al collar si está conectado.
  /// preset: 0=Calm, 1=Moderate, 2=Strong
  void sendHapticCommand({required int preset, bool storm = false}) {
    final ble = _ble;
    if (ble == null || !ble.isConnected) return;
    if (storm) {
      unawaited(ble.sendStorm(preset: preset));
    } else {
      unawaited(ble.sendHaptic(preset: preset));
    }
  }

  void sendHapticOff() {
    final ble = _ble;
    if (ble == null || !ble.isConnected) return;
    unawaited(ble.sendOff());
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

  /// Subscribes to live Firestore updates for the active session document.
  /// This means if the session is updated from another device or by an admin,
  /// the changes reflect instantly in the UI without waiting for the sync timer.
  void _startSessionWatch(String sessionId) {
    _sessionSub?.cancel();
    _sessionSub = _sessionRepo.watchSession(sessionId).listen(
      (session) {
        if (session != null) activeSession.value = session;
      },
      onError: (Object e) =>
          debugPrint('[SessionLive] Firestore session watch: $e'),
    );
  }

  void _stopSessionWatch() {
    _sessionSub?.cancel();
    _sessionSub = null;
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
        vestStability: vestStability.value,
        vestWeightBearing: vestWeightBearing.value,
        vestPainSigns: vestPainSigns.value,
        hipMobility: hipMobility.value,
        hipPainSigns: hipPainSigns.value,
        hipSatStoodAlone: hipSatStoodAlone.value,
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
    _stopSessionWatch();
    _timer?.cancel();
    unawaited(_ble?.endSession());
    unawaited(_vestBle?.endSession());
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
      _startSessionWatch(activeSession.value!.sessionId);
      unawaited(_pushActiveProgressToFirestore());
      // BLE: conectar al collar automaticamente si es modulo collar
      if (moduleType == 'collar') {
        unawaited(_ble?.startSession());
      }
      // BLE: conectar al vest automaticamente si es modulo vest
      if (moduleType == 'vest') {
        unawaited(_vestBle?.startSession());
      }
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

  Future<void> pickAndUploadPhoto() async {
    final session = activeSession.value;
    final uid = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>().currentUser.value?.uid ?? ''
        : '';
    if (session == null || uid.isEmpty) {
      _snack('Error', 'No active session or not signed in.');
      return;
    }
    if (isUploadingPhoto.value) return;
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null) return;
    photoUploadProgress.value = 1;
    photoUrl.value = '';
    isUploadingPhoto.value = true;
    try {
      final imageBytes = await x.readAsBytes();
      final url = await _storage.uploadSessionPhotoBytes(
        userId: uid,
        sessionId: session.sessionId,
        imageBytes: imageBytes,
        filePath: x.path,
        onProgress: (progress) {
          photoUploadProgress.value = progress.clamp(1, 100);
        },
      );
      photoUrl.value = url;
      photoUploadProgress.value = 100;
      unawaited(_pushActiveProgressToFirestore());
    } on FirebaseException catch (e) {
      debugPrint('[SessionLive] photo upload: $e');
      if (e.code == 'unauthorized') {
        _snack(
          'Storage permission denied',
          'Deploy updated Firebase Storage rules, then retry image upload.',
        );
      } else {
        _snack('Upload failed', 'Could not upload photo. Check connection and try again.');
      }
    } catch (e) {
      debugPrint('[SessionLive] photo upload: $e');
      _snack('Upload failed', 'Could not upload photo. Check connection and try again.');
    } finally {
      isUploadingPhoto.value = false;
    }
  }

  Future<void> pickAndUploadVideo() async {
    final session = activeSession.value;
    final uid = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>().currentUser.value?.uid ?? ''
        : '';
    if (session == null || uid.isEmpty) {
      _snack('Error', 'No active session or not signed in.');
      return;
    }
    if (isUploadingVideo.value) return;
    _snack('Upload tip', 'Use Wi-Fi and keep video around 20-50MB for faster upload.');
    final picker = ImagePicker();
    final x = await picker.pickVideo(source: ImageSource.gallery);
    if (x == null) return;
    final pickedFile = File(x.path);
    final sizeBytes = await pickedFile.length();
    if (sizeBytes > _maxVideoUploadBytes) {
      final mb = (sizeBytes / (1024 * 1024)).toStringAsFixed(1);
      _snack(
        'Video too large',
        'Selected video is ${mb}MB. Please keep it under 50MB (720p/medium quality).',
      );
      return;
    }
    videoUploadProgress.value = 1;
    videoUrl.value = '';
    isUploadingVideo.value = true;
    try {
      final url = await _storage.uploadSessionVideo(
        userId: uid,
        sessionId: session.sessionId,
        filePath: x.path,
        onProgress: (progress) {
          videoUploadProgress.value = progress.clamp(1, 100);
        },
      );
      videoUrl.value = url;
      videoUploadProgress.value = 100;
      unawaited(_pushActiveProgressToFirestore());
    } on FirebaseException catch (e) {
      debugPrint('[SessionLive] video upload: $e');
      if (e.code == 'unauthorized') {
        _snack(
          'Storage permission denied',
          'Deploy updated Firebase Storage rules, then retry video upload.',
        );
      } else {
        _snack('Upload failed', 'Could not upload video. Check connection and try again.');
      }
    } catch (e) {
      debugPrint('[SessionLive] video upload: $e');
      _snack('Upload failed', 'Could not upload video. Check connection and try again.');
    } finally {
      isUploadingVideo.value = false;
    }
  }

  Future<void> endSession() async {
    _stopFirestoreSyncTimer();
    _stopSessionWatch();
    _timer?.cancel();
    unawaited(_ble?.endSession());
    unawaited(_vestBle?.endSession());
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
        vestStability: vestStability.value,
        vestWeightBearing: vestWeightBearing.value,
        vestPainSigns: vestPainSigns.value,
        hipMobility: hipMobility.value,
        hipPainSigns: hipPainSigns.value,
        hipSatStoodAlone: hipSatStoodAlone.value,
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
