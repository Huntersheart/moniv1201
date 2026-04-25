import 'package:get/get.dart';

import '../../data/remote/auth_service.dart';
import '../../data/remote/storage_service.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/dog_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../ui/controllers/auth_controller.dart';
import '../../ui/controllers/session_live_controller.dart';

class SessionLiveBinding extends Bindings {
  @override
  void dependencies() {
    // Ensure global singletons are alive (fenix re-creates them if disposed).
    if (!Get.isRegistered<AuthController>()) {
      Get.lazyPut<AuthService>(() => AuthService(), fenix: true);
      Get.lazyPut<AuthRepository>(
        () => AuthRepository(Get.find<AuthService>()),
        fenix: true,
      );
      Get.lazyPut<AuthController>(
        () => AuthController(Get.find<AuthRepository>()),
        fenix: true,
      );
    }

    Get.lazyPut<SessionRepository>(() => SessionRepository(), fenix: true);
    Get.lazyPut<DogRepository>(() => DogRepository(), fenix: true);
    if (!Get.isRegistered<StorageService>()) {
      Get.lazyPut<StorageService>(() => StorageService(), fenix: true);
    }
    Get.lazyPut<SessionLiveController>(
      () => SessionLiveController(
        Get.find<SessionRepository>(),
        Get.find<DogRepository>(),
        Get.find<StorageService>(),
      ),
    );
  }
}
