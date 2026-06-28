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

  final nameController   = TextEditingController();
  final weightController = TextEditingController(text: '0');
  final notesController  = TextEditingController();
  final microchipController = TextEditingController();

  // ── Edad ────────────────────────────────────────────────────
  // El usuario ingresa un numero + selecciona Years o Months
  // Internamente siempre guardamos ageMonths en Firestore
  final ageNumberController = TextEditingController(text: '0');
  // Note: accepts decimals (e.g. 8.5 years = 102 months)
  final ageUnit = 'Years'.obs; // 'Years' | 'Months'
  static const List<String> ageUnits = ['Years', 'Months'];

  int get _ageInMonths {
    final n = double.tryParse(ageNumberController.text) ?? 0;
    return ageUnit.value == 'Years' ? (n * 12).round() : n.round();
  }

  // ── Raza ─────────────────────────────────────────────────────
  // Dropdown con lista de razas populares + "Other" para texto libre
  final breed     = ''.obs;         // valor seleccionado en dropdown ('' = no seleccionado)
  final breedOther = TextEditingController(); // visible solo cuando breed == 'Other'

  static const List<String> breedOptions = [
    'Mixed / Unknown',
    // Populares en USA (ordenadas por popularidad AKC)
    'French Bulldog',
    'Labrador Retriever',
    'Golden Retriever',
    'German Shepherd',
    'Bulldog',
    'Poodle',
    'Beagle',
    'Rottweiler',
    'German Shorthaired Pointer',
    'Dachshund',
    'Pembroke Welsh Corgi',
    'Australian Shepherd',
    'Yorkshire Terrier',
    'Cavalier King Charles Spaniel',
    'Doberman Pinscher',
    'Boxer',
    'Miniature Schnauzer',
    'Cane Corso',
    'Great Dane',
    'Shih Tzu',
    'Siberian Husky',
    'Bernese Mountain Dog',
    'Border Collie',
    'Shetland Sheepdog',
    'Boston Terrier',
    'Havanese',
    'Cocker Spaniel',
    'Maltese',
    'Pomeranian',
    'Chihuahua',
    'Weimaraner',
    'Vizsla',
    'Basset Hound',
    'Collie',
    'Brittany',
    'Mastiff',
    'Bichon Frise',
    'English Springer Spaniel',
    'Pug',
    'West Highland White Terrier',
    'Bloodhound',
    'Newfoundland',
    'Saint Bernard',
    'Rhodesian Ridgeback',
    'Soft Coated Wheaten Terrier',
    'Portuguese Water Dog',
    'Chow Chow',
    'Akita',
    'Chinese Shar-Pei',
    'Bull Terrier',
    'Other',
  ];

  String get breedValue {
    if (breed.value == 'Other') return breedOther.text.trim();
    return breed.value;
  }

  // ── Genero ───────────────────────────────────────────────────
  final gender = 'Male'.obs;
  static const List<String> genders = ['Male', 'Female', 'Other'];

  // ── Historial ────────────────────────────────────────────────
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

  final selectedAnxiety  = <String>[].obs;
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
    weightController.text = dog.weightLbs.toStringAsFixed(1);
    notesController.text = dog.healthNotes;
    microchipController.text = dog.microchipId;
    gender.value = dog.gender;
    selectedAnxiety.value  = List<String>.from(dog.anxietyHistory);
    selectedMobility.value = List<String>.from(dog.mobilityHistory);

    // Edad — mostrar en la unidad mas legible
    if (dog.ageMonths % 12 == 0 && dog.ageMonths > 0) {
      ageUnit.value = 'Years';
      ageNumberController.text = (dog.ageMonths ~/ 12).toString();
    } else {
      ageUnit.value = 'Months';
      ageNumberController.text = dog.ageMonths.toString();
    }

    // Breed — si esta en la lista usa dropdown, si no va a Other
    if (breedOptions.contains(dog.breed)) {
      breed.value = dog.breed;
    } else if (dog.breed.isNotEmpty) {
      breed.value = 'Other';
      breedOther.text = dog.breed;
    }
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
          final bytes = await profileImage.value!.readAsBytes();
          photoUrl = await _storageService.uploadDogPhoto(
            userId: uid,
            dogId: existing.dogId,
            imageBytes: bytes,
          );
        }
        final dog = DogModel(
          dogId: existing.dogId,
          ownerId: uid,
          name: name,
          breed: breedValue,
          ageMonths: _ageInMonths,
          weightLbs: double.tryParse(weightController.text) ?? 0.0,
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
          breed: breedValue,
          ageMonths: _ageInMonths,
          weightLbs: double.tryParse(weightController.text) ?? 0.0,
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
          final bytes = await profileImage.value!.readAsBytes();
          final photoUrl = await _storageService.uploadDogPhoto(
            userId: uid,
            dogId: created.dogId,
            imageBytes: bytes,
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
    } on FirebaseException catch (e) {
      debugPrint('$e');
      final code = e.code.toLowerCase();
      final message = e.message?.toLowerCase() ?? '';
      String uiMessage = 'Could not save profile. Check your connection.';
      if (code == 'unauthorized') {
        uiMessage =
            'Storage permission denied. Check Firebase Storage rules and sign-in.';
      } else if (code == 'unknown' && message.contains('cannot parse response')) {
        uiMessage =
            'iOS upload response error. Please try again or use a smaller image.';
      }
      Get.snackbar(
        'Error',
        uiMessage,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        backgroundColor: const Color(0xFF2A2A2A),
        colorText: Colors.white,
      );
    } catch (e) {
      debugPrint('$e');
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
    ageNumberController.dispose();
    weightController.dispose();
    notesController.dispose();
    microchipController.dispose();
    breedOther.dispose();
    super.onClose();
  }
}
