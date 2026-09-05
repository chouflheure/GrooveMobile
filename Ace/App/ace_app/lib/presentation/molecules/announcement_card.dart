import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../data/models/models.dart';
import '../atoms/atoms.dart';
import '../screens/announcement_detail/announcement_detail_screen.dart';

class AnnouncementCard extends StatelessWidget {
  final AnnouncementModel announcement;
  final String currentUserId;
  // Resolved live from the poster's current profile (falls back to
  // `announcement.userImageUrl` when not given) so a photo added or
  // changed after the announcement was posted still shows up, and old
  // announcements posted before this field existed aren't stuck without one.
  final String? userImageUrl;
  final VoidCallback? onInterested;
  final VoidCallback? onUserTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const AnnouncementCard({
    super.key,
    required this.announcement,
    required this.currentUserId,
    this.userImageUrl,
    this.onInterested,
    this.onUserTap,
    this.onEdit,
    this.onDelete,
  });

  bool get _isOwn => announcement.userId == currentUserId;

  void _showDetail(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => AnnouncementDetailScreen(
          announcement: announcement,
          currentUserId: currentUserId,
          userImageUrl: userImageUrl,
          onInterested: onInterested,
          onUserTap: onUserTap,
          onEdit: onEdit,
          onDelete: onDelete,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isInterested = announcement.interestedUserIds.contains(currentUserId);
    final dateStr = DateFormat(
      'EEEE d MMMM',
      'fr_FR',
    ).format(announcement.date);

    return GestureDetector(
      onTap: () => _showDetail(context),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnnouncementHeader(
              announcement: announcement,
              isOwn: _isOwn,
              userImageUrl: userImageUrl,
              onUserTap: _isOwn ? null : onUserTap,
              onEdit: onEdit,
              onDelete: onDelete,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              announcement.message,
              style: AppTypography.bodyMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.md),
            AnnouncementTags(announcement: announcement, dateStr: dateStr),
            if (!_isOwn) ...[
              const SizedBox(height: AppSpacing.md),
              AnnouncementFooter(
                announcement: announcement,
                isInterested: isInterested,
                onInterested: onInterested,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AnnouncementHeader extends StatelessWidget {
  final AnnouncementModel announcement;
  final bool isOwn;
  final String? userImageUrl;
  final VoidCallback? onUserTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const AnnouncementHeader({
    super.key,
    required this.announcement,
    this.isOwn = false,
    this.userImageUrl,
    this.onUserTap,
    this.onEdit,
    this.onDelete,
  });

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.xxxl),
          ),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + AppSpacing.lg,
          top: AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ListTile(
              leading: const Icon(
                Icons.edit_outlined,
                color: AppColors.textPrimary,
              ),
              title: Text('Modifier', style: AppTypography.bodyMedium),
              onTap: () {
                Navigator.of(context, rootNavigator: true).pop();
                onEdit?.call();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.red,
              ),
              title: Text(
                'Supprimer',
                style: AppTypography.bodyMedium.copyWith(color: Colors.red),
              ),
              onTap: () {
                Navigator.of(context, rootNavigator: true).pop();
                onDelete?.call();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isOwn ? null : onUserTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          AppAvatar(
            initials: announcement.userName
                .split(' ')
                .map((p) => p[0])
                .take(2)
                .join(),
            imageUrl: userImageUrl ?? announcement.userImageUrl,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      announcement.userName,
                      style: AppTypography.headlineSmall,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppBadge.ranking(announcement.userRanking),
                  ],
                ),
                Text(announcement.timeAgo, style: AppTypography.bodySmall),
              ],
            ),
          ),
          if (isOwn)
            GestureDetector(
              onTap: () => _showOptions(context),
              child: const Padding(
                padding: EdgeInsets.all(AppSpacing.xs),
                child: Icon(
                  Icons.more_vert_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else if (onUserTap != null)
            const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: AppColors.textTertiary,
            ),
        ],
      ),
    );
  }
}

class AnnouncementTags extends StatelessWidget {
  final AnnouncementModel announcement;
  final String dateStr;

  const AnnouncementTags({
    super.key,
    required this.announcement,
    required this.dateStr,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _TagChip(
          icon: Icons.calendar_today_rounded,
          label: '${_capitalize(dateStr)} ${announcement.time}',
        ),
        _TagChip(
          icon: Icons.location_on_rounded,
          label: announcement.courtName,
        ),
      ],
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _TagChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TagChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class AnnouncementFooter extends StatelessWidget {
  final AnnouncementModel announcement;
  final bool isInterested;
  final VoidCallback? onInterested;

  const AnnouncementFooter({
    super.key,
    required this.announcement,
    required this.isInterested,
    this.onInterested,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.group_outlined, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          '${announcement.interestedCount} intéressé${announcement.interestedCount > 1 ? 's' : ''}',
          style: AppTypography.bodySmall,
        ),
        const Spacer(),
        GestureDetector(
          onTap: onInterested,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: isInterested
                  ? AppColors.primaryContainer
                  : AppColors.primary,
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            ),
            child: Text(
              isInterested ? 'Intéressé ✓' : 'Je suis dispo !',
              style: AppTypography.labelMedium.copyWith(
                color: isInterested ? AppColors.primary : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
