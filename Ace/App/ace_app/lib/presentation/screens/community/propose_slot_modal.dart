import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/models/models.dart';
import '../../atoms/atoms.dart';
import '../auth/auth_view_model.dart';
import '../courts/courts_view_model.dart';

class ProposeSlotModal extends ConsumerStatefulWidget {
  final Future<void> Function(AnnouncementModel) onConfirm;
  final AnnouncementModel? initial;

  const ProposeSlotModal({super.key, required this.onConfirm, this.initial});

  static Future<void> show(
    BuildContext context, {
    required Future<void> Function(AnnouncementModel) onConfirm,
    AnnouncementModel? initial,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // Attaches to the root Navigator instead of the shell's nested one,
      // so the sheet renders above the bottom nav bar instead of behind it.
      useRootNavigator: true,
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
  bool _noSpecificCourt = false;
  late DateTime _selectedDate;
  late String? _selectedTime;
  int _durationMinutes = 90;
  late MatchType _matchType;
  bool _isLoading = false;

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
    _noSpecificCourt = a != null && a.courtId.isEmpty && a.courtName.isNotEmpty;
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
    final selectedCourt = courts
        .where((c) => c.id == _selectedCourtId)
        .firstOrNull;
    final mediaQuery = MediaQuery.of(context);

    return Container(
      constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.88),
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.xxxl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
            child: Text(
              _isEdit ? "Modifier l'annonce" : 'Proposer un créneau',
              style: AppTypography.headlineLarge,
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.lg,
                AppSpacing.xxl,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                          onTap: () =>
                              setState(() => _durationMinutes = d.value),
                          child: Container(
                            margin: EdgeInsets.only(
                              right: d.value != 120 ? AppSpacing.sm : 0,
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusMd,
                              ),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                            ),
                            child: Text(
                              d.label,
                              textAlign: TextAlign.center,
                              style: AppTypography.labelSmall.copyWith(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textSecondary,
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
                  _CourtPicker(
                    courts: courts,
                    selected: selectedCourt,
                    noSpecificCourt: _noSpecificCourt,
                    onSelect: (result) => setState(() {
                      _noSpecificCourt = result.noSpecificCourt;
                      _selectedCourtId = result.courtId;
                    }),
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
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              0,
              AppSpacing.xxl,
              AppSpacing.xxl,
            ),
            child: AppButton(
              label: _isEdit ? 'Mettre à jour' : "Publier l'annonce",
              onTap: _isValid && !_isLoading ? _confirm : null,
              isLoading: _isLoading,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm() async {
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser == null) return;
    setState(() => _isLoading = true);
    final courts = ref.read(courtsViewModelProvider).courts;
    final selectedCourt = courts
        .where((c) => c.id == _selectedCourtId)
        .firstOrNull;
    final nameParts = currentUser.name.trim().split(' ');
    final displayName = nameParts.length >= 2
        ? '${nameParts.first} ${nameParts.last[0]}.'
        : currentUser.name;
    final announcement = AnnouncementModel(
      id: widget.initial?.id ?? '',
      userId: currentUser.id,
      userName: displayName,
      userRanking: currentUser.ranking,
      userImageUrl: currentUser.profileImageUrl,
      courtId: selectedCourt?.id ?? '',
      courtName:
          selectedCourt?.name ??
          (_noSpecificCourt ? 'Terrain, on verra' : 'Terrain à définir'),
      date: _selectedDate,
      time: _selectedTime ?? 'À définir',
      message: _messageController.text.trim(),
      matchType: _matchType,
      level: currentUser.ranking,
      responsesCount: 0,
      interestedCount: 0,
      createdAt: DateTime.now(),
    );

    try {
      await widget.onConfirm(announcement);
      // Pop the same (root) navigator the sheet was pushed onto — plain
      // Navigator.of(context) can resolve to the wrong one here and leave
      // the sheet stuck open, since show() uses useRootNavigator: true.
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Une erreur est survenue, réessaie.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTypography.labelLarge);
}

/// Shared "tap to open a bottom sheet picker" field shell.
class _PickerField extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color labelColor;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _PickerField({
    required this.icon,
    required this.label,
    required this.onTap,
    this.labelColor = AppColors.textPrimary,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodySmall.copyWith(color: labelColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(AppSpacing.xs),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.textTertiary,
                  ),
                ),
              )
            else
              const Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: AppColors.textTertiary,
              ),
          ],
        ),
      ),
    );
  }
}

