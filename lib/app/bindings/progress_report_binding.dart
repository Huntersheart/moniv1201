import 'package:get/get.dart';
import '../../ui/controllers/progress_report_controller.dart';

class ProgressReportBinding extends Bindings {
  @override
  void dependencies() {
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    Get.lazyPut<ProgressReportController>(
      () => ProgressReportController(
        dogId:   args['dogId']   as String? ?? '',
        dogName: args['dogName'] as String? ?? 'Dog',
      ),
    );
  }
}
