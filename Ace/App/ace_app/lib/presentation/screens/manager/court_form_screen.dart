import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/models/models.dart';
import '../../atoms/atoms.dart';
import 'manager_view_model.dart';

/// Create/edit form for a court — reached from the Manager screen's
/// "Terrains" section. Pass `court: null` to create a new one.
class CourtFormScreen extends ConsumerStatefulWidget {
  final CourtModel? court;
  final List<ClubModel> clubs;

  const CourtFormScreen({super.key, required this.court, required this.clubs});

  @override
  ConsumerState<CourtFormScreen> createState() => _CourtFormScreenState();
}

class _CourtFormScreenState extends ConsumerState<CourtFormScreen> {
  late final _nameController = TextEditingController(
    text: widget.court?.name ?? '',
  );
  late final _locationController = TextEditingController(
    text: widget.court?.location ?? '',
  );
  late final _imageUrlController = TextEditingController(
    text: widget.court?.imageUrl ?? '',
  );
  late final _descriptionController = TextEditingController(
    text: widget.court?.description ?? '',
  );
  late final _priceController = TextEditingController(
    text: widget.court != null ? widget.court!.pricePerHour.toString() : '',
  );
  late final _amenityController = TextEditingController();
  late final _reasonController = TextEditingController();

  late CourtType _type = widget.court?.type ?? CourtType.outdoor;
  late CourtSurface _surface = widget.court?.surface ?? CourtSurface.hard;
  late String? _clubId = widget.court?.clubId.isNotEmpty == true
      ? widget.court!.clubId
      : (widget.clubs.length == 1 ? widget.clubs.first.id : null);
  final List<String> _amenities = [];
  late final Set<String> _selectedTimes = widget.court != null
      ? widget.court!.availableSlots.map((s) => s.time).toSet()
      : AppConstants.timeSlots.toSet();
  late final Set<String> _peakTimes = widget.court != null
      ? widget.court!.peakHours.toSet()
      : {};
  final List<UnavailablePeriod> _periods = [];
  final List<AvailabilityOverride> _overrides = [];
  String _overrideFrom = AppConstants.timeSlots.first;
  String _overrideTo = AppConstants.timeSlots.last;
  bool _isSaving = false;
  bool _isDeleting = false;

  bool get _isEditing => widget.court != null;

  // One hour after the last bookable start time, so an admin can pick an
  // end boundary that actually includes that last slot.
  static final List<String> _closingTimes = [
    ...AppConstants.timeSlots.skip(1),
    '24:00',
  ];

  @override
  void initState() {
    super.initState();
    _amenities.addAll(widget.court?.amenities ?? const []);
    _periods.addAll(widget.court?.unavailablePeriods ?? const []);
    _overrides.addAll(widget.court?.availabilityOverrides ?? const []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _imageUrlController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _amenityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _addAmenity() {
    final value = _amenityController.text.trim();
    if (value.isEmpty || _amenities.contains(value)) return;
    setState(() {
      _amenities.add(value);
      _amenityController.clear();
    });
  }

  Future<void> _addOverride() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (range == null) return;
    if (_overrideFrom.compareTo(_overrideTo) >= 0) return;
    setState(() {
      _overrides.add(
        AvailabilityOverride(
          startDate: range.start,
          endDate: range.end,
          openFrom: _overrideFrom,
          openTo: _overrideTo,
        ),
      );
    });
  }

  Future<void> _addPeriod() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (range == null) return;
    setState(() {
      _periods.add(
        UnavailablePeriod(
          startDate: range.start,
          endDate: range.end,
          reason: _reasonController.text.trim().isEmpty
              ? null
              : _reasonController.text.trim(),
        ),
      );
      _reasonController.clear();
    });
  }

  bool get _isValid =>
      _nameController.text.trim().isNotEmpty &&
      _locationController.text.trim().isNotEmpty &&
      double.tryParse(_priceController.text.trim()) != null &&
      _selectedTimes.isNotEmpty &&
      _clubId != null;