class _PickerSheetShell extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? footer;

  const _PickerSheetShell({
    required this.title,
    required this.child,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.xxxl),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.md),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(title, style: AppTypography.headlineLarge),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          child,
          if (footer != null) ...[
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: footer,
            ),
          ],
        ],
      ),
    );
  }
}

class _DatePicker extends StatelessWidget {
  final DateTime date;
  final ValueChanged<DateTime> onSelect;

  const _DatePicker({required this.date, required this.onSelect});

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => _DatePickerSheet(initialDate: date),
    );
    if (picked != null) onSelect(picked);
  }

  @override
  Widget build(BuildContext context) {
    return _PickerField(
      icon: Icons.calendar_today_rounded,
      label: _capitalize(DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(date)),
      onTap: () => _open(context),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _DatePickerSheet extends StatefulWidget {
  final DateTime initialDate;
  const _DatePickerSheet({required this.initialDate});

  @override
  State<_DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends State<_DatePickerSheet> {
  late DateTime _selected = widget.initialDate;

  @override
  Widget build(BuildContext context) {
    return _PickerSheetShell(
      title: 'Choisir une date',
      footer: AppButton(
        label: 'Valider',
        onTap: () => Navigator.of(context, rootNavigator: true).pop(_selected),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: CalendarDatePicker(
          initialDate: _selected,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 60)),
          onDateChanged: (d) => setState(() => _selected = d),
        ),
      ),
    );
  }
}

const _allDayLabel = 'Toute la journée';

class _TimePicker extends StatelessWidget {
  final String? time;
  final ValueChanged<String?> onSelect;

  const _TimePicker({required this.time, required this.onSelect});

  Future<void> _open(BuildContext context) async {
    final result = await showModalBottomSheet<_TimePickResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => _TimePickerSheet(selected: time),
    );
    if (result != null) onSelect(result.time);
  }

  @override
  Widget build(BuildContext context) {
    final hasTime = time != null;
    return _PickerField(
      icon: Icons.access_time_rounded,
      label: hasTime ? time! : 'À définir',
      labelColor: hasTime ? AppColors.textPrimary : AppColors.textTertiary,
      onTap: () => _open(context),
      onClear: hasTime ? () => onSelect(null) : null,
    );
  }
}

class _TimePickResult {
  final String? time;
  const _TimePickResult(this.time);
}

class _TimePickerSheet extends StatefulWidget {
  final String? selected;
  const _TimePickerSheet({required this.selected});

