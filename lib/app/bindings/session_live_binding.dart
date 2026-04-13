import 'package:get/get.dart';

import '../../data/repositories/dog_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../ui/controllers/session_live_controller.dart';

class SessionLiveBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SessionRepository>(() => SessionRepository());
    Get.lazyPut<DogRepository>(() => DogRepository());
    Get.lazyPut<SessionLiveController>(
      () => SessionLiveController(
        Get.find<SessionRepository>(),
        Get.find<DogRepository>(),
      ),
    );
  }
}
