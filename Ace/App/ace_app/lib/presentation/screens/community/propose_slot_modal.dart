import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/models/models.dart';
import '../../atoms/atoms.dart';
import '../courts/courts_view_model.dart';

class ProposeSlotModal extends ConsumerStatefulWidget {
  final Function(AnnouncementModel) onConfirm;
  final AnnouncementModel? initial;

  const ProposeSlotModal({super.key, required this.onConfirm, this.initial});

  static Future<void> show(
    BuildContext context, {
    required Function(AnnouncementModel) onConfirm,
    AnnouncementModel? initial,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProposeSlotModal(onConfirm: onConfirm, initial: initial),
    );
  }

  @override
  ConsumerState<ProposeSlotModal> createState() => _ProposeSlotModalState();
}

class _ProposeSlotModalState extends ConsumerState<ProposeSlotModal> {
  late final TextEditingController _messageController;
  String? _selectedCourtId;
  late DateTime _selectedDate;
  late String? _selectedTime;
  int _durationMinutes = 90;
  late MatchType _matchType;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final a = widget.initial;
    _messageController = TextEditingController(text: a?.message ?? '');
    _selectedDate = a?.date ?? DateTime.now().add(const Duration(days: 1));
    _selectedTime = (a?.time == 'À définir') ? null : a?.time;
    _matchType = a?.matchType ?? MatchType.singles;
    _selectedCourtId = (a != null && a.courtId.isNotEmpty) ? a.courtId : null;
  }

  static const _durations = [
    (label: '30 min', value: 30),
    (label: '1h', value: 60),
    (label: '1h30', value: 90),
    (label: '2h', value: 120),
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  bool get _isValid => _messageController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final courts = ref.watch(courtsViewModelProvider).courts;
    final selectedCourt =
        courts.where((c) => c.id == _selectedCourtId).firstOrNull;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.xxxl)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.xxl,
        right: AppSpacing.xxl,
        top: AppSpacing.xxl,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xxl,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
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
            const SizedBox(height: AppSpacing.xxl),
            Text(_isEdit ? "Modifier l'annonce" : 'Proposer un créneau', style: AppTypography.headlineLarge),
            const SizedBox(height: AppSpacing.xxl),
            // Date (obligatoire)
            _FieldLabel('Date *'),
            const SizedBox(height: AppSpacing.sm),
            _DatePicker(
              date: _selectedDate,
              onSelect: (d) => setState(() => _selectedDate = d),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Heure (optionnelle)
            _FieldLabel('Heure (optionnelle)'),
            const SizedBox(height: AppSpacing.sm),
            _TimePicker(
              time: _selectedTime,
              onSelect: (t) => setState(() => _selectedTime = t),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Durée max 2h
            _FieldLabel('Durée (max 2h)'),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: _durations.map((d) {
                final isSelected = _durationMinutes == d.value;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _durationMinutes = d.value),
                    child: Container(
                      margin: EdgeInsets.only(
                          right: d.value != 120 ? AppSpacing.sm : 0),
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.background,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.border),
                      ),
                      child: Text(
                        d.label,
                        textAlign: TextAlign.center,
                        style: AppTypography.labelSmall.copyWith(
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Terrain (optionnel)
            _FieldLabel('Terrain (optionnel)'),
            const SizedBox(height: AppSpacing.sm),
            _CourtDropdown(
              courts: courts,
              selected: selectedCourt,
              onSelect: (c) => setState(() => _selectedCourtId = c?.id),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Type de match (obligatoire)
            _FieldLabel('Type de match *'),
            const SizedBox(height: AppSpacing.sm),
            _MatchTypeSelector(
              selected: _matchType,
              onSelect: (t) => setState(() => _matchType = t),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Description (obligatoire)
            _FieldLabel('Description *'),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _messageController,
              maxLines: 3,
              style: AppTypography.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Décrivez votre annonce...',
                hintStyle: AppTypography.bodySmall,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                filled: true,
                fillColor: AppColors.background,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppButton(
              label: _isEdit ? 'Mettre à jour' : "Publier l'annonce",
              onTap: _isValid ? _confirm : null,
            ),
          ],
        ),
      ),
    );
  }

  void _confirm() {
    final courts = ref.read(courtsViewModelProvider).courts;
    final selectedCourt =
        courts.where((c) => c.id == _selectedCourtId).firstOrNull;
    final announcement = AnnouncementModel(
      id: widget.initial?.id ?? 'ann_new_${DateTime.now().millisecondsSinceEpoch}',
      userId: MockData.currentUser.id,
      userName:
          '${MockData.currentUser.name.split(' ').first} ${MockData.currentUser.name.split(' ').last[0]}.',
      userRanking: MockData.currentUser.ranking,
      courtId: selectedCourt?.id ?? '',
      courtName: selectedCourt?.name ?? 'Terrain à définir',
      date: _selectedDate,
      time: _selectedTime ?? 'À définir',
      message: _messageController.text.trim(),
      matchType: _matchType,
      level: MockData.currentUser.ranking,
      responsesCount: 0,
      interestedCount: 0,
      createdAt: DateTime.now(),
    );
    widget.onConfirm(announcement);
    Navigator.of(context).pop();
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTypography.labelLarge);
}

class _CourtDropdown extends StatelessWidget {
  final List<CourtModel> courts;
  final CourtModel? selected;
  final ValueChanged<CourtModel?> onSelect;

  const _CourtDropdown({required this.courts, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return _DropdownContainer(
      child: DropdownButton<CourtModel>(
        value: selected,
        isExpanded: true,
        underline: const SizedBox(),
        hint: Text('Choisir un terrain (optionnel)', style: AppTypography.bodySmall),
        items: courts
            .map((c) => DropdownMenuItem(
                value: c, child: Text(c.name, style: AppTypography.bodyMedium)))
            .toList(),
        onChanged: onSelect,
      ),
    );
  }
}

class _DropdownContainer extends StatelessWidget {
  final Widget child;
  const _DropdownContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _DatePicker extends StatelessWidget {
  final DateTime date;
  final ValueChanged<DateTime> onSelect;

  const _DatePicker({required this.date, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 60)),
        );
        if (picked != null) onSelect(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
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
              DateFormat('dd/MM/yy', 'fr_FR').format(date),
              style: AppTypography.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _TimePicker extends StatelessWidget {
  final String? time;
  final ValueChanged<String> onSelect;

  const _TimePicker({required this.time, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return _DropdownContainer(
      child: DropdownButton<String>(
        value: time,
        isExpanded: true,
        underline: const SizedBox(),
        hint: Text('À définir', style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
        items: AppConstants.timeSlots
            .map((t) => DropdownMenuItem(
                value: t, child: Text(t, style: AppTypography.bodySmall)))
            .toList(),
        onChanged: (t) {
          if (t != null) onSelect(t);
        },
      ),
    );
  }
}

class _MatchTypeSelector extends StatelessWidget {
  final MatchType selected;
  final ValueChanged<MatchType> onSelect;

  const _MatchTypeSelector({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: MatchType.values.map((t) {
        final isSelected = selected == t;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(t),
            child: Container(
              margin: EdgeInsets.only(right: t != MatchType.mixed ? AppSpacing.sm : 0),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.background,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
              ),
              child: Text(
                t.label,
                textAlign: TextAlign.center,
                style: AppTypography.labelSmall.copyWith(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
