import 'dart:async';

import 'package:get/get.dart';

import '../../data/models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';
import 'auth_controller.dart';

class NotificationController extends GetxController {
  final NotificationRepository _repo;

  NotificationController(this._repo);

  final notifications = <NotificationModel>[].obs;
  final unreadCount = 0.obs;
  StreamSubscription<List<NotificationModel>>? _sub;

  String get _userId =>
      Get.find<AuthController>().currentUser.value?.uid ?? '';

  @override
  void onInit() {
    super.onInit();
    ever(Get.find<AuthController>().currentUser, (_) => _startListening());
    _startListening();
  }

  void _startListening() {
    final uid = _userId;
    if (uid.isEmpty) return;
    _sub?.cancel();
    _sub = _repo.watchUserNotifications(uid).listen((list) {
      notifications.value = list;
      unreadCount.value = list.where((n) => !n.isRead).length;
    });
  }

  Future<void> markAsRead(String notificationId) async {
    await _repo.markAsRead(notificationId);
  }

  Future<void> markAllAsRead() async {
    final uid = _userId;
    if (uid.isEmpty) return;
    await _repo.markAllAsRead(uid);
  }

  Future<void> deleteNotification(String notificationId) async {
    await _repo.deleteNotification(notificationId);
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
