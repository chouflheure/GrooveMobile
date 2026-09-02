import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/models/models.dart';
import '../../atoms/atoms.dart';
import '../../molecules/molecules.dart';
import 'admin_view_model.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminViewModelProvider);
    final vm = ref.read(adminViewModelProvider.notifier);

    if (state.successMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.successMessage!),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        vm.clearSuccess();
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('Administration', style: AppTypography.headlineLarge),
          ],
        ),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatsRow(bookings: state.allBookings, courts: state.courts),
                  const SizedBox(height: AppSpacing.xxl),
                  _CreateBookingSection(
                    state: state,
                    vm: vm,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  _AllBookingsSection(bookings: state.allBookings),
                ],
              ),
            ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final List<BookingModel> bookings;
  final List<CourtModel> courts;

  const _StatsRow({required this.bookings, required this.courts});

  @override
  Widget build(BuildContext context) {
    final confirmed = bookings.where((b) => b.status == BookingStatus.confirmed).length;
    return Row(
      children: [
        Expanded(child: StatCard(emoji: '🏟', value: '${courts.length}', label: 'Terrains')),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: StatCard(emoji: '📅', value: '${bookings.length}', label: 'Réservations')),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: StatCard(emoji: '✅', value: '$confirmed', label: 'Confirmées')),
      ],
    );
  }
}

class _CreateBookingSection extends StatelessWidget {
  final AdminState state;
  final AdminViewModel vm;

  const _CreateBookingSection({required this.state, required this.vm});

  @override
  Widget build(BuildContext context) {
    final form = state.form;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.add_circle_rounded, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text('Créer une réservation admin', style: AppTypography.headlineSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Terrain', style: AppTypography.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            value: form.courtId,
            hint: Text('Sélectionner un terrain', style: AppTypography.bodySmall),
            decoration: _dropdownDecoration(),
            items: state.courts
                .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, style: AppTypography.bodyMedium)))
                .toList(),
            onChanged: (id) { if (id != null) vm.setFormCourt(id); },
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Date', style: AppTypography.labelLarge),
                    const SizedBox(height: AppSpacing.sm),
                    _DateField(
                      date: form.date,
                      onSelect: vm.setFormDate,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Heure de début', style: AppTypography.labelLarge),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<String>(
                      value: form.startTime,
                      hint: Text('--:--', style: AppTypography.bodySmall),
                      decoration: _dropdownDecoration(),
                      items: AppConstants.timeSlots
                          .map((t) => DropdownMenuItem(value: t, child: Text(t, style: AppTypography.bodySmall)))
                          .toList(),
                      onChanged: (t) { if (t != null) vm.setFormTime(t); },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Durée', style: AppTypography.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          _DurationSelector(
            selected: form.durationHours,
            onSelect: vm.setFormDuration,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Inviter des joueurs', style: AppTypography.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Minimum 1 joueur requis pour créer une réservation.',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          _UserSelector(
            users: state.users,
            selectedIds: form.invitedUserIds,
            onToggle: vm.toggleInvitedUser,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: form.isValid
                ? 'Créer ${form.invitedUserIds.length} réservation(s)'
                : 'Remplir tous les champs',
            onTap: form.isValid ? vm.createBooking : null,
            isLoading: state.isLoading,
          ),
        ],
      ),
    );
  }

  InputDecoration _dropdownDecoration() => InputDecoration(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    filled: true,
    fillColor: AppColors.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
  );
}

class _DateField extends StatelessWidget {
  final DateTime? date;
  final ValueChanged<DateTime> onSelect;

  const _DateField({required this.date, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now().add(const Duration(days: 1)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 90)),
        );
        if (picked != null) onSelect(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
            const SizedBox(width: AppSpacing.xs),
            Text(
              date != null
                  ? '${date!.day.toString().padLeft(2, '0')}/${date!.month.toString().padLeft(2, '0')}/${date!.year}'
                  : 'Choisir',
              style: AppTypography.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _DurationSelector extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;

  const _DurationSelector({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [1, 2, 3, 4].map((h) {
        final isSelected = selected == h;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(h),
            child: Container(
              margin: EdgeInsets.only(right: h < 4 ? AppSpacing.sm : 0),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.background,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
              ),
              child: Text(
                '${h}h',
                textAlign: TextAlign.center,
                style: AppTypography.labelMedium.copyWith(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _UserSelector extends StatelessWidget {
  final List<UserModel> users;
  final List<String> selectedIds;
  final ValueChanged<String> onToggle;

  const _UserSelector({required this.users, required this.selectedIds, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: users.map((u) {
        final isSelected = selectedIds.contains(u.id);
        return GestureDetector(
          onTap: () => onToggle(u.id),
          child: Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryContainer : AppColors.background,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                AppAvatar(
                  initials: u.initials,
                  size: 36,
                  backgroundColor: isSelected ? AppColors.primary.withValues(alpha: 0.2) : AppColors.surfaceVariant,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.name, style: AppTypography.headlineSmall),
                      Text('${u.ranking} · ${u.location}', style: AppTypography.bodySmall),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _AllBookingsSection extends StatelessWidget {
  final List<BookingModel> bookings;

  const _AllBookingsSection({required this.bookings});

  @override
  Widget build(BuildContext context) {
    final sorted = [...bookings]..sort((a, b) => b.date.compareTo(a.date));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Toutes les réservations', style: AppTypography.headlineSmall),
            Text('${bookings.length} total', style: AppTypography.labelMedium.copyWith(color: AppColors.primary)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ...sorted.map(
          (b) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: BookingHistoryItem(booking: b),
          ),
        ),
      ],
    );
  }
}
