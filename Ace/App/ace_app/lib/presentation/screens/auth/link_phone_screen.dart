import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../atoms/atoms.dart';
import 'auth_view_model.dart';
import 'phone_auth_view_model.dart';

/// Lets an already signed-in (email) user attach a phone number to their
/// account, so they can sign in with either afterwards.
class LinkPhoneScreen extends ConsumerStatefulWidget {
  const LinkPhoneScreen({super.key});

  @override
  ConsumerState<LinkPhoneScreen> createState() => _LinkPhoneScreenState();
}

class _LinkPhoneScreenState extends ConsumerState<LinkPhoneScreen> {
  final _phoneInput = PhoneInputController();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _phoneInput.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final credentialResult = await ref
        .read(phoneAuthViewModelProvider.notifier)
        .confirmCode(_codeController.text, link: true);
    if (credentialResult == null || !mounted) return;

    final user = ref.read(currentUserProvider).valueOrNull;
    if (user != null) {
      await ref
          .read(userRepositoryProvider)
          .update(user.copyWith(phone: _phoneInput.e164));
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Numéro de téléphone lié à ton compte.'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    final phoneState = ref.watch(phoneAuthViewModelProvider);

    ref.listen(phoneAuthViewModelProvider, (prev, next) {
      if (next.errorMessage != null &&
          next.errorMessage != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: const Text('Lier un numéro de téléphone'),
        leading: GestureDetector(
          onTap: () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (phoneState.step == PhoneAuthStep.enterNumber) ...[
              Text('Numéro de téléphone', style: AppTypography.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              PhoneNumberField(controller: _phoneInput),
              const SizedBox(height: AppSpacing.xl),
              _PrimaryButton(
                label: 'Envoyer le code',
                isLoading: phoneState.isLoading,
                onTap: () => ref
                    .read(phoneAuthViewModelProvider.notifier)
                    .sendCode(_phoneInput.e164),
              ),
            ] else ...[
              Text('Code reçu par SMS', style: AppTypography.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Un code a été envoyé au ${phoneState.phoneNumber}.',
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              _Field(
                controller: _codeController,
                hint: '123456',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.xl),
              _PrimaryButton(
                label: 'Confirmer',
                isLoading: phoneState.isLoading,
                onTap: _confirm,
              ),
              const SizedBox(height: AppSpacing.md),
              GestureDetector(
                onTap: () =>
                    ref.read(phoneAuthViewModelProvider.notifier).reset(),
                child: Text(
                  'Changer de numéro',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;

  const _Field({
    required this.controller,
    required this.hint,
    required this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: AppTypography.bodyMedium,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.bodySmall,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
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
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isLoading;

  const _PrimaryButton({
    required this.label,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                label,
                style: AppTypography.labelLarge.copyWith(color: Colors.white),
              ),
      ),
    );
  }
}
