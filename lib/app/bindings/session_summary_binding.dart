import 'package:get/get.dart';

import '../../data/repositories/session_repository.dart';
import '../../ui/controllers/session_summary_controller.dart';

class SessionSummaryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SessionRepository>(() => SessionRepository());
    Get.lazyPut<SessionSummaryController>(
      () => SessionSummaryController(Get.find<SessionRepository>()),
    );
  }
}
