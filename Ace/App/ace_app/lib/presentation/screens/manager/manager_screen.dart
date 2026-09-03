import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/models/models.dart';
import '../../atoms/atoms.dart';
import '../../molecules/molecules.dart';
import '../courts/courts_view_model.dart';
import 'court_form_screen.dart';
import 'manager_view_model.dart';

class ManagerScreen extends ConsumerWidget {
  const ManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(managerViewModelProvider);
    final vm = ref.read(managerViewModelProvider.notifier);

    if (state.message != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.message!),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        vm.clearMessage();
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: const Text('Manager'),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MatchOrganizerSection(state: state, vm: vm),
                  const SizedBox(height: AppSpacing.xxl),
                  _CourtsManagementSection(state: state),
                  const SizedBox(height: AppSpacing.xxl),
                  _ActiveBookingsSection(state: state, vm: vm),
                  const SizedBox(height: AppSpacing.xxl),
                  _AdminsSection(admins: state.admins),
                ],
              ),
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SectionCard({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
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
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(title, style: AppTypography.headlineSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class _MatchOrganizerSection extends StatefulWidget {
  final ManagerState state;
  final ManagerViewModel vm;

  const _MatchOrganizerSection({required this.state, required this.vm});

  @override
  State<_MatchOrganizerSection> createState() => _MatchOrganizerSectionState();
}

class _MatchOrganizerSectionState extends State<_MatchOrganizerSection> {
  final _titleController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final vm = widget.vm;
    final form = state.form;

    // The form resets to empty after a successful batch create — clear the
    // (locally-controlled) title field to match instead of leaving stale text.
    if (form.courtId == null && form.slots.isEmpty && _titleController.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _titleController.clear());
    }

    return _SectionCard(
      icon: Icons.sports_tennis_rounded,
      title: 'Organiser un match',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Terrain', style: AppTypography.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          CourtPicker(
            courts: state.courts,
            selectedCourtId: form.courtId,
            onSelect: vm.setCourt,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Titre (optionnel)', style: AppTypography.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _titleController,
            style: AppTypography.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Ex : Tournoi interne, Cours particulier...',
              hintStyle: AppTypography.bodySmall,
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            ),
            onChanged: vm.setTitle,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Joueur A (optionnel)', style: AppTypography.labelLarge),
                    const SizedBox(height: AppSpacing.sm),
                    _PlayerDropdown(
                      players: state.players,
                      value: form.playerAId,
                      onChanged: vm.setPlayerA,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Joueur B (optionnel)', style: AppTypography.labelLarge),
                    const SizedBox(height: AppSpacing.sm),
                    _PlayerDropdown(
                      players: state.players,
                      value: form.playerBId,
                      onChanged: vm.setPlayerB,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (form.playerAId != null &&
              form.playerBId != null &&
              form.playerAId == form.playerBId) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Les deux joueurs doivent être différents.',
              style: AppTypography.bodySmall.copyWith(color: AppColors.error),
            ),
          ] else if (form.playerAId == null && form.playerBId == null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Laisse les deux vides pour juste bloquer le terrain, sans joueur.',
              style: AppTypography.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text('Créneaux', style: AppTypography.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          if (form.slots.isEmpty)
            Text(
              'Aucun créneau ajouté pour le moment.',
              style: AppTypography.bodySmall,
            )
          else
            ...form.slots.asMap().entries.map(
                  (entry) => _SlotRow(
                    slot: entry.value,
                    onRemove: () => vm.removeSlot(entry.key),
                  ),
                ),
          const SizedBox(height: AppSpacing.sm),
          _AddSlotButton(
            court: state.courts.where((c) => c.id == form.courtId).firstOrNull,
            allBookings: state.allBookings,
            players: state.players,
            onAddMany: (slots) => slots.forEach(vm.addSlot),
            onCancelBooking: vm.cancelBooking,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: form.isValid
                ? 'Créer ${form.slots.length} créneau(x)'
                : 'Choisir un terrain et au moins un créneau',
            onTap: form.isValid ? vm.createMatch : null,
            isLoading: state.isSubmitting,
          ),
        ],
      ),
    );
  }
}