  @override
  State<_TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends State<_TimePickerSheet> {
  String? _start;
  String? _end;

  @override
  void initState() {
    super.initState();
    final selected = widget.selected;
    if (selected != null &&
        selected != _allDayLabel &&
        selected.contains('-')) {
      final parts = selected.split('-');
      if (parts.length == 2) {
        _start = parts[0];
        _end = parts[1];
      }
    }
  }

  bool get _canValidate =>
      _start != null && _end != null && _end!.compareTo(_start!) > 0;

  void _pop(String? time) =>
      Navigator.of(context, rootNavigator: true).pop(_TimePickResult(time));

  @override
  Widget build(BuildContext context) {
    return _PickerSheetShell(
      title: 'Choisir un horaire',
      footer: AppButton(
        label: 'Valider le créneau',
        onTap: _canValidate ? () => _pop('$_start-$_end') : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => _pop(_allDayLabel),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  color: widget.selected == _allDayLabel
                      ? AppColors.primary
                      : AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.primary),
                ),
                child: Text(
                  _allDayLabel,
                  textAlign: TextAlign.center,
                  style: AppTypography.labelMedium.copyWith(
                    color: widget.selected == _allDayLabel
                        ? Colors.white
                        : AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                const Expanded(child: Divider(color: AppColors.border)),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  child: Text(
                    'ou un créneau précis',
                    style: AppTypography.bodySmall,
                  ),
                ),
                const Expanded(child: Divider(color: AppColors.border)),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _FieldLabel('Début'),
            const SizedBox(height: AppSpacing.sm),
            _TimeSlotGrid(
              slots: AppConstants.timeSlots,
              selected: _start,
              onSelect: (t) => setState(() {
                _start = t;
                if (_end != null && _end!.compareTo(t) <= 0) _end = null;
              }),
            ),
            const SizedBox(height: AppSpacing.lg),
            _FieldLabel('Fin'),
            const SizedBox(height: AppSpacing.sm),
            if (_start == null)
              Text(
                "Choisis d'abord une heure de début.",
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              )
            else
              _TimeSlotGrid(
                slots: AppConstants.timeSlots
                    .where((t) => t.compareTo(_start!) > 0)
                    .toList(),
                selected: _end,
                onSelect: (t) => setState(() => _end = t),
              ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

class _TimeSlotGrid extends StatelessWidget {
  final List<String> slots;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _TimeSlotGrid({
    required this.slots,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.22,
      ),
      child: SingleChildScrollView(
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: slots.map((t) {
            final isSelected = t == selected;
            return GestureDetector(
              onTap: () => onSelect(t),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.background,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Text(
                  t,
                  style: AppTypography.labelMedium.copyWith(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _CourtPickResult {
  final String? courtId;
  final bool noSpecificCourt;
  const _CourtPickResult({this.courtId, this.noSpecificCourt = false});
}

class _CourtPicker extends StatelessWidget {
  final List<CourtModel> courts;
  final CourtModel? selected;
  final bool noSpecificCourt;
  final ValueChanged<_CourtPickResult> onSelect;

  const _CourtPicker({
    required this.courts,
    required this.selected,
    required this.noSpecificCourt,
    required this.onSelect,
  });

  Future<void> _open(BuildContext context) async {
    final result = await showModalBottomSheet<_CourtPickResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => _CourtPickerSheet(
        courts: courts,
        selectedId: selected?.id,
        noSpecificCourtSelected: noSpecificCourt,
      ),
    );
    if (result != null) onSelect(result);
  }

  @override
  Widget build(BuildContext context) {
    final label =
        selected?.name ??
        (noSpecificCourt
            ? 'Terrain, on verra'
            : 'Choisir un terrain (optionnel)');
    final hasChoice = selected != null || noSpecificCourt;
    return _PickerField(
      icon: Icons.sports_tennis_rounded,
      label: label,
      labelColor: hasChoice ? AppColors.textPrimary : AppColors.textTertiary,
      onTap: () => _open(context),
      onClear: hasChoice ? () => onSelect(const _CourtPickResult()) : null,
    );
  }
}

class _CourtPickerSheet extends StatelessWidget {
  final List<CourtModel> courts;
  final String? selectedId;
  final bool noSpecificCourtSelected;

  const _CourtPickerSheet({
    required this.courts,
    required this.selectedId,
    required this.noSpecificCourtSelected,
  });

  @override
  Widget build(BuildContext context) {
    return _PickerSheetShell(
      title: 'Choisir un terrain',
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          children: [
            ListTile(
              leading: const Icon(
                Icons.shuffle_rounded,
                color: AppColors.primary,
              ),
              title: Text('Terrain, on verra', style: AppTypography.bodyMedium),
              trailing: noSpecificCourtSelected
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.primary,
                    )
                  : null,
              onTap: () => Navigator.of(
                context,
                rootNavigator: true,
              ).pop(const _CourtPickResult(noSpecificCourt: true)),
            ),
            ...courts.map(
              (c) => ListTile(
                leading: Icon(
                  Icons.sports_tennis_rounded,
                  color: c.id == selectedId
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                title: Text(c.name, style: AppTypography.bodyMedium),
                trailing: c.id == selectedId
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.primary,
                      )
                    : null,
                onTap: () => Navigator.of(
                  context,
                  rootNavigator: true,
                ).pop(_CourtPickResult(courtId: c.id)),
              ),
            ),
          ],
        ),
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
              margin: EdgeInsets.only(
                right: t != MatchType.mixed ? AppSpacing.sm : 0,
              ),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.background,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
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
