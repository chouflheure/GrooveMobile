import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/models/models.dart';
import '../../molecules/molecules.dart';
import '../auth/auth_view_model.dart';
import '../courts/tournament_providers.dart';

/// Player-facing tournament screen — the same bracket the admin sees, but
/// read-only (no schedule/winner actions), plus the self-service
/// register/unregister toggle while `status == registration`.
class TournamentDetailScreen extends ConsumerWidget {
  final TournamentModel tournament;

  const TournamentDetailScreen({super.key, required this.tournament});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Falls back to the snapshot passed at navigation time until the live
    // data has loaded, same pattern as EventDetailScreen.
    final live = ref
        .watch(tournamentsProvider)
        .valueOrNull
        ?.where((t) => t.id == tournament.id)
        .firstOrNull;
    final current = live ?? tournament;
    final allUsers = ref.watch(allUsersProvider).valueOrNull ?? const [];
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final isParticipating =
        currentUser != null && current.participantIds.contains(currentUser.id);

    String playerName(String id) =>
        allUsers.where((u) => u.id == id).firstOrNull?.name ?? 'Joueur';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(current.clubName)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(current.title, style: AppTypography.displayMedium),
            if (current.description.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                current.description,
                style: AppTypography.bodyMedium.copyWith(height: 1.6),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const Icon(
                  Icons.group_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${current.participantIds.length} inscrit${current.participantIds.length >= 2 ? 's' : ''}',
                  style: AppTypography.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            if (current.matches.isEmpty)
              Text(
                'Le bracket sera tiré une fois les inscriptions closes.',
                style: AppTypography.bodyMedium,
              )
            else
              TournamentBracket(tournament: current, playerName: playerName),
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
      bottomNavigationBar: current.status == TournamentStatus.registration
          ? SafeArea(
              minimum: const EdgeInsets.all(AppSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isParticipating
                        ? AppColors.primaryContainer
                        : AppColors.primary,
                    foregroundColor: isParticipating
                        ? AppColors.primary
                        : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    if (currentUser == null) {
                      context.go('/login');
                      return;
                    }
                    ref
                        .read(tournamentRepositoryProvider)
                        .setParticipating(
                          current.id,
                          currentUser.id,
                          !isParticipating,
                        );
                  },
                  child: Text(
                    isParticipating ? 'Inscrit ✓' : "S'inscrire",
                    style: AppTypography.labelLarge.copyWith(
                      color: isParticipating ? AppColors.primary : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