  Future<void> _save() async {
    if (!_isValid) return;
    setState(() => _isSaving = true);

    final court = CourtModel(
      id: widget.court?.id ?? '',
      name: _nameController.text.trim(),
      type: _type,
      surface: _surface,
      location: _locationController.text.trim(),
      pricePerHour: double.parse(_priceController.text.trim()),
      rating: widget.court?.rating ?? 0,
      imageUrl: _imageUrlController.text.trim(),
      description: _descriptionController.text.trim(),
      amenities: _amenities,
      availableSlots: AppConstants.timeSlots
          .where(_selectedTimes.contains)
          .map((t) => TimeSlot(time: t, isAvailable: true))
          .toList(),
      clubId: _clubId ?? '',
      unavailablePeriods: _periods,
      availabilityOverrides: _overrides,
      // A time can only be "peak" if it's actually offered.
      peakHours: _peakTimes.where(_selectedTimes.contains).toList(),
    );

    final ok = await ref
        .read(managerViewModelProvider.notifier)
        .saveCourt(court);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (ok) Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _delete() async {
    final court = widget.court;
    if (court == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce terrain ?'),
        content: Text(
          '"${court.name}" sera définitivement supprimé. Les réservations existantes ne seront pas annulées.',
        ),
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
        .deleteCourt(court.id, court.name);
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
          title: const Text('Terrain'),
          leading: GestureDetector(
            onTap: () => Navigator.of(context, rootNavigator: true).pop(),
            child: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Text(
              "Tu n'es membre d'aucun club, tu ne peux donc pas gérer de terrain.",
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium,
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: Text(_isEditing ? 'Modifier le terrain' : 'Ajouter un terrain'),
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
        leading: GestureDetector(
          onTap: () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _Label('Nom'),
          _TextField(
            controller: _nameController,
            hint: 'Court Central',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Label('Club'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Tu ne peux créer/modifier un terrain que pour un club dont tu es membre.',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: widget.clubs.map((c) {
              final isSelected = _clubId == c.id;
              return GestureDetector(
                onTap: () => setState(() => _clubId = c.id),
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
          _Label('Adresse'),
          _TextField(
            controller: _locationController,
            hint: 'Paris 12e',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Label('Image (URL)'),
          _TextField(controller: _imageUrlController, hint: 'https://...'),
          const SizedBox(height: AppSpacing.lg),
          _Label('Description'),
          _TextField(
            controller: _descriptionController,
            maxLines: 4,
            hint: 'Description du terrain',
          ),
          const SizedBox(height: AppSpacing.lg),
          _Label('Prix/heure (€)'),
          _TextField(
            controller: _priceController,
            hint: '25',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Label('Type'),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: CourtType.values.map((t) {
              final isSelected = _type == t;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _type = t),
                  child: Container(
                    margin: EdgeInsets.only(
                      right: t == CourtType.values.first ? AppSpacing.sm : 0,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                    child: Text(
                      t.label,
                      textAlign: TextAlign.center,
                      style: AppTypography.labelMedium.copyWith(
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
          _Label('Surface'),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: CourtSurface.values.map((s) {
              final isSelected = _surface == s;
              return GestureDetector(
                onTap: () => setState(() => _surface = s),
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
                    s.label,
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
          _Label('Équipements'),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _amenities
                .map(
                  (a) => Chip(
                    label: Text(a, style: AppTypography.labelMedium),
                    onDeleted: () => setState(() => _amenities.remove(a)),
                    backgroundColor: AppColors.surfaceVariant,
                    deleteIconColor: AppColors.textSecondary,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _TextField(
                  controller: _amenityController,
                  hint: 'Ajouter un équipement',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                onPressed: _addAmenity,
                icon: const Icon(
                  Icons.add_circle_rounded,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _Label('Créneaux proposés'),
          const SizedBox(height: AppSpacing.xs),
          Text.rich(
            TextSpan(
              style: AppTypography.bodySmall,
              children: [
                const TextSpan(
                  text: 'Clique sur un horaire pour le faire passer par : '
                      'non proposé (gris) → ',
                ),
                TextSpan(
                  text: 'heure creuse',
                  style: TextStyle(
                    color: AppColors.offPeakHour,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const TextSpan(text: ' (vert) → '),
                TextSpan(
                  text: 'heure pleine',
                  style: TextStyle(
                    color: AppColors.peakHour,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const TextSpan(text: ' (bleu).'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: AppConstants.timeSlots.map((t) {
              final isSelected = _selectedTimes.contains(t);
              final isPeak = _peakTimes.contains(t);
              return _HourStateChip(
                time: t,
                isOffered: isSelected,
                isPeak: isPeak,
                onTap: () => setState(() {
                  if (!isSelected) {
                    // Not offered -> heure creuse.
                    _selectedTimes.add(t);
                  } else if (!isPeak) {
                    // Heure creuse -> heure pleine.
                    _peakTimes.add(t);
                  } else {
                    // Heure pleine -> not offered.
                    _selectedTimes.remove(t);
                    _peakTimes.remove(t);
                  }
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Label('Plages horaires spéciales'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Restreint les horaires proposés sur une plage de dates (ex : 14h-18h seulement du 15 au 20 juin).',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          ..._overrides.map(
            (o) => Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '${_fmt(o.startDate)} → ${_fmt(o.endDate)} · ${o.openFrom}-${o.openTo}',
                      style: AppTypography.bodyMedium,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _overrides.remove(o)),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _overrideFrom,
                  decoration: _decoration(),
                  items: AppConstants.timeSlots
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(t, style: AppTypography.bodySmall),
                        ),
                      )
                      .toList(),
                  onChanged: (t) {
                    if (t != null) setState(() => _overrideFrom = t);
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Text('→'),
              ),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _overrideTo,
                  decoration: _decoration(),
                  items: _closingTimes
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(t, style: AppTypography.bodySmall),
                        ),
                      )
                      .toList(),
                  onChanged: (t) {
                    if (t != null) setState(() => _overrideTo = t);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addOverride,
              icon: const Icon(Icons.date_range_rounded, size: 18),
              label: const Text('Ajouter la plage de dates'),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Label('Périodes de fermeture'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Bloque toutes les réservations sur cette plage de dates (maintenance, événement...).',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          ..._periods.map(
            (p) => Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.event_busy_rounded,
                    size: 16,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '${_fmt(p.startDate)} → ${_fmt(p.endDate)}'
                      '${p.reason != null ? ' · ${p.reason}' : ''}',
                      style: AppTypography.bodyMedium,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _periods.remove(p)),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _TextField(
                  controller: _reasonController,
                  hint: 'Raison (optionnel)',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: _addPeriod,
                icon: const Icon(Icons.date_range_rounded, size: 18),
                label: const Text('Ajouter'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: _isEditing ? 'Enregistrer' : 'Créer le terrain',
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

/// One hour "pastille" in the court edit form's "Créneaux proposés" — tap
/// cycles it through not-offered (grey) → heure creuse (green) → heure
/// pleine (blue) → back to not-offered.
class _HourStateChip extends StatelessWidget {
  final String time;
  final bool isOffered;
  final bool isPeak;
  final VoidCallback onTap;

  const _HourStateChip({
    required this.time,
    required this.isOffered,
    required this.isPeak,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent = !isOffered
        ? AppColors.textTertiary
        : isPeak
        ? AppColors.peakHour
        : AppColors.offPeakHour;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isOffered ? accent : AppColors.background,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(color: accent, width: isOffered ? 1.5 : 1),
        ),
        child: Text(
          time,
          style: AppTypography.labelMedium.copyWith(
            color: isOffered ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
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
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const _TextField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
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