class _PlayerDropdown extends StatelessWidget {
  final List<UserModel> players;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _PlayerDropdown({required this.players, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: value,
      hint: Text('Aucun', style: AppTypography.bodySmall),
      isExpanded: true,
      decoration: InputDecoration(
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
      ),
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text('Aucun', style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary)),
        ),
        ...players.map((u) => DropdownMenuItem<String?>(
              value: u.id,
              child: Text(u.name, style: AppTypography.bodyMedium, overflow: TextOverflow.ellipsis),
            )),
      ],
      onChanged: onChanged,
    );
  }
}

class _SlotRow extends StatelessWidget {
  final MatchSlot slot;
  final VoidCallback onRemove;

  const _SlotRow({required this.slot, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_rounded, size: 16, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '${slot.date.day.toString().padLeft(2, '0')}/${slot.date.month.toString().padLeft(2, '0')}/${slot.date.year} · ${slot.startTime} · ${slot.durationHours}h',
              style: AppTypography.bodyMedium,
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, size: 18, color: AppColors.error),
          ),
        ],
      ),
    );
  }
}

class _AddSlotButton extends ConsumerStatefulWidget {
  final CourtModel? court;
  final List<BookingModel> allBookings;
  final List<UserModel> players;
  final ValueChanged<List<MatchSlot>> onAddMany;
  final ValueChanged<String> onCancelBooking;

  const _AddSlotButton({
    required this.court,
    required this.allBookings,
    required this.players,
    required this.onAddMany,
    required this.onCancelBooking,
  });

  @override
  ConsumerState<_AddSlotButton> createState() => _AddSlotButtonState();
}

