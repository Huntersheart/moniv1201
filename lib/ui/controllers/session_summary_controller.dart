import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/session_model.dart';
import '../../data/repositories/session_repository.dart';

class SessionSummaryController extends GetxController {
  final SessionRepository _sessionRepo;

  SessionSummaryController(this._sessionRepo);

  final Rxn<SessionModel> session = Rxn<SessionModel>();
  final isLoading = false.obs;

  StreamSubscription<SessionModel?>? _sessionSub;
  bool _missingSessionNotified = false;

  @override
  void onInit() {
    super.onInit();
    final raw = Get.arguments;
    if (raw is! Map) return;
    final args = Map<String, dynamic>.from(raw);
    final s = args['session'];
    if (s is SessionModel) {
      session.value = s;
    } else if (args['sessionId'] is String) {
      _subscribeSession(args['sessionId'] as String);
    }
  }

  void _subscribeSession(String sessionId) {
    isLoading.value = true;
    _missingSessionNotified = false;
    _sessionSub?.cancel();
    _sessionSub = _sessionRepo.watchSession(sessionId).listen(
      (doc) {
        session.value = doc;
        isLoading.value = false;
        if (doc == null && !_missingSessionNotified) {
          _missingSessionNotified = true;
          Get.snackbar(
            'Session',
            'Could not load this session from the cloud.',
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(16),
            backgroundColor: const Color(0xFF2A2A2A),
            colorText: Colors.white,
          );
        }
      },
      onError: (_) {
        session.value = null;
        isLoading.value = false;
        if (!_missingSessionNotified) {
          _missingSessionNotified = true;
          Get.snackbar(
            'Session',
            'Could not load this session. Check your connection.',
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(16),
            backgroundColor: const Color(0xFF2A2A2A),
            colorText: Colors.white,
          );
        }
      },
    );
  }

  @override
  void onClose() {
    _sessionSub?.cancel();
    super.onClose();
  }
}
