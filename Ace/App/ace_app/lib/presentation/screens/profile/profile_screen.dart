import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/booking_grouping.dart';
import '../../../data/models/models.dart';
import '../../atoms/atoms.dart';
import '../../molecules/molecules.dart';
import '../auth/auth_view_model.dart';
import '../auth/link_phone_screen.dart';
import '../booking_detail/booking_detail_screen.dart';
import '../courts/club_event_providers.dart';
import '../courts/courts_view_model.dart';
import '../edit_profile/edit_profile_screen.dart';
import '../event_detail/event_detail_screen.dart';
import '../manager/manager_screen.dart';
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
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Column(
          children: [
            Expanded(child: _GuestProfilePrompt()),
            _VersionFooter(),
          ],
        ),
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
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  )
                : _BookingsSection(state: state, currentUserId: user.id),
          ),
          SliverToBoxAdapter(child: _SettingsSection()),
          const SliverToBoxAdapter(child: _VersionFooter()),
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
            const Icon(
              Icons.person_outline_rounded,
              size: 64,
              color: AppColors.textTertiary,
            ),
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

class _ProfileHeader extends ConsumerWidget {
  final UserModel user;
  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubNames =
        ref
            .watch(clubsProvider)
            .valueOrNull
            ?.where((c) => user.clubIds.contains(c.id))
            .map((c) => c.name)
            .toList() ??
        const [];
    return SliverAppBar(
      expandedHeight: 200,
      pinned: false,
      stretch: true,
      automaticallyImplyLeading: false,
      // Transparent so nothing shows behind the gradient container's
      // rounded bottom corners — a solid color here would paint square
      // right up to the sliver's edges, peeking out past the radius.
      backgroundColor: const Color.fromARGB(0, 255, 255, 255),
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
                    imageUrl: user.profileImageUrl,
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
                              style: AppTypography.headlineLarge.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Membre depuis ${_formatMemberSince(user.memberSince)}',
                              style: AppTypography.bodySmall.copyWith(
                                color: Colors.white70,
                              ),
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
                      _InfoPill(
                        Icons.calendar_today_rounded,
                        '${user.matchesPerMonth} matchs/mois',
                      ),
                      if (clubNames.isNotEmpty)
                        _InfoPill(
                          Icons.emoji_events_outlined,
                          clubNames.join(', '),
                        ),
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
      'Janvier',
      'Février',
      'Mars',
      'Avril',
      'Mai',
      'Juin',
      'Juillet',
      'Août',
      'Septembre',
      'Octobre',
      'Novembre',
      'Décembre',
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
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      // A plain Row instead of a 2-cell GridView: there are always exactly
      // two cards, so there's no need for grid machinery (and its fixed
      // mainAxisExtent, which was reserving far more height than the cards
      // actually need) — this sizes to the cards' real content height.
      child: Row(
        children: [
          Expanded(
            child: StatCard(
              emoji: '🎾',
              value: '${stats.matchesPlayed}',
              label: 'Matchs joués',
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: StatCard(
              emoji: '⏱',
              value: '${stats.hoursPlayed}h',
              label: 'Heures jouées',
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingsSection extends ConsumerWidget {
  final ProfileState state;
  final String currentUserId;

  const _BookingsSection({required this.state, required this.currentUserId});

  void _openDetail(BuildContext context, BookingModel booking) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => BookingDetailScreen(booking: booking)),
    );
  }

  void _openEvent(BuildContext context, ClubEventModel event) {
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)));
  }

  bool _isEventUpcoming(ClubEventModel event) {
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    final eventDay = DateTime(
      event.date.year,
      event.date.month,
      event.date.day,
    );
    return !eventDay.isBefore(todayDay);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myEvents = (ref.watch(clubEventsProvider).valueOrNull ?? const [])
        .where((e) => e.participantIds.contains(currentUserId))
        .toList();
    final upcomingEvents = myEvents.where(_isEventUpcoming).toList();
    final pastEvents = myEvents.where((e) => !_isEventUpcoming(e)).toList();

    final upcomingBookingGroups = groupConsecutiveBookings(
      state.upcomingBookings,
    );
    final pastBookingGroups = groupConsecutiveBookings(state.pastBookings);

    final upcoming =
        [
          ...upcomingBookingGroups.map(
            (g) => ProfileEntry(
              date: g.first.date,
              startTime: g.first.startTime,
              child: BookingHistoryItem(
                group: g,
                onTap: () => _openDetail(context, g.first),
              ),
            ),
          ),
          ...upcomingEvents.map(
            (e) => ProfileEntry(
              date: e.date,
              startTime: e.startTime,
              child: EventReservationItem(
                event: e,
                onTap: () => _openEvent(context, e),
              ),
            ),
          ),
        ]..sort((a, b) {
          final cmp = a.date.compareTo(b.date);
          return cmp != 0 ? cmp : a.startTime.compareTo(b.startTime);
        });

    final past =
        [
          ...pastBookingGroups.map(
            (g) => ProfileEntry(
              date: g.first.date,
              startTime: g.first.startTime,
              child: BookingHistoryItem(
                group: g,
                titleColor: AppColors.primary,
                onTap: () => _openDetail(context, g.first),
              ),
            ),
          ),
          ...pastEvents.map(
            (e) => ProfileEntry(
              date: e.date,
              startTime: e.startTime,
              child: EventReservationItem(
                event: e,
                titleColor: AppColors.primary,
                onTap: () => _openEvent(context, e),
              ),
            ),
          ),
        ]..sort((a, b) {
          final cmp = b.date.compareTo(a.date);
          return cmp != 0 ? cmp : b.startTime.compareTo(a.startTime);
        });

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        children: [
          if (upcoming.isNotEmpty) ...[
            _SectionHeader(
              title: 'Réservations à venir',
              count: upcoming.length,
            ),
            const SizedBox(height: AppSpacing.sm),
            ...upcoming.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: entry.child,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          _SectionHeader(
            title: 'Historique des réservations',
            count: past.length,
            onViewMore: past.length > 3
                ? () => Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (_) => AllBookingsScreen(
                        bookings: state.pastBookings,
                        events: pastEvents,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          ...past
              .take(3)
              .map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: entry.child,
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

  const _SectionHeader({
    required this.title,
    required this.count,
    this.onViewMore,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(
              Icons.history_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(title, style: AppTypography.headlineSmall),
          ],
        ),
        GestureDetector(
          onTap: onViewMore,
          child: Row(
            children: [
              Text(
                '$count',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
              if (onViewMore != null) ...[
                const SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
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
    final isAdmin =
        ref.watch(currentUserProvider).valueOrNull?.isAdmin ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
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
            icon: Icons.phone_iphone_rounded,
            label: 'Numéro de téléphone',
            subtitle: 'Lier un numéro pour te connecter aussi par SMS',
            onTap: () => Navigator.of(
              context,
              rootNavigator: true,
            ).push(MaterialPageRoute(builder: (_) => const LinkPhoneScreen())),
          ),
          if (isAdmin) ...[
            const SizedBox(height: AppSpacing.md),
            _SettingsCard(
              icon: Icons.shield_rounded,
              label: 'Manager',
              subtitle: 'Organiser des matchs et gérer les réservations',
              onTap: () => Navigator.of(
                context,
                rootNavigator: true,
              ).push(MaterialPageRoute(builder: (_) => const ManagerScreen())),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _SettingsCard(
            icon: Icons.logout_rounded,
            label: 'Déconnexion',
            subtitle: 'Se déconnecter du compte',
            color: AppColors.error,
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Se déconnecter ?'),
                  content: const Text(
                    'Tu devras te reconnecter pour accéder à ton profil et tes réservations.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('Annuler'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: Text(
                        'Se déconnecter',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
              await ref.read(authViewModelProvider.notifier).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}

class _VersionFooter extends StatelessWidget {
  const _VersionFooter();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        if (info == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: Center(
            child: Text(
              'Version ${info.version} (${info.buildNumber})',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
        );
      },
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
                  Text(
                    label,
                    style: AppTypography.headlineSmall.copyWith(color: color),
                  ),
                  Text(subtitle, style: AppTypography.bodySmall),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: onTap != null
                  ? AppColors.textTertiary
                  : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}
