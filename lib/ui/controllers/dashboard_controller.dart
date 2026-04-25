import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/dog_model.dart';
import '../../data/models/session_model.dart';
import '../../data/repositories/dog_repository.dart';
import '../../data/repositories/session_repository.dart';
import 'auth_controller.dart';

class DashboardController extends GetxController {
  final DogRepository _dogRepo;
  final SessionRepository _sessionRepo;
  final AuthController _auth;

  DashboardController(this._dogRepo, this._sessionRepo, this._auth);

  final dogs = <DogModel>[].obs;
  /// Completed sessions from Firestore (newest first, capped in [SessionRepository]).
  final completedSessions = <SessionModel>[].obs;
  final selectedDogIndex = 0.obs;

  StreamSubscription<List<DogModel>>? _dogSub;
  StreamSubscription<List<SessionModel>>? _sessionSub;
  Timer? _sessionRetryTimer;
  int _sessionRetryAttempt = 0;
  bool _sessionIndexSnackShown = false;
  String? _sessionsListenUid;
  bool _isRecoveringPermission = false;

  static const int _maxSessionRetries = 40;
  static const Duration _sessionRetryDelay = Duration(seconds: 10);

  /// Must come from FirebaseAuth only; this is what Firestore rules evaluate
  /// as request.auth.uid.
  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void onInit() {
    super.onInit();
    ever(_auth.currentUser, (_) => _startListening());
    _startListening();
  }

  void _startListening() {
    final uid = _userId;
    if (uid.isEmpty) {
      _dogSub?.cancel();
      _dogSub = null;
      _sessionSub?.cancel();
      _sessionSub = null;
      _sessionRetryTimer?.cancel();
      _sessionRetryTimer = null;
      _sessionsListenUid = null;
      dogs.clear();
      completedSessions.clear();
      selectedDogIndex.value = 0;
      return;
    }

    if (_sessionsListenUid != uid) {
      _sessionsListenUid = uid;
      _sessionRetryAttempt = 0;
      _sessionIndexSnackShown = false;
    }

    _dogSub?.cancel();
    _sessionSub?.cancel();
    _sessionRetryTimer?.cancel();

    _dogSub = _dogRepo.watchDogs(uid).listen(
          (list) {
            dogs.value = list;
            if (list.isEmpty) {
              selectedDogIndex.value = 0;
            } else if (selectedDogIndex.value >= list.length) {
              selectedDogIndex.value = list.length - 1;
            }
          },
          onError: (Object e) {
            debugPrint('[Dashboard] dog error: $e');
            if (_isPermissionDenied(e)) {
              dogs.clear();
              _dogSub?.cancel();
              _dogSub = null;
              _recoverAfterPermissionDenied(uid);
            }
          },
        );

    _listenUserSessions(uid);
  }

  /// Retries while Firestore composite indexes are still building (FAILED_PRECONDITION).
  void _listenUserSessions(String uid) {
    _sessionSub?.cancel();
    _sessionSub = _sessionRepo.watchUserSessions(uid).listen(
      (list) {
        _sessionRetryAttempt = 0;
        completedSessions.value = list;
      },
      onError: (Object e) {
        debugPrint('[Dashboard] session error: $e');
        if (_isPermissionDenied(e)) {
          completedSessions.clear();
          _sessionSub?.cancel();
          _sessionSub = null;
          _recoverAfterPermissionDenied(uid);
          return;
        }
        if (!_isFirestoreSessionsIndexBlocked(e)) return;
        if (!_sessionIndexSnackShown) {
          _sessionIndexSnackShown = true;
          Get.snackbar(
            'Session history',
            'Your session list is connecting. If you just deployed database indexes, '
            'wait 1–2 minutes and it will load automatically.',
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 6),
            backgroundColor: const Color(0xFF2A2A2A),
            colorText: Colors.white,
          );
        }
        if (_sessionRetryAttempt >= _maxSessionRetries) return;
        _sessionRetryAttempt++;
        _sessionRetryTimer?.cancel();
        _sessionRetryTimer = Timer(_sessionRetryDelay, () {
          if (_userId != uid || uid.isEmpty) return;
          _listenUserSessions(uid);
        });
      },
    );
  }

  static bool _isFirestoreSessionsIndexBlocked(Object e) {
    final s = e.toString().toLowerCase();
    if (!s.contains('failed-precondition')) return false;
    return s.contains('index') ||
        s.contains('building') ||
        s.contains('composite');
  }

  static bool _isPermissionDenied(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('permission-denied');
  }

  void _recoverAfterPermissionDenied(String uid) {
    if (_isRecoveringPermission) return;
    _isRecoveringPermission = true;
    Future<void>(() async {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null || user.uid != uid) return;
        await user.getIdToken(true);
        await Future<void>.delayed(const Duration(milliseconds: 500));
      } catch (_) {
        return;
      } finally {
        _isRecoveringPermission = false;
      }
      if (_userId != uid || uid.isEmpty) return;
      _startListening();
    });
  }

  /// Raw Firestore stream for dogs — use with [StreamBuilder] for live UI.
  Stream<List<DogModel>> get dogsStream {
    final uid = _userId;
    if (uid.isEmpty) return const Stream.empty();
    return _dogRepo.watchDogs(uid);
  }

  /// Raw Firestore stream for completed sessions — use with [StreamBuilder].
  Stream<List<SessionModel>> get sessionsStream {
    final uid = _userId;
    if (uid.isEmpty) return const Stream.empty();
    return _sessionRepo.watchUserSessions(uid);
  }

  void selectDog(int index) => selectedDogIndex.value = index;

  DogModel? get selectedDog =>
      dogs.isNotEmpty && selectedDogIndex.value < dogs.length
          ? dogs[selectedDogIndex.value]
          : null;

  Future<void> deleteDog(DogModel dog) async {
    final uid = _userId;
    if (uid.isEmpty) return;
    try {
      await _dogRepo.deleteDog(userId: uid, dogId: dog.dogId);
      // Stream listener updates [dogs] and clamps [selectedDogIndex] after delete.
    } catch (e) {
      Get.snackbar(
        'Error',
        'Could not delete dog. Try again.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        backgroundColor: const Color(0xFF2A2A2A),
        colorText: Colors.white,
      );
    }
  }

  @override
  void onClose() {
    _sessionRetryTimer?.cancel();
    _dogSub?.cancel();
    _sessionSub?.cancel();
    super.onClose();
  }
}
