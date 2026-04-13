import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models/dog_model.dart';
import '../../data/repositories/dog_repository.dart';
import '../../data/remote/storage_service.dart';
import 'auth_controller.dart';

class AddDogController extends GetxController {
  final DogRepository _dogRepo;
  final StorageService _storageService;

  AddDogController(this._dogRepo, this._storageService);

  final ImagePicker _picker = ImagePicker();

  final Rxn<XFile> profileImage = Rxn<XFile>();
  final isLoading = false.obs;

  final nameController = TextEditingController();
  final breedController = TextEditingController();
  final ageController = TextEditingController(text: '0');
  final weightController = TextEditingController(text: '0');
  final notesController = TextEditingController();
  final microchipController = TextEditingController();

  final gender = 'Male'.obs;
  static const List<String> genders = ['Male', 'Female', 'Other'];

  static const List<String> anxietyOptions = [
    'Noise Phobia (Thunder/Fireworks)',
    'Separation Anxiety',
    'Social/Fear Anxiety',
    'Travel/Crate Anxiety',
    'Generalized Anxiety',
  ];

  static const List<String> mobilityOptions = [
    'Hip Dysplasia',
    'Arthritis',
    'CCL/Ligament Injury',
    'Neurological Weakness (Scuffing)',
    'Post-Surgical Recovery',
  ];

  final selectedAnxiety = <String>[].obs;
  final selectedMobility = <String>[].obs;

  // If editing an existing dog
  Rxn<DogModel> editingDog = Rxn<DogModel>();

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null && args['dog'] is DogModel) {
      _populateFromDog(args['dog'] as DogModel);
    }
  }

  void _populateFromDog(DogModel dog) {
    editingDog.value = dog;
    nameController.text = dog.name;
    breedController.text = dog.breed;
    ageController.text = dog.ageMonths.toString();
    weightController.text = dog.weightKg.toString();
    notesController.text = dog.healthNotes;
    microchipController.text = dog.microchipId;
    gender.value = dog.gender;
    selectedAnxiety.value = List<String>.from(dog.anxietyHistory);
    selectedMobility.value = List<String>.from(dog.mobilityHistory);
  }

  void toggleAnxiety(String key) {
    if (selectedAnxiety.contains(key)) {
      selectedAnxiety.remove(key);
    } else {
      selectedAnxiety.add(key);
    }
  }

  void toggleMobility(String key) {
    if (selectedMobility.contains(key)) {
      selectedMobility.remove(key);
    } else {
      selectedMobility.add(key);
    }
  }

  Future<void> pickProfileImage(ImageSource source) async {
    try {
      final x = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (x != null) profileImage.value = x;
    } catch (_) {
      Get.snackbar(
        'Image',
        'Could not open gallery or camera. Check permissions in Settings.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        backgroundColor: const Color(0xFF2A2A2A),
        colorText: Colors.white,
      );
    }
  }

  Future<void> saveProfile() async {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      Get.snackbar(
        'Validation',
        'Dog name is required.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        backgroundColor: const Color(0xFF2A2A2A),
        colorText: Colors.white,
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid ??
        Get.find<AuthController>().currentUser.value?.uid ??
        '';
    if (uid.isEmpty) return;

    isLoading.value = true;
    try {
      final existing = editingDog.value;
      final isEditing = existing != null;
      final now = DateTime.now();

      late final String savedDogId;
      if (isEditing) {
        var photoUrl = existing.photoUrl;
        if (profileImage.value != null) {
          photoUrl = await _storageService.uploadDogPhoto(
            userId: uid,
            dogId: existing.dogId,
            filePath: profileImage.value!.path,
          );
        }
        final dog = DogModel(
          dogId: existing.dogId,
          ownerId: uid,
          name: name,
          breed: breedController.text.trim(),
          ageMonths: int.tryParse(ageController.text) ?? 0,
          weightKg: double.tryParse(weightController.text) ?? 0.0,
          gender: gender.value,
          photoUrl: photoUrl,
          microchipId: microchipController.text.trim(),
          anxietyHistory: selectedAnxiety.toList(),
          mobilityHistory: selectedMobility.toList(),
          healthNotes: notesController.text.trim(),
          createdAt: existing.createdAt,
          updatedAt: now,
        );
        await _dogRepo.updateDog(dog);
        savedDogId = dog.dogId;
      } else {
        final dog = DogModel(
          dogId: '',
          ownerId: uid,
          name: name,
          breed: breedController.text.trim(),
          ageMonths: int.tryParse(ageController.text) ?? 0,
          weightKg: double.tryParse(weightController.text) ?? 0.0,
          gender: gender.value,
          photoUrl: '',
          microchipId: microchipController.text.trim(),
          anxietyHistory: selectedAnxiety.toList(),
          mobilityHistory: selectedMobility.toList(),
          healthNotes: notesController.text.trim(),
          createdAt: now,
          updatedAt: now,
        );
        var created = await _dogRepo.addDog(dog);
        if (profileImage.value != null) {
          final photoUrl = await _storageService.uploadDogPhoto(
            userId: uid,
            dogId: created.dogId,
            filePath: profileImage.value!.path,
          );
          await _dogRepo.updateDog(created.copyWith(photoUrl: photoUrl));
        }
        savedDogId = created.dogId;
      }

      Get.back(result: savedDogId);
      Get.snackbar(
        'Saved',
        isEditing ? 'Dog profile updated.' : 'Dog profile added.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        backgroundColor: const Color(0xFF2A2A2A),
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Could not save profile. Check your connection.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        backgroundColor: const Color(0xFF2A2A2A),
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    nameController.dispose();
    breedController.dispose();
    ageController.dispose();
    weightController.dispose();
    notesController.dispose();
    microchipController.dispose();
    super.onClose();
  }
}
