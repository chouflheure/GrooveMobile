import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';

/// A shimmering placeholder rectangle — the building block for skeleton
/// loading states (see `CourtCardSkeleton`). Each instance runs its own
/// shimmer animation, so a screen full of them still looks like one
/// coherent sweep since they share the same duration/direction.
class AppSkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadiusGeometry borderRadius;

  const AppSkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(
      Radius.circular(AppSpacing.radiusSm),
    ),
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceVariant,
      highlightColor: AppColors.surface,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}
