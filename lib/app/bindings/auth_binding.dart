import 'package:get/get.dart';

import '../../data/remote/auth_service.dart';
import '../../data/remote/password_reset_cloud_service.dart';
import '../../data/repositories/auth_repository.dart';
import '../../ui/controllers/auth_controller.dart';
import '../../ui/controllers/password_reset_otp_controller.dart';

class AuthBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AuthService>(() => AuthService());
    Get.lazyPut<PasswordResetCloudService>(
      () => PasswordResetCloudService(),
      fenix: true,
    );
    Get.lazyPut<AuthRepository>(
      () => AuthRepository(Get.find<AuthService>()),
    );
    Get.lazyPut<AuthController>(
      () => AuthController(Get.find<AuthRepository>()),
    );
    Get.lazyPut<PasswordResetOtpController>(
      () => PasswordResetOtpController(),
      fenix: true,
    );
  }
}
