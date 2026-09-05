import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/models/models.dart';
import '../../molecules/molecules.dart';
import '../community/community_view_model.dart';

class AnnouncementDetailScreen extends ConsumerWidget {
  final AnnouncementModel announcement;
  final String currentUserId;
  final String? userImageUrl;
  final VoidCallback? onInterested;
  final VoidCallback? onUserTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const AnnouncementDetailScreen({
    super.key,
    required this.announcement,
    required this.currentUserId,
    this.userImageUrl,
    this.onInterested,
    this.onUserTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The card passes in a snapshot at push-time; re-read the live copy so
    // the "Intéressé" button reflects the toggle immediately instead of
    // only after popping back to the list.
    final live =
        ref
            .watch(communityViewModelProvider)
            .announcements
            .where((a) => a.id == announcement.id)
            .firstOrNull ??
        announcement;
    final isOwn = live.userId == currentUserId;
    final isInterested = live.interestedUserIds.contains(currentUserId);
    final dateStr = DateFormat('EEEE d MMMM', 'fr_FR').format(live.date);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: const Text('Annonce'),
        leading: GestureDetector(
          onTap: () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AnnouncementHeader(
            announcement: live,
            isOwn: isOwn,
            userImageUrl: userImageUrl,
            onUserTap: isOwn ? null : onUserTap,
            // Modifier/Supprimer act on this announcement — leave the
            // detail page before running them, same as "back".
            onEdit: () {
              Navigator.of(context, rootNavigator: true).pop();
              onEdit?.call();
            },
            onDelete: () {
              Navigator.of(context, rootNavigator: true).pop();
              onDelete?.call();
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            live.message,
            style: AppTypography.bodyMedium.copyWith(height: 1.5),
          ),
          const SizedBox(height: AppSpacing.lg),
          AnnouncementTags(announcement: live, dateStr: dateStr),
          if (!isOwn) ...[
            const SizedBox(height: AppSpacing.xl),
            AnnouncementFooter(
              announcement: live,
              isInterested: isInterested,
              onInterested: onInterested,
            ),
          ],
        ],
      ),
    );
  }
}
