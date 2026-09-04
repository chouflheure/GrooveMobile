import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/booking_grouping.dart';
import '../../../data/models/models.dart';
import '../../molecules/molecules.dart';
import '../booking_detail/booking_detail_screen.dart';
import '../event_detail/event_detail_screen.dart';

class AllBookingsScreen extends StatelessWidget {
  final List<BookingModel> bookings;
  final List<ClubEventModel> events;

  const AllBookingsScreen({
    super.key,
    required this.bookings,
    this.events = const [],
  });

  @override
  Widget build(BuildContext context) {
    final entries =
        [
          ...groupConsecutiveBookings(bookings).map(
            (g) => ProfileEntry(
              date: g.first.date,
              startTime: g.first.startTime,
              child: BookingHistoryItem(
                group: g,
                titleColor: AppColors.primary,
                onTap: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (_) => BookingDetailScreen(booking: g.first),
                  ),
                ),
              ),
            ),
          ),
          ...events.map(
            (e) => ProfileEntry(
              date: e.date,
              startTime: e.startTime,
              child: EventReservationItem(
                event: e,
                titleColor: AppColors.primary,
                onTap: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (_) => EventDetailScreen(event: e),
                  ),
                ),
              ),
            ),
          ),
        ]..sort((a, b) {
          final cmp = b.date.compareTo(a.date);
          return cmp != 0 ? cmp : b.startTime.compareTo(a.startTime);
        });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: Text(
          'Historique des matchs',
          style: AppTypography.headlineLarge,
        ),
        leading: GestureDetector(
          onTap: () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: entries.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.history_rounded,
                    size: 64,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Aucun match joué', style: AppTypography.headlineMedium),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) => entries[i].child,
            ),
    );
  }
}
