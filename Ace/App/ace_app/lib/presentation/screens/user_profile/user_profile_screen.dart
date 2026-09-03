import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/models/models.dart';
import '../../../data/providers/favorites_provider.dart';
import '../../atoms/atoms.dart';
import '../../molecules/molecules.dart';
import '../courts/courts_view_model.dart';

class UserProfileScreen extends ConsumerWidget {
  final UserModel user;

  const UserProfileScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final isFavorite = favorites.contains(user.id);
    final clubNames = ref
        .watch(clubsProvider)
        .valueOrNull
        ?.where((c) => user.clubIds.contains(c.id))
        .map((c) => c.name)
        .toList() ??
        const [];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _UserHeader(
              user: user,
              isFavorite: isFavorite,
              ref: ref,
              clubNames: clubNames,
            ),
          ),
          SliverToBoxAdapter(child: _StatsGrid(user: user)),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxxl)),
        ],
      ),
    );
  }
}

class _UserHeader extends StatelessWidget {
  final UserModel user;
  final bool isFavorite;
  final WidgetRef ref;
  final List<String> clubNames;

  const _UserHeader({
    required this.user,
    required this.isFavorite,
    required this.ref,
    this.clubNames = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary, AppColors.primaryLight],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppSpacing.radiusXl),
          bottomRight: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.lg,
            AppSpacing.xxl,
            AppSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context, rootNavigator: true).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () =>
                        ref.read(favoritesProvider.notifier).toggle(user.id),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: isFavorite
                            ? Colors.white.withValues(alpha: 0.9)
                            : Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isFavorite ? AppColors.primary : Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppAvatar(
                initials: user.initials,
                size: 72,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: AppTypography.headlineLarge
                              .copyWith(color: Colors.white),
                        ),
                        Text(
                          'Membre depuis ${_formatMemberSince(user.memberSince)}',
                          style: AppTypography.bodySmall
                              .copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  AppBadge.ranking(user.ranking),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.md,
                children: [
                  _InfoPill(Icons.location_on_rounded, user.location),
                  _InfoPill(Icons.star_rounded, '${user.rating}/5'),
                  _InfoPill(Icons.calendar_today_rounded,
                      '${user.matchesPerMonth} matchs/mois'),
                  if (clubNames.isNotEmpty)
                    _InfoPill(Icons.emoji_events_outlined, clubNames.join(', ')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatMemberSince(DateTime date) {
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoPill(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white70),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: Text(
            label,
            style: AppTypography.bodySmall.copyWith(color: Colors.white70),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final UserModel user;
  const _StatsGrid({required this.user});

  @override
  Widget build(BuildContext context) {
    final stats = user.stats;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.3,
        children: [
          StatCard(emoji: '🎾', value: '${stats.matchesPlayed}', label: 'Matchs joués'),
          StatCard(emoji: '🏆', value: '${stats.wins}', label: 'Victoires'),
          StatCard(
            emoji: '📈',
            value: '${(stats.winRate * 100).round()}%',
            label: 'Win rate',
          ),
          StatCard(emoji: '⏱', value: '${stats.hoursPlayed}h', label: 'Heures jouées'),
        ],
      ),
    );
  }
}

