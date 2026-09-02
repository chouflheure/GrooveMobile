import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/models/models.dart';
import '../../atoms/atoms.dart';
import '../../molecules/molecules.dart';
import '../booking_detail/booking_detail_screen.dart';
import '../edit_profile/edit_profile_screen.dart';
import 'all_bookings_screen.dart';
import 'profile_view_model.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileViewModelProvider);
    final user = state.user;

    if (state.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _ProfileHeader(state: state)),
          SliverToBoxAdapter(child: _StatsGrid(state: state)),
          SliverToBoxAdapter(child: _SurfacesSection(user: user)),
          SliverToBoxAdapter(
            child: _BookingsSection(state: state),
          ),
          SliverToBoxAdapter(child: _SettingsSection()),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxxl)),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final ProfileState state;
  const _ProfileHeader({required this.state});

  @override
  Widget build(BuildContext context) {
    final user = state.user;
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
                          style: AppTypography.headlineLarge.copyWith(color: Colors.white),
                        ),
                        Text(
                          'Membre depuis ${_formatMemberSince(user.memberSince)}',
                          style: AppTypography.bodySmall.copyWith(color: Colors.white70),
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
                  _InfoPill(Icons.calendar_today_rounded, '${user.matchesPerMonth} matchs/mois'),
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
        Text(label, style: AppTypography.bodySmall.copyWith(color: Colors.white70)),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final ProfileState state;
  const _StatsGrid({required this.state});

  @override
  Widget build(BuildContext context) {
    final stats = state.user.stats;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
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

class _SurfacesSection extends StatelessWidget {
  final UserModel user;
  const _SurfacesSection({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🎯', style: TextStyle(fontSize: 18)),
              const SizedBox(width: AppSpacing.sm),
              Text('Surfaces préférées', style: AppTypography.headlineSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSurfaceProgress(
            label: 'Terre battue',
            value: user.surfaces.clay,
            color: AppColors.clay,
          ),
          const SizedBox(height: AppSpacing.md),
          AppSurfaceProgress(
            label: 'Dur',
            value: user.surfaces.hard,
            color: AppColors.hard,
          ),
          const SizedBox(height: AppSpacing.md),
          AppSurfaceProgress(
            label: 'Gazon',
            value: user.surfaces.grass,
            color: AppColors.grass,
          ),
        ],
      ),
    );
  }
}

class _BookingsSection extends StatelessWidget {
  final ProfileState state;
  const _BookingsSection({required this.state});

  void _openDetail(BuildContext context, BookingModel booking) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BookingDetailScreen(booking: booking)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = state.upcomingBookings;
    final past = state.pastBookings;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        children: [
          if (upcoming.isNotEmpty) ...[
            _SectionHeader(title: 'Réservations à venir', count: upcoming.length),
            const SizedBox(height: AppSpacing.sm),
            ...upcoming.take(2).map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: BookingHistoryItem(
                      booking: b,
                      onTap: () => _openDetail(context, b),
                    ),
                  ),
                ),
            const SizedBox(height: AppSpacing.md),
          ],
          _SectionHeader(
            title: 'Historique des réservations',
            count: past.length,
            onViewMore: past.length > 4
                ? () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => AllBookingsScreen(bookings: past)),
                    )
                : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          ...past.take(4).map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: BookingHistoryItem(
                    booking: b,
                    titleColor: AppColors.primary,
                    onTap: () => _openDetail(context, b),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final VoidCallback? onViewMore;

  const _SectionHeader({required this.title, required this.count, this.onViewMore});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.history_rounded, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.xs),
            Text(title, style: AppTypography.headlineSmall),
          ],
        ),
        GestureDetector(
          onTap: onViewMore,
          child: Row(
            children: [
              Text('$count', style: AppTypography.labelMedium.copyWith(color: AppColors.primary)),
              if (onViewMore != null) ...[
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.primary),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsSection extends StatefulWidget {
  @override
  State<_SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends State<_SettingsSection> {
  bool _notificationsEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        children: [
          _SettingsCard(
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            subtitle: _notificationsEnabled ? 'Activées' : 'Désactivées',
            trailing: Switch.adaptive(
              value: _notificationsEnabled,
              onChanged: (v) => setState(() => _notificationsEnabled = v),
              activeThumbColor: AppColors.primary,
              activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SettingsCard(
            icon: Icons.settings_outlined,
            label: 'Paramètres',
            subtitle: 'Modifier mon profil',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SettingsCard(
            icon: Icons.logout_rounded,
            label: 'Déconnexion',
            subtitle: 'Se déconnecter du compte',
            color: AppColors.error,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _SettingsCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    this.color = AppColors.textPrimary,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTypography.headlineSmall
                          .copyWith(color: color)),
                  Text(subtitle, style: AppTypography.bodySmall),
                ],
              ),
            ),
            trailing ??
                Icon(Icons.chevron_right_rounded,
                    color: onTap != null
                        ? AppColors.textTertiary
                        : Colors.transparent),
          ],
        ),
      ),
    );
  }
}
