import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/models/models.dart';
import '../../atoms/atoms.dart';
import '../../molecules/molecules.dart';
import '../auth/auth_view_model.dart';
import '../booking_confirmation/booking_confirmation_sheet.dart';
import '../courts/courts_view_model.dart';

/// Args passed via `GoRouter`'s `extra` when navigating to `/court/:id`.
class CourtDetailArgs {
  final CourtModel court;
  final String? initialSlot;

  const CourtDetailArgs({required this.court, this.initialSlot});
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

final _bookedSlotsProvider =
    StreamProvider.family<Set<String>, ({String courtId, DateTime date})>(
  (ref, args) => ref
      .watch(bookingRepositoryProvider)
      .watchBookedSlotsForDate(args.date)
      .map((byCourtId) => byCourtId[args.courtId] ?? const <String>{}),
);

class CourtDetailScreen extends ConsumerStatefulWidget {
  final CourtModel court;
  final String? initialSlot;

  const CourtDetailScreen({super.key, required this.court, this.initialSlot});

  @override
  ConsumerState<CourtDetailScreen> createState() => _CourtDetailScreenState();
}

class _CourtDetailScreenState extends ConsumerState<CourtDetailScreen> {
  late DateTime _selectedDate = AppConstants.today();
  late String? _selectedSlot = widget.initialSlot;

