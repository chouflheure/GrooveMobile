import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/models/models.dart';
import '../../../data/providers/favorites_provider.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../atoms/atoms.dart';
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
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.7,
        child: BookingConfirmationSheet(
          court: court,
          selectedSlot: selectedSlot,
          date: date,
        ),
      ),
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
  final _searchController = TextEditingController();

  String get _endTime {
    final parts = widget.selectedSlot.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final totalMinutes = hour * 60 + minute + 90;
    final endHour = totalMinutes ~/ 60;
    final endMin = totalMinutes % 60;
    return '${endHour.toString().padLeft(2, '0')}:${endMin.toString().padLeft(2, '0')}';
  }

  double get _price => widget.court.pricePerHour * 1.5;

  List<UserModel> get _filteredPartners {
    final query = _searchQuery.toLowerCase().trim();
    return MockData.allUsers
        .where((u) => u.id != MockData.currentUser.id && !u.isAdmin)
        .where((u) =>
            query.isEmpty ||
            u.name.toLowerCase().contains(query) ||
            u.location.toLowerCase().contains(query) ||
            u.ranking.toLowerCase().contains(query))
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

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.xxxl)),
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
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CourtSummaryCard(
                    court: widget.court,
                    date: widget.date,
                    slot: widget.selectedSlot,
                    endTime: _endTime,
                    price: _price,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Text('Inviter un partenaire',
                      style: AppTypography.headlineMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Une réservation nécessite deux joueurs.',
                    style: AppTypography.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SearchBar(
                    controller: _searchController,
                    onChanged: (q) => setState(() => _searchQuery = q),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ..._filteredPartners.map((user) => _PartnerTile(
                        user: user,
                        isSelected: _selectedPartner?.id == user.id,
                        isFavorite: favorites.contains(user.id),
                        onSelect: () => setState(() {
                          _selectedPartner =
                              _selectedPartner?.id == user.id ? null : user;
                        }),
                        onViewProfile: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => UserProfileScreen(user: user)),
                        ),
                      )),
                ],
              ),
            ),
          ),
          _BottomBar(
            selectedPartner: _selectedPartner,
            price: _price,
            isLoading: _isLoading,
            onConfirm: _confirm,
          ),
        ],
      ),
    );
  }

  Future<void> _confirm() async {
    if (_selectedPartner == null) return;
    setState(() => _isLoading = true);

    final booking = BookingModel(
      id: '',
      courtId: widget.court.id,
      courtName: widget.court.name,
      userId: MockData.currentUser.id,
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
      Navigator.of(context).pop();
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
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is SlotAlreadyBookedException
                ? e.toString()
                : 'Une erreur est survenue, réessaie.',
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
          _Row(
            icon: Icons.location_on_rounded,
            label: court.location,
          ),
          const SizedBox(height: AppSpacing.sm),
          _Row(
            icon: Icons.grid_on_rounded,
            label: '${court.surface.label} · ${court.type.label}',
          ),
          const SizedBox(height: AppSpacing.sm),
          _Row(
            icon: Icons.calendar_today_rounded,
            label: '${date.day.toString().padLeft(2, '0')}/'
                '${date.month.toString().padLeft(2, '0')}/'
                '${date.year} · $slot – $endTime (1h30)',
          ),
          if (price > 0) ...[
            const Divider(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total', style: AppTypography.headlineSmall),
                Text(
                  '${price.toInt()}€',
                  style: AppTypography.headlineLarge
                      .copyWith(color: AppColors.primary),
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
        hintStyle: AppTypography.bodyMedium
            .copyWith(color: AppColors.textTertiary),
        prefixIcon:
            const Icon(Icons.search_rounded, color: AppColors.textSecondary),
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
                  size: 48,
                  backgroundColor:
                      isSelected ? AppColors.primary : AppColors.surfaceVariant,
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
                      child: const Icon(Icons.favorite_rounded,
                          size: 10, color: AppColors.primary),
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
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.15),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusFull),
                        ),
                        child: Text(
                          user.ranking,
                          style: AppTypography.labelSmall.copyWith(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w700),
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
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 20),
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
  final VoidCallback onConfirm;

  const _BottomBar({
    required this.selectedPartner,
    required this.price,
    required this.isLoading,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final confirmLabel = price > 0
        ? 'Confirmer — ${price.toInt()}€'
        : 'Confirmer';
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
        label: selectedPartner == null
            ? 'Sélectionner un partenaire'
            : confirmLabel,
        onTap: selectedPartner == null || isLoading ? null : onConfirm,
        isLoading: isLoading,
      ),
    );
  }
}
