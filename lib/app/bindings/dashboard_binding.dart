import 'package:get/get.dart';

import '../../data/repositories/dog_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../ui/controllers/dashboard_controller.dart';

class DashboardBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DogRepository>(() => DogRepository());
    Get.lazyPut<SessionRepository>(() => SessionRepository());
    Get.lazyPut<DashboardController>(
      () => DashboardController(
        Get.find<DogRepository>(),
        Get.find<SessionRepository>(),
      ),
    );
  }
}