  @override
  Widget build(BuildContext context) {
    // Falls back to the snapshot passed at navigation time until the live
    // data has loaded, then tracks Firestore so the template + booked slots
    // for the selected day stay current.
    final template =
        ref.watch(courtByIdProvider(widget.court.id)).valueOrNull ??
            widget.court;
    final booked = ref
            .watch(_bookedSlotsProvider((
              courtId: template.id,
              date: _selectedDate,
            )))
            .valueOrNull ??
        const <String>{};
    final court = _withBookedSlots(template, booked);
    final isAuthenticated = ref.watch(currentUserProvider).valueOrNull != null;
    final clubName = ref
        .watch(clubsProvider)
        .valueOrNull
        ?.where((c) => c.id == court.clubId)
        .firstOrNull
        ?.name;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _SliverHero(court: court),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _QuickInfoRow(court: court),
                  const SizedBox(height: AppSpacing.xxl),
                  _Section(
                    title: 'Description',
                    child: Text(
                      court.description,
                      style: AppTypography.bodyMedium.copyWith(height: 1.6),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  _Section(
                    title: 'Adresse',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (clubName != null && clubName.isNotEmpty) ...[
                          Text(
                            clubName,
                            style: AppTypography.labelMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                        ],
                        _AddressTile(address: court.location),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  _Section(
                    title: 'Équipements',
                    child: _AmenitiesGrid(amenities: court.amenities),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  _Section(
                    title: 'Réserver un créneau',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DateSelector(
                          selectedDate: _selectedDate,
                          onSelect: (date) => setState(() {
                            _selectedDate = date;
                            _selectedSlot = null;
                          }),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _SlotsSection(
                          court: court,
                          selectedSlot: _selectedSlot,
                          onSelect: (slot) =>
                              setState(() => _selectedSlot = slot),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        court: court,
        selectedSlot: _selectedSlot,
        isAuthenticated: isAuthenticated,
        onBook: () => isAuthenticated
            ? _openBooking(context, court)
            : context.go('/login'),
      ),
    );
  }

  CourtModel _withBookedSlots(CourtModel template, Set<String> booked) {
    return CourtModel(
      id: template.id,
      name: template.name,
      type: template.type,
      surface: template.surface,
      location: template.location,
      pricePerHour: template.pricePerHour,
      rating: template.rating,
      imageUrl: template.imageUrl,
      description: template.description,
      amenities: template.amenities,
      availableSlots: template.availableSlots
          .map((s) => booked.contains(s.time) ||
                  AppConstants.isSlotPast(_selectedDate, s.time)
              ? TimeSlot(time: s.time, isAvailable: false)
              : s)
          .toList(),
      clubId: template.clubId,
    );
  }

  void _openBooking(BuildContext context, CourtModel court) {
    if (_selectedSlot == null) return;
    BookingConfirmationSheet.show(
      context,
      court: court,
      selectedSlot: _selectedSlot!,
      date: _selectedDate,
    ).then((_) => setState(() => _selectedSlot = null));
  }
}

class _SliverHero extends StatelessWidget {
  final CourtModel court;

  const _SliverHero({required this.court});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: AppColors.surface,
      leading: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          margin: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              court.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: AppColors.surfaceVariant,
                child: const Icon(
                  Icons.sports_tennis,
                  size: 64,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            Positioned(
              bottom: AppSpacing.lg,
              left: AppSpacing.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    court.name,
                    style: AppTypography.displayMedium.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 14,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        court.location,
                        style: AppTypography.bodySmall.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickInfoRow extends StatelessWidget {
  final CourtModel court;

  const _QuickInfoRow({required this.court});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _InfoChip(
          icon: court.type == CourtType.indoor
              ? Icons.home_rounded
              : Icons.wb_sunny_rounded,
          label: court.type.label,
          color: court.type == CourtType.indoor
              ? AppColors.indoorBadge
              : AppColors.outdoorBadge,
        ),
        const SizedBox(width: AppSpacing.sm),
        _InfoChip(
          icon: Icons.grid_on_rounded,
          label: court.surface.label,
          color: AppColors.primary,
        ),
        const Spacer(),
        if (court.pricePerHour > 0)
          Text(
            '${court.pricePerHour.toInt()}€/h',
            style: AppTypography.headlineLarge.copyWith(color: AppColors.primary),
          ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
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
        Text(title, style: AppTypography.headlineMedium),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    );
  }
}

class _AddressTile extends StatelessWidget {
  final String address;

  const _AddressTile({required this.address});

  bool get _hasAddress => address.trim().isNotEmpty;

  Future<void> _openMaps() async {
    final uri = Uri(
      scheme: 'https',
      host: 'www.google.com',
      path: '/maps/search/',
      queryParameters: {'api': '1', 'query': address},
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _hasAddress ? _openMaps : null,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Icon(
              Icons.location_on_rounded,
              size: 18,
              color: _hasAddress ? AppColors.primary : AppColors.textTertiary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                _hasAddress ? address : 'Pas renseigné',
                style: AppTypography.bodyMedium.copyWith(
                  color: _hasAddress
                      ? AppColors.primary
                      : AppColors.textTertiary,
                  decoration:
                      _hasAddress ? TextDecoration.underline : TextDecoration.none,
                ),
              ),
            ),
            if (_hasAddress)
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textTertiary,
              ),
          ],
        ),
      ),
    );
  }
}

class _AmenitiesGrid extends StatelessWidget {
  final List<String> amenities;

  const _AmenitiesGrid({required this.amenities});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: amenities
          .map(
            (a) => Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                a,
                style: AppTypography.bodySmall.copyWith(color: Colors.black),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _DateSelector extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelect;

  const _DateSelector({required this.selectedDate, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final today = AppConstants.today();
    final days = List.generate(
      AppConstants.bookingCalendarDays,
      (i) => today.add(Duration(days: i)),
    );
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) {
          final day = days[i];
          return _DateChip(
            date: day,
            isSelected: _isSameDay(day, selectedDate),
            onTap: () => onSelect(day),
          );
        },
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final DateTime date;
  final bool isSelected;
  final VoidCallback onTap;

  const _DateChip({
    required this.date,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 52,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('E', 'fr_FR').format(date),
              style: AppTypography.labelSmall.copyWith(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${date.day}',
              style: AppTypography.headlineSmall.copyWith(
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotsSection extends StatelessWidget {
  final CourtModel court;
  final String? selectedSlot;
  final ValueChanged<String?> onSelect;

  const _SlotsSection({
    required this.court,
    required this.selectedSlot,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final freeSlots = court.freeSlots;
    if (freeSlots.isEmpty) {
      return Text(
        'Aucun créneau disponible.',
        style: AppTypography.bodySmall,
      );
    }
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: freeSlots
          .map(
            (slot) => TimeSlotChip(
              slot: slot,
              isSelected: selectedSlot == slot.time,
              onTap: () =>
                  onSelect(selectedSlot == slot.time ? null : slot.time),
            ),
          )
          .toList(),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final CourtModel court;
  final String? selectedSlot;
  final bool isAuthenticated;
  final VoidCallback onBook;

  const _BottomBar({
    required this.court,
    required this.selectedSlot,
    required this.isAuthenticated,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    final label = !isAuthenticated
        ? 'Se connecter pour réserver'
        : switch ((selectedSlot, court.pricePerHour > 0)) {
            (null, _) => 'Sélectionner un créneau',
            (final slot?, true) =>
              'Réserver à $slot — ${(court.pricePerHour * 1.5).toInt()}€',
            (final slot?, false) => 'Réserver à $slot',
          };
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.md,
        AppSpacing.xxl,
        AppSpacing.md + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: AppButton(
        label: label,
        onTap: (isAuthenticated && selectedSlot == null) ? null : onBook,
      ),
    );
  }
}
