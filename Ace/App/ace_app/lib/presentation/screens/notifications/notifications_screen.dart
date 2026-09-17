import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/notifications/notification_navigation.dart';
import '../../../data/models/models.dart';
import '../courts/courts_view_model.dart';

/// The "bell" notification center — every club event/tournament/booking
/// notification the user has received (messages and broadcasts live in
/// their own tabs instead, see `CommunityScreen`). Opening this screen
/// marks everything currently unseen as seen (clears the bell's badge);
/// an individual item stays highlighted until it's actually tapped.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  // Re-runs (harmlessly — it only touches whatever's still unseen) every
  // time the list changes while this screen stays open, so a notification
  // that arrives while it's already open gets cleared too, not just
  // whatever existed at the moment it was first opened.
  void _markUnseenAsSeen(List<AppNotificationModel> notifications) {
    final unseenIds = notifications
        .where((n) => !n.seen)
        .map((n) => n.id)
        .toList();
    if (unseenIds.isEmpty) return;
    ref.read(notificationRepositoryProvider).markAllSeen(unseenIds);
  }

  Future<void> _openNotification(AppNotificationModel notification) async {
    if (!notification.clicked) {
      ref.read(notificationRepositoryProvider).markClicked(notification.id);
    }
    await handleNotificationTap(ref, notification.data);
  }

  void _deleteNotification(String id) {
    ref.read(notificationRepositoryProvider).delete(id);
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'club_event':
        return Icons.event_rounded;
      case 'tournament':
        return Icons.emoji_events_rounded;
      case 'booking_created':
        return Icons.event_available_rounded;
      case 'booking_cancelled':
        return Icons.event_busy_rounded;
      case 'booking_reminder':
        return Icons.access_time_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    // `ref.listen` only reacts to *future* changes — if the provider
    // already had data before this screen opened (very likely, since the
    // bell badge elsewhere already keeps it alive), that existing value
    // needs handling too, hence the direct call right below as well.
    ref.listen<AsyncValue<List<AppNotificationModel>>>(
      appNotificationsProvider,
      (previous, next) => next.whenData(_markUnseenAsSeen),
    );
    final notifications =
        ref.watch(appNotificationsProvider).valueOrNull ?? const [];
    _markUnseenAsSeen(notifications);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: const Text('Notifications'),
        leading: GestureDetector(
          onTap: () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: notifications.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Text(
                  'Aucune notification pour le moment.',
                  style: AppTypography.bodySmall,
                ),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
              ),
              itemCount: notifications.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) {
                final notification = notifications[i];
                final isUnclicked = !notification.clicked;
                return Dismissible(
                  key: ValueKey(notification.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    ),
                    child: const Icon(
                      Icons.delete_rounded,
                      color: Colors.white,
                    ),
                  ),
                  onDismissed: (_) => _deleteNotification(notification.id),
                  child: GestureDetector(
                    onTap: () => _openNotification(notification),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: isUnclicked
                            ? AppColors.primaryContainer
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusLg,
                        ),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusMd,
                              ),
                            ),
                            child: Icon(
                              _iconFor(notification.type),
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notification.title,
                                  style: AppTypography.headlineSmall.copyWith(
                                    fontWeight: isUnclicked
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  notification.body,
                                  style: AppTypography.bodySmall,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  notification.timeAgo,
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isUnclicked)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 4),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
