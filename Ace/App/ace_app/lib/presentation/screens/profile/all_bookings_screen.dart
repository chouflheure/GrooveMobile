import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/booking_grouping.dart';
import '../../../data/models/models.dart';
import '../../molecules/molecules.dart';
import '../booking_detail/booking_detail_screen.dart';

class AllBookingsScreen extends StatelessWidget {
  final List<BookingModel> bookings;

  const AllBookingsScreen({super.key, required this.bookings});

  @override
  Widget build(BuildContext context) {
    final groups = groupConsecutiveBookings(bookings);
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
      body: groups.isEmpty
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
              itemCount: groups.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) => BookingHistoryItem(
                group: groups[i],
                titleColor: AppColors.primary,
                onTap: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        BookingDetailScreen(booking: groups[i].first),
                  ),
                ),
              ),
            ),
    );
  }
}
