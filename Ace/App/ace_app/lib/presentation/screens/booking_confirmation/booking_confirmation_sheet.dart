import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/models/models.dart';
import '../../../data/providers/favorites_provider.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../atoms/atoms.dart';
import '../auth/auth_view_model.dart';
import '../profile/profile_view_model.dart';
import '../user_profile/user_profile_screen.dart';

/// Bottom sheet (70% of the screen) used to confirm a booking — same content
/// as the old full-page confirmation flow, minus the court hero image.
class BookingConfirmationSheet extends ConsumerStatefulWidget {
  final CourtModel court;
  final String selectedSlot;
  final DateTime date;

  const BookingConfirmationSheet({
    super.key,
    required this.court,
    required this.selectedSlot,
    required this.date,
  });

  static Future<void> show(
    BuildContext context, {
    required CourtModel court,
    required String selectedSlot,
    required DateTime date,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (sheetContext) {
        // Grow the sheet while the keyboard is up, and lift it clear of the
        // keyboard, so fields further down (the partner search bar) and the
        // confirm button aren't hidden behind it.
        final keyboardHeight = MediaQuery.of(sheetContext).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: keyboardHeight),
          child: FractionallySizedBox(
            heightFactor: keyboardHeight > 0 ? 0.85 : 0.7,
            child: BookingConfirmationSheet(
              court: court,
              selectedSlot: selectedSlot,
              date: date,
            ),
          ),
        );
      },
    );
  }

  @override
  ConsumerState<BookingConfirmationSheet> createState() =>
      _BookingConfirmationSheetState();
}

class _BookingConfirmationSheetState
    extends ConsumerState<BookingConfirmationSheet> {
  UserModel? _selectedPartner;
  String _searchQuery = '';
  bool _isLoading = false;
  // Shown in place of the confirm button rather than as a SnackBar, so it
  // stays visible until the player actually does something about it.
  String? _errorMessage;
  final _searchController = TextEditingController();

  String get _endTime {
    final parts = widget.selectedSlot.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final totalMinutes = hour * 60 + minute + 60;
    final endHour = totalMinutes ~/ 60;
    final endMin = totalMinutes % 60;
    return '${endHour.toString().padLeft(2, '0')}:${endMin.toString().padLeft(2, '0')}';
  }

  double get _price => widget.court.pricePerHour;

  List<UserModel> get _filteredPartners {
    final query = _searchQuery.toLowerCase().trim();
    final currentUserId = ref.watch(currentUserProvider).valueOrNull?.id;
    final courtClubId = widget.court.clubId;
    return (ref.watch(allUsersProvider).valueOrNull ?? const [])
        .where((u) => u.id != currentUserId)
        // A partner must belong to the same club as the court being
        // booked — courts without a club (legacy/unset) skip this check.
        .where((u) => courtClubId.isEmpty || u.clubIds.contains(courtClubId))
        .where(
          (u) =>
              query.isEmpty ||
              u.name.toLowerCase().contains(query) ||
              u.location.toLowerCase().contains(query) ||
              u.ranking.toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(favoritesProvider);
    // Collapse the summary card and intro text while the keyboard is up —
    // otherwise there's barely any room left to show search results.
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.xxxl),
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              AppSpacing.lg,
              AppSpacing.xxl,
              0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Réservation', style: AppTypography.headlineLarge),
                GestureDetector(
                  onTap: () => Navigator.of(context, rootNavigator: true).pop(),
                  child: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Fixed header (never scrolls away) — keeps the search bar in
          // view and above the keyboard, instead of it (and the results
          // below it) scrolling out of sight while typing.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              AppSpacing.lg,
              AppSpacing.xxl,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!keyboardOpen) ...[
                  _CourtSummaryCard(
                    court: widget.court,
                    date: widget.date,
                    slot: widget.selectedSlot,
                    endTime: _endTime,
                    price: _price,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                Text(
                  'Inviter un partenaire',
                  style: AppTypography.headlineMedium,
                ),
                if (!keyboardOpen) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Une réservation nécessite deux joueurs.',
                    style: AppTypography.bodySmall,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                _SearchBar(
                  controller: _searchController,
                  onChanged: (q) => setState(() => _searchQuery = q),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.md,
                AppSpacing.xxl,
                AppSpacing.xxl,
              ),
              children: _filteredPartners
                  .map(
                    (user) => _PartnerTile(
                      user: user,
                      isSelected: _selectedPartner?.id == user.id,
                      isFavorite: favorites.contains(user.id),
                      onSelect: () => setState(() {
                        _selectedPartner = _selectedPartner?.id == user.id
                            ? null
                            : user;
                        _errorMessage = null;
                      }),
                      onViewProfile: () =>
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              builder: (_) => UserProfileScreen(user: user),
                            ),
                          ),
                    ),
                  )
                  .toList(),
            ),
          ),
          _BottomBar(
            selectedPartner: _selectedPartner,
            price: _price,
            isLoading: _isLoading,
            errorMessage: _errorMessage,
            onConfirm: _confirm,
            onDismissError: () => setState(() => _errorMessage = null),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm() async {
    if (_selectedPartner == null) return;
    final currentUserId = ref.read(currentUserProvider).valueOrNull?.id;
    if (currentUserId == null) return;
    setState(() => _isLoading = true);

    final booking = BookingModel(
      id: '',
      courtId: widget.court.id,
      courtName: widget.court.name,
      userId: currentUserId,
      partnerId: _selectedPartner!.id,
      partnerName:
          '${_selectedPartner!.name.split(' ').first} ${_selectedPartner!.name.split(' ').last[0]}.',
      date: widget.date,
      startTime: widget.selectedSlot,
      endTime: _endTime,
      courtAddress: widget.court.location,
      status: BookingStatus.confirmed,
      price: _price,
      createdAt: DateTime.now(),
    );

    try {
      await ref.read(profileViewModelProvider.notifier).addBooking(booking);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Réservation confirmée à ${widget.selectedSlot} sur ${widget.court.name} !',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            e is SlotAlreadyBookedException ||
                e is ClubMismatchException ||
                e is CourtClosedException ||
                e is SlotOutsideHoursException ||
                e is PeakHourLimitExceededException ||
                e is OffPeakHourLimitExceededException
            ? e.toString()
            : 'Une erreur est survenue, réessaie.';
      });
    }
  }
}

