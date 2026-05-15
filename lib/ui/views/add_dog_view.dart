import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../controllers/add_dog_controller.dart';
import '../widgets/signara_dashboard_background.dart';
import '../widgets/signara_dropdown_field.dart';
import '../widgets/signara_primary_button.dart';
import '../widgets/signara_text_field.dart';

const String _kDogPlaceholderAsset = 'assets/icons/dog_icon.png';
const String _kCameraAsset = 'assets/icons/camara_icon.png';

/// Circular profile (green border + glow), camera control, full form — matches Add Dog design.
class AddDogView extends GetView<AddDogController> {
  const AddDogView({super.key});

  void _openImageSourceSheet(BuildContext context) {
    FocusManager.instance.primaryFocus?.unfocus();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1F1C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_library_outlined, color: Colors.white.withValues(alpha: 0.85)),
                title: const Text('Gallery', style: TextStyle(color: Colors.white, fontSize: 16)),
                onTap: () {
                  Navigator.pop(ctx);
                  controller.pickProfileImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt_outlined, color: Colors.white.withValues(alpha: 0.85)),
                title: const Text('Camera', style: TextStyle(color: Colors.white, fontSize: 16)),
                onTap: () {
                  Navigator.pop(ctx);
                  controller.pickProfileImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            onPressed: () => Get.back<void>(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          ),
          title: const Text(
            'Add Dog',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const SignaraDashboardBackground(),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: _ProfileAvatarBlock(onCameraTap: () => _openImageSourceSheet(context))),
                    
                    const SizedBox(height: 8.0),
                    _FormSectionCard(
                      title: 'Basic Information',
                      subtitle: 'Required details about your dog',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SignaraTextField(
                            label: 'Name*',
                            labelTextAlign: TextAlign.start,
                            controller: controller.nameController,
                            hintText: 'Enter dog name',
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 16),
                          // ── Breed dropdown ───────────────────────────────
                          Obx(() => SignaraDropdownField(
                            label: 'Breed',
                            value: controller.breed.value.isEmpty
                                ? null
                                : controller.breed.value,
                            items: AddDogController.breedOptions,
                            hintText: 'Select breed (optional)',
                            onChanged: (v) {
                              if (v != null) controller.breed.value = v;
                            },
                          )),
                          // Campo libre si eligio "Other"
                          Obx(() => controller.breed.value == 'Other'
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: SignaraTextField(
                                    label: 'Breed name',
                                    labelTextAlign: TextAlign.start,
                                    controller: controller.breedOther,
                                    hintText: 'Enter breed name',
                                    textInputAction: TextInputAction.next,
                                  ),
                                )
                              : const SizedBox.shrink()),
                          const SizedBox(height: 16),
                          // ── Edad: numero + Years/Months ──────────────────
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: SignaraTextField(
                                  label: 'Age*',
                                  labelTextAlign: TextAlign.start,
                                  controller: controller.ageNumberController,
                                  hintText: '0',
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.next,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 3,
                                child: Obx(() => SignaraDropdownField(
                                  label: 'Unit',
                                  value: controller.ageUnit.value,
                                  items: AddDogController.ageUnits,
                                  onChanged: (v) {
                                    if (v != null) controller.ageUnit.value = v;
                                  },
                                )),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 3,
                                child: SignaraTextField(
                                  label: 'Weight (lbs)*',
                                  labelTextAlign: TextAlign.start,
                                  controller: controller.weightController,
                                  hintText: '0',
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.next,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Obx(
                            () => SignaraDropdownField(
                              label: 'Gender*',
                              value: controller.gender.value,
                              items: AddDogController.genders,
                              onChanged: (v) {
                                if (v != null) controller.gender.value = v;
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _FormSectionCard(
                      title: 'Anxiety History',
                      subtitle: 'Select all that apply',
                      child: Obx(
                        () => Theme(
                          data: Theme.of(context).copyWith(
                            checkboxTheme: CheckboxThemeData(
                              fillColor: WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return AppColors.signaraGold;
                                }
                                return Colors.transparent;
                              }),
                              checkColor: WidgetStateProperty.all(const Color(0xFF1A1F1C)),
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                          ),
                          child: Column(
                            children: AddDogController.anxietyOptions.map((o) {
                              final on = controller.selectedAnxiety.contains(o);
                              return CheckboxListTile(
                                value: on,
                                  side: const BorderSide(
    color: Colors.white,
    width: 1.5,
  ),
                                onChanged: (_) => controller.toggleAnxiety(o),
                                title: Text(
                                  o,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 100),
                                    fontSize: 15,
                                    height: 1.25,
                                  ),
                                ),
                                controlAffinity: ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _FormSectionCard(
                      title: 'Mobility History',
                      subtitle: 'Select all that apply',
                      child: Obx(
                        () => Theme(
                          data: Theme.of(context).copyWith(
                            checkboxTheme: CheckboxThemeData(
                              fillColor: WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return AppColors.signaraGold;
                                }
                                return Colors.transparent;
                              }),
                              checkColor: WidgetStateProperty.all(const Color(0xFF1A1F1C)),
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                          ),
                          child: Column(
                            children: AddDogController.mobilityOptions.map((o) {
                              final on = controller.selectedMobility.contains(o);
                              return CheckboxListTile(
                                value: on,
                                  side: const BorderSide(
    color: Colors.white,
    width: 1.5,
  ),
                                onChanged: (_) => controller.toggleMobility(o),
                                title: Text(
                                  o,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.88),
                                    fontSize: 15,
                                    height: 1.25,
                                  ),
                                ),
                                controlAffinity: ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _FormSectionCard(
                      title: 'Additional Notes',
                      subtitle: 'Optional Information',
                      child: SignaraTextField(
                        label: 'Notes',
                        labelTextAlign: TextAlign.start,
                        controller: controller.notesController,
                        hintText: 'eg : dog is good',
                        maxLines: 5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Obx(
                      () => SignaraPrimaryButton(
                        label: 'Save Dog Profile',
                        isLoading: controller.isLoading.value,
                        onPressed: controller.saveProfile,
                      ),
                    ),

                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormSectionCard extends StatelessWidget {
  const _FormSectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F1C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ProfileAvatarBlock extends GetView<AddDogController> {
  const _ProfileAvatarBlock({required this.onCameraTap});

  final VoidCallback onCameraTap;

  static const double _size = 152;
  static const Color _ring = Color(0xFF3D6B4F);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onCameraTap,
      child: SizedBox(
        width: _size + 16,
        height: _size + 16,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Obx(() {
              final x = controller.profileImage.value;
              return Container(
                width: _size,
                height: _size,
               
                child: ClipOval(
                  child: x == null
                      ? Image.asset(
                          _kDogPlaceholderAsset,
                          fit: BoxFit.cover,
                          width: _size,
                          height: _size,
                        )
                      : Image.file(
                          File(x.path),
                          fit: BoxFit.cover,
                          width: _size,
                          height: _size,
                        ),
                ),
              );
            }),
            Positioned(
              right: 12,
              bottom: 12,
              child: GestureDetector(
                onTap: onCameraTap,
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121814),
                    shape: BoxShape.circle,
                    border: Border.all(color: _ring.withValues(alpha: 0.9)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    _kCameraAsset,
                    width: 22,
                    height: 22,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
