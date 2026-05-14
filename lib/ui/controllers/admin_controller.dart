import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/session_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/admin_repository.dart';

class AdminController extends GetxController {
  final AdminRepository _repo;

  AdminController(this._repo);

  // ── State ──────────────────────────────────────────────────────────────────

  final RxList<UserModel> users = <UserModel>[].obs;
  final RxList<SessionModel> sessions = <SessionModel>[].obs;
  final isLoadingUsers = false.obs;
  final isLoadingSessions = false.obs;
  final RxString roleUpdateUid = ''.obs; // uid currently being updated

  StreamSubscription<List<UserModel>>? _usersSub;
  StreamSubscription<List<SessionModel>>? _sessionsSub;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    _subscribeUsers();
    _subscribeSessions();
  }

  @override
  void onClose() {
    _usersSub?.cancel();
    _sessionsSub?.cancel();
    super.onClose();
  }

  // ── Streams ────────────────────────────────────────────────────────────────

  void _subscribeUsers() {
    isLoadingUsers.value = true;
    _usersSub = _repo.watchAllUsers().listen(
      (list) {
        users.assignAll(list);
        isLoadingUsers.value = false;
      },
      onError: (Object e) {
        isLoadingUsers.value = false;
        debugPrint('[Admin] users stream error: $e');
        _snack('Error', 'Could not load users. Check your connection.');
      },
    );
  }

  void _subscribeSessions() {
    isLoadingSessions.value = true;
    _sessionsSub = _repo.watchAllSessions(limit: 200).listen(
      (list) {
        sessions.assignAll(list);
        isLoadingSessions.value = false;
      },
      onError: (Object e) {
        isLoadingSessions.value = false;
        debugPrint('[Admin] sessions stream error: $e');
      },
    );
  }

  // ── Role management ────────────────────────────────────────────────────────

  Future<void> promoteToAdmin(UserModel user) async {
    if (user.isAdmin) return;
    final confirmed = await _confirm(
      title: 'Promote to Admin?',
      message:
          '${user.displayName.isNotEmpty ? user.displayName : user.email} will have full admin access to all data and modules.',
    );
    if (!confirmed) return;
    await _setRole(user, 'admin');
  }

  Future<void> demoteToPioneer(UserModel user) async {
    if (user.isPioneer) return;
    final confirmed = await _confirm(
      title: 'Demote to Pioneer?',
      message:
          '${user.displayName.isNotEmpty ? user.displayName : user.email} will lose admin access and see only the Collar module.',
    );
    if (!confirmed) return;
    await _setRole(user, 'pioneer');
  }

  Future<void> _setRole(UserModel user, String role) async {
    roleUpdateUid.value = user.uid;
    try {
      await _repo.setUserRole(user.uid, role);
      _snack(
        'Role updated',
        '${user.displayName.isNotEmpty ? user.displayName : user.email} is now ${role == 'admin' ? 'Admin' : 'Pioneer'}.',
      );
    } catch (e) {
      debugPrint('[Admin] setUserRole error: $e');
      _snack('Error', 'Could not update role. Please try again.');
    } finally {
      roleUpdateUid.value = '';
    }
  }

  // ── Computed helpers ───────────────────────────────────────────────────────

  int get adminCount => users.where((u) => u.isAdmin).length;
  int get pioneerCount => users.where((u) => u.isPioneer).length;
  int get totalSessions => sessions.length;

  List<SessionModel> sessionsForUser(String userId) =>
      sessions.where((s) => s.userId == userId).toList();

  // ── UI helpers ─────────────────────────────────────────────────────────────

  Future<bool> _confirm({
    required String title,
    required String message,
  }) async {
    final result = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
        ),
        content: Text(
          message,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 15,
              height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<bool>(result: false),
            child: Text('Cancel',
                style:
                    TextStyle(color: Colors.white.withValues(alpha: 0.75))),
          ),
          TextButton(
            onPressed: () => Get.back<bool>(result: true),
            child: const Text('Confirm',
                style: TextStyle(
                    color: Color(0xFFD4A847),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _snack(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      backgroundColor: const Color(0xFF2A2A2A),
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }
}
