import 'package:get/get.dart';

import '../../data/remote/auth_service.dart';
import '../../data/repositories/auth_repository.dart';
import '../../ui/controllers/auth_controller.dart';

class AuthBinding extends Bindings {
  @override
  void dependencies() {
    // [InitialBinding] may already have registered these globally — never duplicate.
    if (!Get.isRegistered<AuthService>()) {
      Get.lazyPut<AuthService>(() => AuthService());
    }
    if (!Get.isRegistered<AuthRepository>()) {
      Get.lazyPut<AuthRepository>(
        () => AuthRepository(Get.find<AuthService>()),
      );
    }
    if (!Get.isRegistered<AuthController>()) {
      Get.lazyPut<AuthController>(
        () => AuthController(Get.find<AuthRepository>()),
      );
    }
  }
}
