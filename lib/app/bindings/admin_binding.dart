import 'package:get/get.dart';

import '../../data/repositories/admin_repository.dart';
import '../../ui/controllers/admin_controller.dart';

class AdminBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AdminRepository>(() => AdminRepository());
    Get.lazyPut<AdminController>(
      () => AdminController(Get.find<AdminRepository>()),
    );
  }
}
