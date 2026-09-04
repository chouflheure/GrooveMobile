import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/models/models.dart';
import '../../atoms/atoms.dart';
import 'manager_view_model.dart';

/// Create/edit form for a club event — reached from the Manager screen's
/// "Événements" section. Pass `event: null` to create a new one.
class EventFormScreen extends ConsumerStatefulWidget {
  final ClubEventModel? event;
  final List<ClubModel> clubs;
  final List<CourtModel> courts;

  const EventFormScreen({
    super.key,
    this.event,
    required this.clubs,
    required this.courts,
  });

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  late final _titleController = TextEditingController(
    text: widget.event?.title ?? '',
  );
  late final _descriptionController = TextEditingController(
    text: widget.event?.description ?? '',
  );
  late final _addressController = TextEditingController(
    text: widget.event?.address ?? '',
  );

  late String? _clubId =
      widget.event?.clubId ??
      (widget.clubs.length == 1 ? widget.clubs.first.id : null);
  late DateTime? _date = widget.event?.date;
  late final Set<String> _selectedCourtIds = widget.event != null
      ? widget.courts
            .where((c) => widget.event!.courtNames.contains(c.name))
            .map((c) => c.id)
            .toSet()
      : {};
  late String? _startTime = widget.event?.startTime.isNotEmpty == true
      ? widget.event!.startTime
      : null;
  late String? _endTime = widget.event?.endTime.isNotEmpty == true
      ? widget.event!.endTime
      : null;
  bool _isSaving = false;
  bool _isDeleting = false;

  static final List<String> _closingTimes = [
    ...AppConstants.timeSlots.skip(1),
    '24:00',
  ];

  bool get _isEditing => widget.event != null;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  bool get _isValid =>
      _titleController.text.trim().isNotEmpty &&
      _addressController.text.trim().isNotEmpty &&
      _clubId != null &&
      _date != null &&
      // Courts were picked → an hourly range must be set too, so those
      // slots can actually be reserved on save.
      (_selectedCourtIds.isEmpty ||
          _isEditing ||
          (_startTime != null && _endTime != null));

  Future<void> _save() async {
    if (!_isValid) return;
    setState(() => _isSaving = true);

    final club = widget.clubs.firstWhere((c) => c.id == _clubId);
    final selectedCourts = widget.courts
        .where((c) => _selectedCourtIds.contains(c.id))
        .toList();

    final event = ClubEventModel(
      id: widget.event?.id ?? '',
      clubId: club.id,
      clubName: club.name,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      date: _date!,
      address: _addressController.text.trim(),
      courtNames: selectedCourts.map((c) => c.name).toList(),
      startTime: _startTime ?? '',
      endTime: _endTime ?? '',
      participantIds: widget.event?.participantIds ?? const [],
      createdAt: widget.event?.createdAt ?? DateTime.now(),
    );

    final notifier = ref.read(managerViewModelProvider.notifier);
    final ok = _isEditing
        ? await notifier.updateEvent(event)
        : await notifier.createEvent(event, reserveCourts: selectedCourts);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (ok) Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _delete() async {
    final event = widget.event;
    if (event == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer cet événement ?'),
        content: Text('"${event.title}" sera définitivement supprimé.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isDeleting = true);
    final ok = await ref
        .read(managerViewModelProvider.notifier)
        .deleteEvent(event.id, event.title);
    if (!mounted) return;
    setState(() => _isDeleting = false);
    if (ok) Navigator.of(context, rootNavigator: true).pop();
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    if (widget.clubs.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          scrolledUnderElevation: 0,
          title: const Text('Événement'),
          leading: GestureDetector(
            onTap: () => Navigator.of(context, rootNavigator: true).pop(),
            child: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Text(
              "Tu n'es membre d'aucun club, tu ne peux donc pas créer d'événement.",
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium,
            ),
          ),
        ),
      );
    }

    final courtsForClub = widget.courts
        .where((c) => c.clubId == _clubId)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: Text(_isEditing ? "Modifier l'événement" : 'Créer un événement'),
        leading: GestureDetector(
          onTap: () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          if (_isEditing)
            IconButton(
              onPressed: _isDeleting ? null : _delete,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
              ),
            ),
        ],
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _Label('Titre'),
          const SizedBox(height: AppSpacing.sm),
          _TextField(
            controller: _titleController,
            hint: 'Tournoi de printemps',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Label('Club'),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: widget.clubs.map((c) {
              final isSelected = _clubId == c.id;
              return GestureDetector(
                onTap: () => setState(() {
                  _clubId = c.id;
                  _selectedCourtIds.clear();
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Text(
                    c.name,
                    style: AppTypography.labelMedium.copyWith(
                      color: isSelected
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Label('Description'),
          const SizedBox(height: AppSpacing.sm),
          _TextField(
            controller: _descriptionController,
            maxLines: 4,
            hint: "Description de l'événement",
          ),
          const SizedBox(height: AppSpacing.lg),
          _Label('Date'),
          const SizedBox(height: AppSpacing.sm),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    _date != null ? _fmt(_date!) : 'Choisir une date',
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Label('Adresse'),
          const SizedBox(height: AppSpacing.sm),
          _TextField(
            controller: _addressController,
            hint: 'Paris 12e',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Label('Terrains pris'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _isEditing
                ? 'Les terrains occupés par cet événement (informatif).'
                : "Les créneaux horaires ci-dessous seront réservés sur les terrains sélectionnés.",
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (courtsForClub.isEmpty)
            Text(
              'Choisis un club pour voir ses terrains.',
              style: AppTypography.bodySmall,
            )
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: courtsForClub.map((c) {
                final isSelected = _selectedCourtIds.contains(c.id);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (isSelected) {
                      _selectedCourtIds.remove(c.id);
                    } else {
                      _selectedCourtIds.add(c.id);
                    }
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull,
                      ),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                    child: Text(
                      c.name,
                      style: AppTypography.labelMedium.copyWith(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          if (_selectedCourtIds.isNotEmpty && !_isEditing) ...[
            const SizedBox(height: AppSpacing.lg),
            _Label('Horaire'),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _startTime,
                    hint: Text('Début', style: AppTypography.bodySmall),
                    decoration: _decoration(),
                    items: AppConstants.timeSlots
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(t, style: AppTypography.bodySmall),
                          ),
                        )
                        .toList(),
                    onChanged: (t) => setState(() {
                      _startTime = t;
                      if (_endTime != null &&
                          t != null &&
                          _endTime!.compareTo(t) <= 0) {
                        _endTime = null;
                      }
                    }),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: Text('→'),
                ),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _endTime,
                    hint: Text('Fin', style: AppTypography.bodySmall),
                    decoration: _decoration(),
                    items: _closingTimes
                        .where(
                          (t) =>
                              _startTime == null ||
                              t.compareTo(_startTime!) > 0,
                        )
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(t, style: AppTypography.bodySmall),
                          ),
                        )
                        .toList(),
                    onChanged: _startTime == null
                        ? null
                        : (t) => setState(() => _endTime = t),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: _isEditing ? 'Enregistrer' : "Créer l'événement",
            onTap: _isValid ? _save : null,
            isLoading: _isSaving,
          ),
          SizedBox(
            height: AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration() => InputDecoration(
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
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
  );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTypography.labelLarge);
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const _TextField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      style: AppTypography.bodyMedium,
      decoration: InputDecoration(
        hintText: hint,
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
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
    );
  }
}
