import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/widgets/app_text_field.dart';
import 'package:meetit/core/widgets/circular_avatar.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:quickalert/quickalert.dart';

final editNameControllerProvider = Provider.autoDispose<TextEditingController>((
  ref,
) {
  final c = TextEditingController(
    text: ref.read(currentUserProvider)?.name ?? '',
  );
  ref.onDispose(c.dispose);
  return c;
});

final editLocationControllerProvider =
    Provider.autoDispose<TextEditingController>((ref) {
      final c = TextEditingController(
        text: ref.read(currentUserProvider)?.location ?? '',
      );
      ref.onDispose(c.dispose);
      return c;
    });

final editAgeControllerProvider = Provider.autoDispose<TextEditingController>((
  ref,
) {
  final age = ref.read(currentUserProvider)?.age;
  final c = TextEditingController(text: age != null ? age.toString() : '');
  ref.onDispose(c.dispose);
  return c;
});

final editGenderProvider = StateProvider.autoDispose<String?>((ref) {
  return ref.read(currentUserProvider)?.gender;
});

final editProfileLoadingProvider = StateProvider.autoDispose<bool>(
  (ref) => false,
);

// Seçilen fotoğraf dosyası
final editPhotoFileProvider = StateProvider.autoDispose<File?>((ref) => null);

class EditProfilePage extends ConsumerWidget {
  const EditProfilePage({super.key});

  List<String> _genders(BuildContext context) => [
        'auth.gender_male'.tr(),
        'auth.gender_female'.tr(),
        'auth.gender_other'.tr(),
      ];

