import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/models/models.dart';
import '../../atoms/atoms.dart';
import 'court_form_screen.dart';
import 'event_form_screen.dart';
import 'group_chat_form_screen.dart';
import 'manager_view_model.dart';
import 'match_form_screen.dart';

class ManagerScreen extends ConsumerWidget {
  const ManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(managerViewModelProvider);
    final vm = ref.read(managerViewModelProvider.notifier);

    if (state.message != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.message!),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        vm.clearMessage();
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(scrolledUnderElevation: 0, title: const Text('Manager')),
      body: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _MatchOrganizerSection(),
                  const SizedBox(height: AppSpacing.xxl),
                  _CourtsManagementSection(state: state),
                  const SizedBox(height: AppSpacing.xxl),
                  _EventsManagementSection(state: state),
                  const SizedBox(height: AppSpacing.xxl),
                  _GroupChatSection(players: state.players),
                  const SizedBox(height: AppSpacing.xxl),
                  _ActiveBookingsSection(state: state, vm: vm),
                  const SizedBox(height: AppSpacing.xxl),
                  _AdminsSection(admins: state.admins),
                ],
              ),
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(title, style: AppTypography.headlineSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class _MatchOrganizerSection extends StatelessWidget {
  const _MatchOrganizerSection();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.sports_tennis_rounded,
      title: 'Organiser un match',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bloque un terrain pour un match, avec ou sans joueurs assignés.',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(builder: (_) => const MatchFormScreen()),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Créer un match'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveBookingsSection extends StatelessWidget {
  final ManagerState state;
  final ManagerViewModel vm;

  const _ActiveBookingsSection({required this.state, required this.vm});

  @override
  Widget build(BuildContext context) {
    final bookings = state.activeBookings;
    return _SectionCard(
      icon: Icons.event_busy_rounded,
      title: 'Annuler une réservation',
      child: bookings.isEmpty
          ? Text('Aucune réservation active.', style: AppTypography.bodySmall)
          : Column(
              children: bookings
                  .map(
                    (b) => _BookingRow(
                      booking: b,
                      onCancel: () => _confirmCancel(context, vm, b),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  void _confirmCancel(
    BuildContext context,
    ManagerViewModel vm,
    BookingModel booking,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Annuler cette réservation ?'),
        content: Text(
          '${booking.courtName} · ${booking.date.day}/${booking.date.month} · ${booking.startTime}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Retour'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              vm.cancelBooking(booking.id);
            },
            child: const Text(
              'Annuler la réservation',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingRow extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback onCancel;

  const _BookingRow({required this.booking, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(booking.courtName, style: AppTypography.headlineSmall),
                if (booking.title != null && booking.title!.isNotEmpty)
                  Text(
                    booking.title!,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                Text(
                  '${booking.date.day.toString().padLeft(2, '0')}/${booking.date.month.toString().padLeft(2, '0')} · ${booking.startTime}-${booking.endTime}'
                  '${booking.partnerName != null ? ' · avec ${booking.partnerName}' : ''}',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onCancel,
            child: const Text(
              'Annuler',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourtsManagementSection extends StatelessWidget {
  final ManagerState state;

  const _CourtsManagementSection({required this.state});

  void _openForm(BuildContext context, {CourtModel? court}) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => CourtFormScreen(court: court, clubs: state.clubs),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.location_on_rounded,
      title: 'Terrains',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.courts.isEmpty)
            Text(
              'Aucun terrain pour le moment.',
              style: AppTypography.bodySmall,
            )
          else
            ...state.courts.map((c) {
              final clubName = state.clubs
                  .where((cl) => cl.id == c.clubId)
                  .firstOrNull
                  ?.name;
              return GestureDetector(
                onTap: () => _openForm(context, court: c),
                child: Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.name, style: AppTypography.headlineSmall),
                            Text(
                              '${c.type.label} · ${c.surface.label}'
                              '${clubName != null ? ' · $clubName' : ''}',
                              style: AppTypography.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.edit_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openForm(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Ajouter un terrain'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventsManagementSection extends StatelessWidget {
  final ManagerState state;

  const _EventsManagementSection({required this.state});

  void _openForm(BuildContext context, {ClubEventModel? event}) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => EventFormScreen(
          event: event,
          clubs: state.clubs,
          courts: state.courts,
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final sorted = [...state.events]..sort((a, b) => a.date.compareTo(b.date));
    return _SectionCard(
      icon: Icons.event_rounded,
      title: 'Événements',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sorted.isEmpty)
            Text(
              'Aucun événement pour le moment.',
              style: AppTypography.bodySmall,
            )
          else
            ...sorted.map(
              (e) => GestureDetector(
                onTap: () => _openForm(context, event: e),
                child: Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.title, style: AppTypography.headlineSmall),
                            Text(
                              '${_fmt(e.date)} · ${e.clubName} · ${e.participantIds.length} participant(s)',
                              style: AppTypography.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.edit_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openForm(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Créer un événement'),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupChatSection extends StatelessWidget {
  final List<UserModel> players;

  const _GroupChatSection({required this.players});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.groups_rounded,
      title: 'Conversation de groupe',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Démarre une conversation avec plusieurs joueurs à la fois.',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) => GroupChatFormScreen(players: players),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Créer une conversation de groupe'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminsSection extends StatelessWidget {
  final List<UserModel> admins;

  const _AdminsSection({required this.admins});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.shield_rounded,
      title: 'Administrateurs',
      child: admins.isEmpty
          ? Text('Aucun administrateur trouvé.', style: AppTypography.bodySmall)
          : Column(
              children: admins
                  .map(
                    (u) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        children: [
                          AppAvatar(initials: u.initials, size: 36),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  u.name,
                                  style: AppTypography.headlineSmall,
                                ),
                                Text(u.email, style: AppTypography.bodySmall),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}
