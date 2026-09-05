import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/models/models.dart';
import '../../../data/providers/storage_provider.dart';
import '../../atoms/atoms.dart';
import '../../molecules/molecules.dart';
import 'manager_view_model.dart';

/// Edit form for a club — reached from the Manager screen's "Clubs"
/// section. Clubs are pre-seeded (not created through the app), so this is
/// edit-only: name, location, and image.
class ClubFormScreen extends ConsumerStatefulWidget {
  final ClubModel club;

  const ClubFormScreen({super.key, required this.club});

  @override
  ConsumerState<ClubFormScreen> createState() => _ClubFormScreenState();
}

class _ClubFormScreenState extends ConsumerState<ClubFormScreen> {
  late final _nameController = TextEditingController(text: widget.club.name);
  late final _locationController = TextEditingController(
    text: widget.club.location,
  );
  late final _imageUrlController = TextEditingController(
    text: widget.club.imageUrl ?? '',
  );
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _nameController.text.trim().isNotEmpty &&
      _locationController.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_isValid) return;
    setState(() => _isSaving = true);

    final club = ClubModel(
      id: widget.club.id,
      name: _nameController.text.trim(),
      location: _locationController.text.trim(),
      imageUrl: _imageUrlController.text.trim().isEmpty
          ? null
          : _imageUrlController.text.trim(),
    );

    final ok = await ref.read(managerViewModelProvider.notifier).saveClub(club);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (ok) Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: const Text('Modifier le club'),
        leading: GestureDetector(
          onTap: () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Text('Nom', style: AppTypography.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _nameController,
            style: AppTypography.bodyMedium,
            onChanged: (_) => setState(() {}),
            decoration: _decoration(),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Localisation', style: AppTypography.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _locationController,
            style: AppTypography.bodyMedium,
            onChanged: (_) => setState(() {}),
            decoration: _decoration(),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Image', style: AppTypography.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          ImageUrlField(
            controller: _imageUrlController,
            onPickAndUpload: (file) => ref
                .read(storageRepositoryProvider)
                .uploadClubImage(widget.club.id, file),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Enregistrer',
            onTap: _isValid ? _save : null,
            isLoading: _isSaving,
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration() => InputDecoration(
    hintStyle: AppTypography.bodySmall,
    filled: true,
    fillColor: AppColors.background,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
  );
}
