import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../atoms/app_skeleton_box.dart';

/// Stand-in for [CourtCard] while courts are loading — mirrors its layout
/// (180px image block, badge pills, title/location lines, slot chip row)
/// so the list doesn't visibly jump once real cards swap in.
class CourtCardSkeleton extends StatelessWidget {
  const CourtCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 180,
            width: double.infinity,
            child: Stack(
              children: [
                const AppSkeletonBox(
                  width: double.infinity,
                  height: 180,
                  borderRadius: BorderRadius.zero,
                ),
                Positioned(
                  top: AppSpacing.md,
                  left: AppSpacing.md,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSkeletonBox(
                        width: 64,
                        height: 22,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusFull,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AppSkeletonBox(
                        width: 64,
                        height: 22,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusFull,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: AppSpacing.md,
                  right: AppSpacing.md,
                  child: AppSkeletonBox(
                    width: 56,
                    height: 22,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                ),
                Positioned(
                  bottom: AppSpacing.md,
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppSkeletonBox(width: 100, height: 12),
                      const SizedBox(height: 6),
                      AppSkeletonBox(width: 160, height: 18),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AppSkeletonBox(width: 140, height: 14),
                    AppSkeletonBox(width: 60, height: 14),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    AppSkeletonBox(
                      width: 64,
                      height: 36,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppSkeletonBox(
                      width: 64,
                      height: 36,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppSkeletonBox(
                      width: 64,
                      height: 36,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
