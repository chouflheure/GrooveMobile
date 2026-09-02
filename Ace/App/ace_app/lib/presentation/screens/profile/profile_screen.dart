import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/models/models.dart';
import '../../atoms/atoms.dart';
import '../../molecules/molecules.dart';
import '../auth/auth_view_model.dart';
import '../booking_detail/booking_detail_screen.dart';
import '../edit_profile/edit_profile_screen.dart';
import '../notification_settings/notification_settings_screen.dart';
import 'all_bookings_screen.dart';
import 'profile_view_model.dart';

const _headerGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [AppColors.primaryDark, AppColors.primary, AppColors.primaryLight],
);

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.valueOrNull;

    if (userAsync.isLoading && !userAsync.hasValue) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (user == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: _GuestProfilePrompt(),
      );
    }

    final state = ref.watch(profileViewModelProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _ProfileHeader(user: user),
          SliverToBoxAdapter(child: _StatsGrid(user: user)),
          SliverToBoxAdapter(
            child: state.isLoading
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.xxl),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  )
                : _BookingsSection(state: state),
          ),
          SliverToBoxAdapter(child: _SettingsSection()),
          SliverToBoxAdapter(
            child: SizedBox(
              height: AppSpacing.xxxl + MediaQuery.paddingOf(context).bottom,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestProfilePrompt extends StatelessWidget {
  const _GuestProfilePrompt();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_outline_rounded, size: 64, color: AppColors.textTertiary),
            const SizedBox(height: AppSpacing.md),
            Text('Pas encore connecté', style: AppTypography.headlineMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Connecte-toi pour voir ton profil, tes statistiques et tes réservations.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'Se connecter',
                onTap: () => context.go('/login'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserModel user;
  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 230,
      pinned: true,
      stretch: true,
      automaticallyImplyLeading: false,
      backgroundColor: AppColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: _headerGradient,
            borderRadius: BorderRadius.only(
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
                AppSpacing.lg,
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
                      _InfoPill(Icons.calendar_today_rounded, '${user.matchesPerMonth} matchs/mois'),
                    ],
                  ),
                ],
              ),
            ),
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
  final UserModel user;
  const _StatsGrid({required this.user});

  @override
  Widget build(BuildContext context) {
    final stats = user.stats;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
      child: GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          mainAxisExtent: 136,
        ),
        children: [
          StatCard(emoji: '🎾', value: '${stats.matchesPlayed}', label: 'Matchs joués'),
          StatCard(emoji: '⏱', value: '${stats.hoursPlayed}h', label: 'Heures jouées'),
        ],
      ),
    );
  }
}

class _BookingsSection extends StatelessWidget {
  final ProfileState state;
  const _BookingsSection({required this.state});

  void _openDetail(BuildContext context, BookingModel booking) {
    Navigator.of(context, rootNavigator: true).push(
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
            ...upcoming.map(
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
            onViewMore: past.length > 3
                ? () => Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(builder: (_) => AllBookingsScreen(bookings: past)),
                    )
                : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          ...past.take(3).map(
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

class _SettingsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        children: [
          _SettingsCard(
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            subtitle: 'Gérer mes notifications',
            onTap: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (_) => const NotificationSettingsScreen(),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SettingsCard(
            icon: Icons.settings_outlined,
            label: 'Paramètres',
            subtitle: 'Modifier mon profil',
            onTap: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SettingsCard(
            icon: Icons.logout_rounded,
            label: 'Déconnexion',
            subtitle: 'Se déconnecter du compte',
            color: AppColors.error,
            onTap: () async {
              await ref.read(authViewModelProvider.notifier).signOut();
              if (context.mounted) context.go('/login');
            },
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

  const _SettingsCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    this.color = AppColors.textPrimary,
    this.onTap,
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
