import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/models/models.dart';
import '../../../data/providers/storage_provider.dart';
import '../../atoms/atoms.dart';
import '../auth/auth_view_model.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _locationController;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  late String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider).value!;
    _nameController = TextEditingController(text: user.name);
    _emailController = TextEditingController(text: user.email);
    _phoneController = TextEditingController(text: user.phone ?? '');
    _locationController = TextEditingController(text: user.location);
    _profileImageUrl = user.profileImageUrl;
  }

  Future<void> _pickAndUploadPhoto(String userId) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final url = await ref
          .read(storageRepositoryProvider)
          .uploadUserImage(userId, File(picked.path));
      if (!mounted) return;
      setState(() => _profileImageUrl = url);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Échec de l\'envoi de la photo : $e',
        type: AppSnackbarType.error,
      );
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: const Text('Modifier le profil'),
        leading: GestureDetector(
          onTap: () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Center(
            child: GestureDetector(
              onTap: _isUploadingPhoto ? null : () => _pickAndUploadPhoto(user.id),
              child: Stack(
                children: [
                  AppAvatar(
                    initials: user.initials,
                    imageUrl: _profileImageUrl,
                    size: 80,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: _isUploadingPhoto
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          _Field(
            label: 'Nom complet',
            controller: _nameController,
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
          _Field(
            label: 'Email',
            controller: _emailController,
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            enabled: false,
            helperText: 'Non modifiable — c\'est ton identifiant de connexion.',
          ),
          const SizedBox(height: AppSpacing.md),
          _Field(
            label: 'Téléphone',
            controller: _phoneController,
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: AppSpacing.md),
          _Field(
            label: 'Localisation',
            controller: _locationController,
            icon: Icons.location_on_outlined,
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppButton(
            label: 'Enregistrer',
            onTap: _isSaving ? null : () => _save(user),
            isLoading: _isSaving,
          ),
        ],
      ),
    );
  }

  Future<void> _save(UserModel user) async {
    setState(() => _isSaving = true);
    try {
      await ref
          .read(userRepositoryProvider)
          .update(
            user.copyWith(
              name: _nameController.text.trim(),
              email: _emailController.text.trim(),
              phone: _phoneController.text.trim().isEmpty
                  ? null
                  : _phoneController.text.trim(),
              location: _locationController.text.trim(),
              profileImageUrl: _profileImageUrl,
            ),
          );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      AppSnackbar.show(
        context,
        message: 'Profil mis à jour !',
        type: AppSnackbarType.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppSnackbar.show(
        context,
        message: 'Une erreur est survenue, réessaie.',
        type: AppSnackbarType.error,
      );
    }
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType keyboardType;
  final bool enabled;
  final String? helperText;

  const _Field({
    required this.label,
    required this.controller,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.enabled = true,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          enabled: enabled,
          style: AppTypography.bodyMedium,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: AppColors.textSecondary),
            filled: true,
            fillColor: enabled ? AppColors.surface : AppColors.surfaceVariant,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            helperText!,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ],
    );
  }
}
