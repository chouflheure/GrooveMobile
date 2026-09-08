import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/models/models.dart';
import '../../atoms/atoms.dart';
import '../booking_detail/booking_detail_screen.dart';
import 'manager_view_model.dart';

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Read-only "all courts × all hours" grid for a single day — lets an admin
/// see every terrain's occupancy at a glance instead of opening them one by
/// one. Pure client-side aggregation of `ManagerViewModel`'s already-loaded
/// `courts`/`allBookings` (no new Firestore query).
class AdminScheduleScreen extends ConsumerStatefulWidget {
  const AdminScheduleScreen({super.key});

  @override
  ConsumerState<AdminScheduleScreen> createState() =>
      _AdminScheduleScreenState();
}

class _AdminScheduleScreenState extends ConsumerState<AdminScheduleScreen> {
  late DateTime _selectedDate = AppConstants.today();

  static const double _nameColumnWidth = 110;
  static const double _hourColumnWidth = 64;
  static const double _rowHeight = 56;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(
      () => _selectedDate = DateTime(picked.year, picked.month, picked.day),
    );
  }

  String? _playerName(ManagerState state, String? userId) {
    if (userId == null || userId.isEmpty) return null;
    return state.players.where((u) => u.id == userId).firstOrNull?.name;
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  void _showBookingSheet(ManagerState state, BookingModel booking) {
    final bookerName = _playerName(state, booking.userId) ?? 'Joueur';
    final partnerName = booking.partnerId != null
        ? (_playerName(state, booking.partnerId) ?? booking.partnerName)
        : null;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg + MediaQuery.paddingOf(sheetContext).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(booking.courtName, style: AppTypography.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${_fmt(booking.date)} · ${booking.startTime}-${booking.endTime}',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              partnerName != null ? '$bookerName vs $partnerName' : bookerName,
              style: AppTypography.bodyMedium,
            ),
            if (booking.hasExternalPlayer) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Joueur extérieur au club',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Voir le détail',
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (_) => BookingDetailScreen(booking: booking),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(managerViewModelProvider);

    final bookingsByCourtAndSlot = <String, Map<String, BookingModel>>{};
    for (final b in state.allBookings) {
      if (b.status == BookingStatus.cancelled) continue;
      if (b.isEventBlock) continue;
      if (!_isSameDay(b.date, _selectedDate)) continue;
      bookingsByCourtAndSlot.putIfAbsent(b.courtId, () => {})[b.startTime] = b;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: const Text('Planning'),
        leading: GestureDetector(
          onTap: () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          IconButton(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: _DayStrip(
              selectedDate: _selectedDate,
              onSelect: (d) => setState(() => _selectedDate = d),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: state.courts.isEmpty
                ? Center(
                    child: Text(
                      'Aucun terrain pour le moment.',
                      style: AppTypography.bodyMedium,
                    ),
                  )
                : SingleChildScrollView(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            const SizedBox(
                              height: _rowHeight,
                              width: _nameColumnWidth,
                            ),
                            ...state.courts.map(
                              (c) => Container(
                                height: _rowHeight,
                                width: _nameColumnWidth,
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                ),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    right: BorderSide(color: AppColors.border),
                                    bottom: BorderSide(color: AppColors.border),
                                  ),
                                ),
                                child: Text(
                                  c.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.labelMedium,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Column(
                              children: [
                                Row(
                                  children: AppConstants.timeSlots
                                      .map(
                                        (t) => Container(
                                          width: _hourColumnWidth,
                                          height: _rowHeight,
                                          alignment: Alignment.center,
                                          decoration: const BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(
                                                color: AppColors.border,
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            t,
                                            style: AppTypography.labelSmall,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                                ...state.courts.map(
                                  (court) => Row(
                                    children: AppConstants.timeSlots.map((t) {
                                      final booking =
                                          bookingsByCourtAndSlot[court.id]?[t];
                                      final offered = court.availableSlots.any(
                                        (s) => s.time == t,
                                      );
                                      final closed = court.isClosedOn(
                                        _selectedDate,
                                      );
                                      return _ScheduleCell(
                                        width: _hourColumnWidth,
                                        height: _rowHeight,
                                        offered: offered && !closed,
                                        booking: booking,
                                        label: booking != null
                                            ? (_playerName(
                                                    state,
                                                    booking.userId,
                                                  ) ??
                                                  'Réservé')
                                            : null,
                                        onTap: booking != null
                                            ? () => _showBookingSheet(
                                                state,
                                                booking,
                                              )
                                            : null,
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleCell extends StatelessWidget {
  final double width;
  final double height;
  final bool offered;
  final BookingModel? booking;
  final String? label;
  final VoidCallback? onTap;

  const _ScheduleCell({
    required this.width,
    required this.height,
    required this.offered,
    required this.booking,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color background;
    if (!offered) {
      background = AppColors.surfaceVariant;
    } else if (booking != null) {
      background = AppColors.error.withValues(alpha: 0.15);
    } else {
      background = AppColors.primaryContainer;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: background,
          border: const Border(
            right: BorderSide(color: AppColors.border),
            bottom: BorderSide(color: AppColors.border),
          ),
        ),
        child: label != null
            ? Text(
                label!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
      ),
    );
  }
}

class _DayStrip extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelect;

  const _DayStrip({required this.selectedDate, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final today = AppConstants.today();
    final days = List.generate(14, (i) => today.add(Duration(days: i - 3)));
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) {
          final day = days[i];
          final isSelected = _isSameDay(day, selectedDate);
          return GestureDetector(
            onTap: () => onSelect(day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 52,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _weekdayLabel(day.weekday),
                    style: AppTypography.labelSmall.copyWith(
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '${day.day}',
                    style: AppTypography.labelLarge.copyWith(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _weekdayLabel(int weekday) => const [
    'lun.',
    'mar.',
    'mer.',
    'jeu.',
    'ven.',
    'sam.',
    'dim.',
  ][weekday - 1];
}
