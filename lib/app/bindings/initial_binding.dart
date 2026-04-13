import 'package:get/get.dart';

import '../../data/remote/auth_service.dart';
import '../../data/remote/storage_service.dart';
import '../../data/remote/fcm_service.dart';
import '../../data/remote/firebase_service.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/dog_repository.dart';
import '../../data/repositories/device_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../ui/controllers/auth_controller.dart';
import '../../ui/controllers/notification_controller.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // Services
    Get.lazyPut<AuthService>(() => AuthService(), fenix: true);
    Get.lazyPut<StorageService>(() => StorageService(), fenix: true);
    Get.lazyPut<FcmService>(() => FcmService(), fenix: true);

    // Repositories
    Get.lazyPut<AuthRepository>(
      () => AuthRepository(Get.find<AuthService>()),
      fenix: true,
    );
    Get.lazyPut<DogRepository>(() => DogRepository(), fenix: true);
    Get.lazyPut<DeviceRepository>(() => DeviceRepository(), fenix: true);
    Get.lazyPut<SessionRepository>(() => SessionRepository(), fenix: true);
    Get.lazyPut<NotificationRepository>(
      () => NotificationRepository(),
      fenix: true,
    );

    // Global controllers (always registered; safe to call even without Firebase)
    Get.lazyPut<AuthController>(
      () => AuthController(Get.find<AuthRepository>()),
      fenix: true,
    );

    // Notification controller only when Firebase is live
    if (FirebaseService.isInitialized) {
      Get.lazyPut<NotificationController>(
        () => NotificationController(Get.find<NotificationRepository>()),
        fenix: true,
      );
    }
  }
}
