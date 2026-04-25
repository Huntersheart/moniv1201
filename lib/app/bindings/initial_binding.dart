import 'package:get/get.dart';

import '../../data/remote/auth_service.dart';
import '../../data/remote/storage_service.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/dog_repository.dart';
import '../../data/repositories/device_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../ui/controllers/auth_controller.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // Services
    Get.lazyPut<AuthService>(() => AuthService(), fenix: true);
    Get.lazyPut<StorageService>(() => StorageService(), fenix: true);

    // Repositories
    Get.lazyPut<AuthRepository>(
      () => AuthRepository(Get.find<AuthService>()),
      fenix: true,
    );
    Get.lazyPut<DogRepository>(() => DogRepository(), fenix: true);
    Get.lazyPut<DeviceRepository>(() => DeviceRepository(), fenix: true);
    Get.lazyPut<SessionRepository>(() => SessionRepository(), fenix: true);

    // Global controller
    if (!Get.isRegistered<AuthController>()) {
      Get.put<AuthController>(
        AuthController(Get.find<AuthRepository>()),
        permanent: true,
      );
    }
  }
}
