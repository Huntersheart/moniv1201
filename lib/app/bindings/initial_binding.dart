import 'package:get/get.dart';

import '../../data/remote/auth_service.dart';
import '../../data/remote/storage_service.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/dog_repository.dart';
import '../../data/repositories/device_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../ui/controllers/auth_controller.dart';
import '../../ui/controllers/ble_controller.dart';
import '../../ui/controllers/vest_ble_controller.dart';
import '../../ui/controllers/storm_controller.dart';

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

    // Global controllers
    if (!Get.isRegistered<AuthController>()) {
      Get.put<AuthController>(
        AuthController(Get.find<AuthRepository>()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<BleController>()) {
      Get.put<BleController>(BleController(), permanent: true);
    }
    if (!Get.isRegistered<VestBleController>()) {
      Get.put<VestBleController>(VestBleController(), permanent: true);
    }
    if (!Get.isRegistered<StormController>()) {
      Get.put<StormController>(StormController(), permanent: true);
    }
  }
}
