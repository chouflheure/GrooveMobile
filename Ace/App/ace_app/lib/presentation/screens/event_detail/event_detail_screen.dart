import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/models/models.dart';
import '../auth/auth_view_model.dart';
import '../courts/club_event_providers.dart';
import 'event_participants_screen.dart';

class EventDetailScreen extends ConsumerWidget {
  final ClubEventModel event;

  const EventDetailScreen({super.key, required this.event});

  void _share(ClubEventModel current) {
    final dateStr = DateFormat('EEEE d MMMM', 'fr_FR').format(current.date);
    final lines = [
      current.title,
      if (current.description.isNotEmpty) current.description,
      '$dateStr · ${current.clubName}',
      if (current.address.isNotEmpty) current.address,
    ];
    SharePlus.instance.share(ShareParams(text: lines.join('\n')));
  }

  DateTime _timeOn(DateTime date, String hhmm) {
    final parts = hhmm.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  void _addToCalendar(ClubEventModel current) {
    final hasTime = current.startTime.isNotEmpty;
    final start = hasTime
        ? _timeOn(current.date, current.startTime)
        : current.date;
    final end = hasTime && current.endTime.isNotEmpty
        ? _timeOn(current.date, current.endTime)
        : start.add(const Duration(hours: 1));
    Add2Calendar.addEvent2Cal(
      Event(
        title: current.title,
        description: current.description,
        location: current.address,
        startDate: start,
        endDate: end,
        allDay: !hasTime,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Falls back to the snapshot passed at navigation time until the live
    // data has loaded, then tracks Firestore so participation stays current.
    final live = ref
        .watch(clubEventsProvider)
        .valueOrNull
        ?.where((e) => e.id == event.id)
        .firstOrNull;
    final current = live ?? event;
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final isParticipating =
        currentUser != null && current.participantIds.contains(currentUser.id);
    final dateStr = DateFormat(
      'EEEE d MMMM yyyy',
      'fr_FR',
    ).format(current.date);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(current.clubName, style: AppTypography.headlineSmall),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            onPressed: () => _addToCalendar(current),
          ),
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => _share(current),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(current.title, style: AppTypography.displayMedium),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(
                  Icons.event_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${dateStr[0].toUpperCase()}${dateStr.substring(1)}',
                  style: AppTypography.bodyMedium,
                ),
              ],
            ),
            if (current.startTime.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    current.endTime.isNotEmpty
                        ? '${current.startTime} - ${current.endTime}'
                        : current.startTime,
                    style: AppTypography.bodyMedium,
                  ),
                ],
              ),
            ],
            if (current.description.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxl),
              _Section(
                title: 'Description',
                child: Text(
                  current.description,
                  style: AppTypography.bodyMedium.copyWith(height: 1.6),
                ),
              ),
            ],
            if (current.courtNames.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxl),
              _Section(
                title: 'Terrains',
                child: Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: current.courtNames
                      .map(
                        (name) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusFull,
                            ),
                          ),
                          child: Text(
                            name,
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
            if (current.address.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxl),
              _Section(
                title: 'Adresse',
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        current.address,
                        style: AppTypography.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            _Section(
              title: 'Participants',
              child: GestureDetector(
                onTap: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (_) => EventParticipantsScreen(
                      participantIds: current.participantIds,
                      eventTitle: current.title,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.group_outlined,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${current.participantIds.length} participant${current.participantIds.length >= 2 ? 's' : ''}',
                      style: AppTypography.bodyMedium,
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
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
                  .read(clubEventRepositoryProvider)
                  .setParticipating(
                    current.id,
                    currentUser.id,
                    !isParticipating,
                  );
            },
            child: Text(
              isParticipating ? 'Inscrit ✓' : 'Participer',
              style: AppTypography.labelLarge.copyWith(
                color: isParticipating ? AppColors.primary : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}
