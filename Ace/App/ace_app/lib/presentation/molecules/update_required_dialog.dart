import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../atoms/atoms.dart';

/// Shown on launch when the installed app version is below the one Remote
/// Config requires. Dismissible by tapping outside unless [mandatory] is
/// true, in which case there is no way to close it short of updating.
class UpdateRequiredDialog extends StatelessWidget {
  const UpdateRequiredDialog({super.key, required this.mandatory});

  final bool mandatory;

  static Future<void> show(BuildContext context, {required bool mandatory}) {
    return showDialog(
      context: context,
      barrierDismissible: !mandatory,
      builder: (_) => PopScope(
        canPop: !mandatory,
        child: UpdateRequiredDialog(mandatory: mandatory),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _RacketBanner(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    mandatory
                        ? 'Mise à jour nécessaire'
                        : 'Mise à jour disponible',
                    textAlign: TextAlign.center,
                    style: AppTypography.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    mandatory
                        ? 'Une nouvelle version de CourtConnect est disponible '
                              'et est nécessaire pour continuer à utiliser '
                              'l\'application.'
                        : 'Une nouvelle version de CourtConnect est disponible. '
                              'Nous te recommandons de mettre à jour l\'application.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: 'Mettre à jour',
                      onTap: () {
                        // TODO: brancher les liens App Store / Play Store réels.
                      },
                    ),
                  ),
                  if (!mandatory) ...[
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Plus tard',
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The illustration banner up top — a tennis racket floating over the app's
/// green gradient, with a couple of soft translucent circles behind it for
/// depth (in place of the rocket-launch/clouds illustration this was based
/// on).
class _RacketBanner extends StatelessWidget {
  const _RacketBanner();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 170,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primaryDark,
                  AppColors.primary,
                  AppColors.primaryLight,
                ],
              ),
            ),
          ),
          Positioned(
            left: -30,
            top: -30,
            child: _softCircle(120, 0.10),
          ),
          Positioned(
            right: -20,
            bottom: -40,
            child: _softCircle(140, 0.08),
          ),
          Positioned(
            right: 20,
            top: 24,
            child: _softCircle(36, 0.14),
          ),
          const Center(
            child: Icon(
              Icons.sports_tennis_rounded,
              size: 76,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _softCircle(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}
