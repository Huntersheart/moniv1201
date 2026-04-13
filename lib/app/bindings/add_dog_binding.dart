import 'package:get/get.dart';

import '../../data/repositories/dog_repository.dart';
import '../../data/remote/storage_service.dart';
import '../../ui/controllers/add_dog_controller.dart';

class AddDogBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DogRepository>(() => DogRepository());
    Get.lazyPut<StorageService>(() => StorageService());
    Get.lazyPut<AddDogController>(
      () => AddDogController(
        Get.find<DogRepository>(),
        Get.find<StorageService>(),
      ),
    );
  }
}