  Future<void> _pickPhoto(WidgetRef ref) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 800,
    );
    if (picked != null) {
      ref.read(editPhotoFileProvider.notifier).state = File(picked.path);
    }
  }

  Future<String?> _uploadPhoto(File file, String uid) async {
    try {
      final ref = FirebaseStorage.instance.ref().child(
        'profile_photos/$uid.jpg',
      );
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  Future<void> _onSave(BuildContext context, WidgetRef ref) async {
    final name = ref.read(editNameControllerProvider).text.trim();
    final location = ref.read(editLocationControllerProvider).text.trim();
    final ageText = ref.read(editAgeControllerProvider).text.trim();
    final gender = ref.read(editGenderProvider);
    final photoFile = ref.read(editPhotoFileProvider);
    final currentUser = ref.read(currentUserProvider);

    if (name.isEmpty) {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.warning,
        title: 'validation.missing_field'.tr(),
        text: 'edit_profile.missing_name'.tr(),
        confirmBtnColor: context.colors.primary,
      );
      return;
    }

    final age = ageText.isNotEmpty ? int.tryParse(ageText) : null;
    if (ageText.isNotEmpty && (age == null || age < 18)) {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'validation.invalid_age'.tr(),
        text: 'edit_profile.invalid_age'.tr(),
        confirmBtnColor: context.colors.primary,
      );
      return;
    }

    ref.read(editProfileLoadingProvider.notifier).state = true;

    try {
      String? photoUrl = currentUser?.photoUrl;

      // Fotoğraf yükleme
      if (photoFile != null && currentUser != null) {
        photoUrl = await _uploadPhoto(photoFile, currentUser.uid);
      }

      // Firestore güncelle
      final uid = currentUser?.uid ?? FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final updates = <String, dynamic>{
          'name': name,
          if (location.isNotEmpty) 'location': location,
          if (age != null) 'age': age,
          if (gender != null) 'gender': gender,
          if (photoUrl != null) 'photoUrl': photoUrl,
        };
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update(updates);
      }

      // Firebase Auth display name güncelle
      await FirebaseAuth.instance.currentUser?.updateDisplayName(name);

      // Local state güncelle
      final updatedUser = currentUser?.copyWith(
        name: name,
        location: location.isNotEmpty ? location : null,
        age: age,
        gender: gender,
        photoUrl: photoUrl,
      );
      if (updatedUser != null) {
        await ref.read(authProvider.notifier).updateUser(updatedUser);
      }

      if (!context.mounted) return;
      if (!context.mounted) return;
      final nav = Navigator.of(context);
      QuickAlert.show(
        context: context,
        type: QuickAlertType.success,
        title: 'edit_profile.saved'.tr(),
        text: 'edit_profile.profile_updated'.tr(),
        confirmBtnColor: context.colors.primary,
        onConfirmBtnTap: () {
          nav.pop(); // QuickAlert dialog'unu kapat
          nav.pop(); // Edit Profile sayfasını kapat
        },
      );
    } catch (e) {
      ref.read(editProfileLoadingProvider.notifier).state = false;
      if (!context.mounted) return;
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'common.error'.tr(),
        text: 'edit_profile.update_error'.tr(),
        confirmBtnColor: context.colors.primary,
      );
    }

    ref.read(editProfileLoadingProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final isLoading = ref.watch(editProfileLoadingProvider);
    final selectedGender = ref.watch(editGenderProvider);
    final photoFile = ref.watch(editPhotoFileProvider);

    final nameCtrl = ref.watch(editNameControllerProvider);
    final locationCtrl = ref.watch(editLocationControllerProvider);
    final ageCtrl = ref.watch(editAgeControllerProvider);

    return Scaffold(
      backgroundColor: context.colors.scaffold,
      appBar: AppBar(
        backgroundColor: context.colors.scaffold,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: context.colors.textPrimary,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'edit_profile.title'.tr(),
          style: TextStyle(
            color: context.colors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          TextButton(
            onPressed: isLoading ? null : () => _onSave(context, ref),
            child: Text(
              'common.save'.tr(),
              style: TextStyle(
                color: context.colors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Avatar + Fotoğraf ──────────────────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: () => _pickPhoto(ref),
                  child: Stack(
                    children: [
                      // Fotoğraf: seçilen dosya > mevcut URL > harf avatar
                      if (photoFile != null)
                        CircleAvatar(
                          radius: 46,
                          backgroundImage: FileImage(photoFile),
                        )
                      else if (currentUser?.photoUrl != null)
                        CircleAvatar(
                          radius: 46,
                          backgroundImage: NetworkImage(currentUser!.photoUrl!),
                        )
                      else
                        CircularAvatar(
                          name: currentUser?.name ?? 'K',
                          radius: 46,
                        ),

                      // Kamera ikonu
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: context.colors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.colors.card,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: () => _pickPhoto(ref),
                  icon: Icon(
                    Icons.photo_camera_outlined,
                    size: 16,
                    color: context.colors.primary,
                  ),
                  label: Text(
                    photoFile != null
                        ? 'edit_profile.photo_selected'.tr()
                        : 'edit_profile.change_photo'.tr(),
                    style: TextStyle(
                      color: photoFile != null
                          ? context.colors.success
                          : context.colors.primary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              _SectionLabel(label: 'edit_profile.section_personal'.tr()),
              const SizedBox(height: 12),

              AppTextField(
                controller: nameCtrl,
                label: 'auth.name_surname'.tr(),
                hint: 'auth.name_hint'.tr(),
                prefixIcon: Icons.person_outline,
                textInputAction: TextInputAction.next,
              ),
              SizedBox(height: 16),

              // Email (düzenlenemez)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.colors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.mail_outline,
                      color: context.colors.hint,
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        currentUser?.email ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: context.colors.hint,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.lock_outline,
                      size: 14,
                      color: context.colors.hint,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(
                  'edit_profile.email_locked'.tr(),
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.hint.withOpacity(0.8),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              AppTextField(
                controller: locationCtrl,
                label: 'auth.city_location'.tr(),
                hint: 'auth.location_hint'.tr(),
                prefixIcon: Icons.location_on_outlined,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              AppTextField(
                controller: ageCtrl,
                label: 'auth.age'.tr(),
                hint: 'auth.age_hint'.tr(),
                prefixIcon: Icons.cake_outlined,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
              ),
              SizedBox(height: 16),

              // Cinsiyet
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'auth.gender'.tr(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedGender,
                    decoration: _dropdownDecoration(context),
                    hint: Text(
                      'auth.gender_hint'.tr(),
                      style: TextStyle(
                        color: context.colors.hint,
                        fontSize: 14,
                      ),
                    ),
                    items: _genders(context)
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (v) =>
                        ref.read(editGenderProvider.notifier).state = v,
                  ),
                ],
              ),

              SizedBox(height: 36),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : () => _onSave(context, ref),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: context.colors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: isLoading
                      ? SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.colors.card,
                          ),
                        )
                      : Text(
                          'edit_profile.save_changes'.tr(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _dropdownDecoration(BuildContext context) {
    return InputDecoration(
      filled: true,
      fillColor: context.colors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.colors.border, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.colors.border, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.colors.primary, width: 1.6),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: context.colors.textSecondary,
        letterSpacing: 0.8,
      ),
    );
  }
}