class _AddSlotButtonState extends ConsumerState<_AddSlotButton> {
  DateTime? _date;
  final Set<String> _selectedTimes = {};

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) setState(() { _date = picked; _selectedTimes.clear(); });
  }

  void _toggleTime(String time) {
    setState(() {
      if (_selectedTimes.contains(time)) {
        _selectedTimes.remove(time);
      } else {
        _selectedTimes.add(time);
      }
    });
  }

  void _add() {
    if (_date == null || _selectedTimes.isEmpty) return;
    widget.onAddMany(
      _selectedTimes
          .map((time) => MatchSlot(date: _date!, startTime: time))
          .toList(),
    );
    setState(() {
      _date = null;
      _selectedTimes.clear();
    });
  }

  void _showBookingDetail(String time) {
    final court = widget.court;
    if (court == null || _date == null) return;
    final booking = widget.allBookings.where((b) {
      return b.courtId == court.id &&
          b.startTime == time &&
          b.status != BookingStatus.cancelled &&
          b.date.year == _date!.year &&
          b.date.month == _date!.month &&
          b.date.day == _date!.day;
    }).firstOrNull;

    final playerName = booking == null
        ? null
        : widget.players.where((u) => u.id == booking.userId).firstOrNull?.name ??
            booking.userId;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Réservation existante'),
        content: booking == null
            ? const Text("Détail introuvable pour ce créneau.")
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(booking.courtName, style: AppTypography.headlineSmall),
                  if (booking.title != null && booking.title!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      booking.title!,
                      style: AppTypography.labelMedium.copyWith(color: AppColors.primary),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Text('$time - ${booking.endTime}', style: AppTypography.bodyMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Joueur : $playerName', style: AppTypography.bodySmall),
                  if (booking.partnerName != null)
                    Text('Partenaire : ${booking.partnerName}', style: AppTypography.bodySmall),
                ],
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            child: const Text('Fermer'),
          ),
          if (booking != null)
            TextButton(
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
                widget.onCancelBooking(booking.id);
              },
              child: const Text('Annuler la réservation', style: TextStyle(color: AppColors.error)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final court = widget.court;
    final bookedTimes = court != null && _date != null
        ? ref
            .watch(bookedSlotsForCourtProvider((courtId: court.id, date: _date!)))
            .valueOrNull
        : null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border, style: BorderStyle.solid),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                _date != null
                    ? '${_date!.day.toString().padLeft(2, '0')}/${_date!.month.toString().padLeft(2, '0')}'
                    : 'Date',
                style: AppTypography.bodySmall,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (court == null)
            Text('Choisis un terrain pour voir les créneaux.', style: AppTypography.bodySmall)
          else if (_date == null)
            Text('Choisis une date pour voir les créneaux disponibles.', style: AppTypography.bodySmall)
          else if (bookedTimes == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else ...[
            Text(
              'Vert = disponible (clique pour sélectionner) · Rouge = déjà réservé (clique pour voir la résa).',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: court.baseSlotsFor(_date!).map((s) {
                final isBooked = bookedTimes.contains(s.time);
                return SlotAvailabilityChip(
                  time: s.time,
                  isBooked: isBooked,
                  isSelected: _selectedTimes.contains(s.time),
                  onTap: () => isBooked ? _showBookingDetail(s.time) : _toggleTime(s.time),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _date != null && _selectedTimes.isNotEmpty ? _add : null,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('Ajouter ${_selectedTimes.length} créneau(x)'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveBookingsSection extends StatelessWidget {
  final ManagerState state;
  final ManagerViewModel vm;

  const _ActiveBookingsSection({required this.state, required this.vm});

  @override
  Widget build(BuildContext context) {
    final bookings = state.activeBookings;
    return _SectionCard(
      icon: Icons.event_busy_rounded,
      title: 'Annuler une réservation',
      child: bookings.isEmpty
          ? Text('Aucune réservation active.', style: AppTypography.bodySmall)
          : Column(
              children: bookings
                  .map((b) => _BookingRow(
                        booking: b,
                        onCancel: () => _confirmCancel(context, vm, b),
                      ))
                  .toList(),
            ),
    );
  }

  void _confirmCancel(BuildContext context, ManagerViewModel vm, BookingModel booking) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Annuler cette réservation ?'),
        content: Text(
          '${booking.courtName} · ${booking.date.day}/${booking.date.month} · ${booking.startTime}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Retour'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              vm.cancelBooking(booking.id);
            },
            child: const Text('Annuler la réservation', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _BookingRow extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback onCancel;

  const _BookingRow({required this.booking, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(booking.courtName, style: AppTypography.headlineSmall),
                if (booking.title != null && booking.title!.isNotEmpty)
                  Text(
                    booking.title!,
                    style: AppTypography.labelSmall.copyWith(color: AppColors.primary),
                  ),
                Text(
                  '${booking.date.day.toString().padLeft(2, '0')}/${booking.date.month.toString().padLeft(2, '0')} · ${booking.startTime}-${booking.endTime}'
                  '${booking.partnerName != null ? ' · avec ${booking.partnerName}' : ''}',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onCancel,
            child: const Text('Annuler', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _CourtsManagementSection extends StatelessWidget {
  final ManagerState state;

  const _CourtsManagementSection({required this.state});

  void _openForm(BuildContext context, {CourtModel? court}) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => CourtFormScreen(court: court, clubs: state.clubs),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.location_on_rounded,
      title: 'Terrains',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.courts.isEmpty)
            Text('Aucun terrain pour le moment.', style: AppTypography.bodySmall)
          else
            ...state.courts.map((c) {
              final clubName = state.clubs.where((cl) => cl.id == c.clubId).firstOrNull?.name;
              return GestureDetector(
                onTap: () => _openForm(context, court: c),
                child: Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.name, style: AppTypography.headlineSmall),
                            Text(
                              '${c.type.label} · ${c.surface.label}'
                              '${clubName != null ? ' · $clubName' : ''}',
                              style: AppTypography.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.edit_rounded, size: 18, color: AppColors.primary),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openForm(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Ajouter un terrain'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminsSection extends StatelessWidget {
  final List<UserModel> admins;

  const _AdminsSection({required this.admins});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.shield_rounded,
      title: 'Administrateurs',
      child: admins.isEmpty
          ? Text('Aucun administrateur trouvé.', style: AppTypography.bodySmall)
          : Column(
              children: admins
                  .map(
                    (u) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        children: [
                          AppAvatar(initials: u.initials, size: 36),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(u.name, style: AppTypography.headlineSmall),
                                Text(u.email, style: AppTypography.bodySmall),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}