class _CourtSummaryCard extends StatelessWidget {
  final CourtModel court;
  final DateTime date;
  final String slot;
  final String endTime;
  final double price;

  const _CourtSummaryCard({
    required this.court,
    required this.date,
    required this.slot,
    required this.endTime,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Column(
        children: [
          _Row(icon: Icons.sports_tennis_rounded, label: court.name),
          const SizedBox(height: AppSpacing.sm),
          _Row(icon: Icons.location_on_rounded, label: court.location),
          const SizedBox(height: AppSpacing.sm),
          _Row(
            icon: Icons.grid_on_rounded,
            label: '${court.surface.label} · ${court.type.label}',
          ),
          const SizedBox(height: AppSpacing.sm),
          _Row(
            icon: Icons.calendar_today_rounded,
            label:
                '${date.day.toString().padLeft(2, '0')}/'
                '${date.month.toString().padLeft(2, '0')}/'
                '${date.year} · $slot – $endTime (1h)',
          ),
          if (price > 0) ...[
            const Divider(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total', style: AppTypography.headlineSmall),
                Text(
                  '${price.toInt()}€',
                  style: AppTypography.headlineLarge.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Row({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(label, style: AppTypography.bodyMedium)),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Rechercher un joueur…',
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textTertiary,
        ),
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
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _PartnerTile extends StatelessWidget {
  final UserModel user;
  final bool isSelected;
  final bool isFavorite;
  final VoidCallback onSelect;
  final VoidCallback onViewProfile;

  const _PartnerTile({
    required this.user,
    required this.isSelected,
    required this.isFavorite,
    required this.onSelect,
    required this.onViewProfile,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryContainer : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                AppAvatar(
                  initials: user.initials,
                  imageUrl: user.profileImageUrl,
                  size: 48,
                  backgroundColor: isSelected
                      ? AppColors.primary
                      : AppColors.surfaceVariant,
                  textColor: isSelected ? Colors.white : AppColors.textPrimary,
                ),
                if (isFavorite)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        size: 10,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(user.name, style: AppTypography.headlineSmall),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusFull,
                          ),
                        ),
                        child: Text(
                          user.ranking,
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${user.location} · ${user.stats.matchesPlayed} matchs',
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onViewProfile,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Icon(
                  Icons.person_outline_rounded,
                  size: 20,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final UserModel? selectedPartner;
  final double price;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onConfirm;
  final VoidCallback onDismissError;

  const _BottomBar({
    required this.selectedPartner,
    required this.price,
    required this.isLoading,
    required this.errorMessage,
    required this.onConfirm,
    required this.onDismissError,
  });

  @override
  Widget build(BuildContext context) {
    final confirmLabel = price > 0
        ? 'Confirmer — ${price.toInt()}€'
        : 'Confirmer';
    final error = errorMessage;
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
      child: error != null
          ? _ErrorBanner(message: error, onDismiss: onDismissError)
          : AppButton(
              label: selectedPartner == null
                  ? 'Sélectionner un partenaire'
                  : confirmLabel,
              onTap: selectedPartner == null || isLoading ? null : onConfirm,
              isLoading: isLoading,
            ),
    );
  }
}

/// Takes the confirm button's exact place when a booking attempt fails, so
/// the reason stays visible instead of flashing by as a SnackBar. Tapping
/// it dismisses it and brings the button back (e.g. to try a different
/// partner or slot).
class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 18,
              color: AppColors.error,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: AppTypography.bodySmall.copyWith(color: AppColors.error),
              ),
            ),
            const Icon(Icons.close_rounded, size: 16, color: AppColors.error),
          ],
        ),
      ),
    );
  }
}
