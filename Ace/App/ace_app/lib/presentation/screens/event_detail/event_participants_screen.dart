import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/models/models.dart';
import '../../atoms/atoms.dart';
import '../auth/auth_view_model.dart';

/// List of a club event's participants, resolved from `participantIds` via
/// `allUsersProvider` — reached by tapping the "Participants" section on
/// the event detail screen.
class EventParticipantsScreen extends ConsumerStatefulWidget {
  final List<String> participantIds;
  final String eventTitle;

  const EventParticipantsScreen({
    super.key,
    required this.participantIds,
    required this.eventTitle,
  });

  @override
  ConsumerState<EventParticipantsScreen> createState() =>
      _EventParticipantsScreenState();
}

class _EventParticipantsScreenState
    extends ConsumerState<EventParticipantsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allUsers = ref.watch(allUsersProvider).valueOrNull ?? const [];
    final participants =
        allUsers.where((u) => widget.participantIds.contains(u.id)).toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    final query = _query.toLowerCase().trim();
    final filtered = query.isEmpty
        ? participants
        : participants
              .where((u) => u.name.toLowerCase().contains(query))
              .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Participants', style: AppTypography.headlineSmall),
            Text(widget.eventTitle, style: AppTypography.bodySmall),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: TextField(
              controller: _searchController,
              onChanged: (q) => setState(() => _query = q),
              style: AppTypography.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Rechercher un participant...',
                hintStyle: AppTypography.bodySmall,
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.textSecondary,
                ),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: participants.isEmpty
                ? Center(
                    child: Text(
                      'Aucun participant pour le moment.',
                      style: AppTypography.bodySmall,
                    ),
                  )
                : filtered.isEmpty
                ? Center(
                    child: Text(
                      'Aucun résultat pour "$_query".',
                      style: AppTypography.bodySmall,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _ParticipantTile(user: filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  final UserModel user;

  const _ParticipantTile({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          AppAvatar(
            initials: user.initials,
            imageUrl: user.profileImageUrl,
            size: 40,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: AppTypography.headlineSmall),
                if (user.location.isNotEmpty)
                  Text(user.location, style: AppTypography.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
