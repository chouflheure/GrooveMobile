import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../screens/courts/courts_view_model.dart';

/// The club's logo + name once one is unambiguous — either the club picked
/// in the courts screen's club filter, or the only club there is to show
/// (most players belong to just one). Falls back to the generic app
/// branding for a guest or an unfiltered multi-club view, where there's no
/// single club to represent. Shared between the mobile courts screen's own
/// app bar and the web shell's persistent top bar (see `MainScaffold`).
class AppBrandMark extends ConsumerWidget {
  const AppBrandMark({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(courtsViewModelProvider);
    final club = state.selectedClubId != null
        ? state.clubs.where((c) => c.id == state.selectedClubId).firstOrNull
        : (state.clubs.length == 1 ? state.clubs.single : null);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BrandLogo(imageUrl: club?.imageUrl),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            club?.name ?? AppConstants.appName,
            style: AppTypography.headlineLarge.copyWith(
              color: AppColors.primary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _BrandLogo extends StatelessWidget {
  final String? imageUrl;

  const _BrandLogo({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) return const _FallbackMark();
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        placeholder: (_, _) => Container(
          width: 44,
          height: 44,
          color: AppColors.surfaceVariant,
        ),
        errorWidget: (_, _, _) => const _FallbackMark(),
      ),
    );
  }
}

class _FallbackMark extends StatelessWidget {
  const _FallbackMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.sports_tennis_rounded,
        color: Colors.white,
        size: 24,
      ),
    );
  }
}
