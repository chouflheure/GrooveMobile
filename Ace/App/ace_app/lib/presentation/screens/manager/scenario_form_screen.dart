import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/models/models.dart';
import '../../atoms/atoms.dart';
import 'manager_view_model.dart';

/// Create/edit form for a booking scenario — a named, reusable
/// `BookingPolicy` a court can be assigned to (see `CourtFormScreen`'s
/// scenario picker). Reached from the Manager screen's "Gérer la
/// disponibilité" section. Pass `scenario: null` to create a new one.
class ScenarioFormScreen extends ConsumerStatefulWidget {
  final BookingScenario? scenario;
  final List<ClubModel> clubs;

  const ScenarioFormScreen({
    super.key,
    required this.scenario,
    required this.clubs,
  });

  @override
  ConsumerState<ScenarioFormScreen> createState() =>
      _ScenarioFormScreenState();
}

class _ScenarioFormScreenState extends ConsumerState<ScenarioFormScreen> {
  late final String _scenarioId =
      widget.scenario?.id ??
      FirebaseFirestore.instance.collection('bookingScenarios').doc().id;
  late final _nameController = TextEditingController(
    text: widget.scenario?.name ?? '',
  );
  late String? _clubId = widget.scenario?.clubId.isNotEmpty == true
      ? widget.scenario!.clubId
      : (widget.clubs.length == 1 ? widget.clubs.first.id : null);

  late BookingPolicy _policy = widget.scenario?.policy ?? const BookingPolicy();
  late final _windowDaysController = TextEditingController(
    text: _policy.bookingWindowDays.toString(),
  );
  late final _peakLimitController = TextEditingController(
    text: _policy.peakHourLimit?.toString() ?? '',
  );
  late final _offPeakLimitController = TextEditingController(
    text: _policy.offPeakHourLimit?.toString() ?? '',
  );
  late final _maxPerDayController = TextEditingController(
    text: _policy.maxSlotsPerDay?.toString() ?? '',
  );
  late final _maxPerWeekController = TextEditingController(
    text: _policy.maxSlotsPerWeek?.toString() ?? '',
  );
  bool _isSaving = false;
  bool _isDeleting = false;

  bool get _isEditing => widget.scenario != null;

  @override
  void dispose() {
    _nameController.dispose();
    _windowDaysController.dispose();
    _peakLimitController.dispose();
    _offPeakLimitController.dispose();
    _maxPerDayController.dispose();
    _maxPerWeekController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _nameController.text.trim().isNotEmpty &&
      _clubId != null &&
      int.tryParse(_windowDaysController.text.trim()) != null &&
      int.parse(_windowDaysController.text.trim()) > 0;

  /// Empty text means "unlimited" (`null`); anything else must parse as an
  /// int — an unparsable value also falls back to "unlimited" rather than
  /// blocking save, since these fields are always optional.
  int? _parseOptionalLimit(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  Future<void> _save() async {
    if (!_isValid) return;
    setState(() => _isSaving = true);

    final scenario = BookingScenario(
      id: _scenarioId,
      clubId: _clubId ?? '',
      name: _nameController.text.trim(),
      policy: _policy.copyWith(
        bookingWindowDays: int.parse(_windowDaysController.text.trim()),
        peakHourLimit: () => _parseOptionalLimit(_peakLimitController),
        offPeakHourLimit: () => _parseOptionalLimit(_offPeakLimitController),
        maxSlotsPerDay: () => _parseOptionalLimit(_maxPerDayController),
        maxSlotsPerWeek: () => _parseOptionalLimit(_maxPerWeekController),
      ),
    );

    final ok = await ref
        .read(managerViewModelProvider.notifier)
        .saveScenario(scenario, isNew: !_isEditing);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (ok) Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _delete() async {
    final scenario = widget.scenario;
    if (scenario == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce scénario ?'),
        content: Text(
          '"${scenario.name}" sera définitivement supprimé. Les terrains qui '
          'l\'utilisent repasseront aux règles par défaut.',
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
        .deleteScenario(scenario.id, scenario.name);
    if (!mounted) return;
    setState(() => _isDeleting = false);
    if (ok) Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.clubs.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          scrolledUnderElevation: 0,
          title: const Text('Scénario'),
          leading: GestureDetector(
            onTap: () => Navigator.of(context, rootNavigator: true).pop(),
            child: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Text(
              "Tu n'es membre d'aucun club, tu ne peux donc pas gérer de scénario.",
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
        title: Text(_isEditing ? 'Modifier le scénario' : 'Ajouter un scénario'),
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
          _Label('Nom du scénario'),
          _TextField(
            controller: _nameController,
            hint: 'Weekend, Heures de pointe...',
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
          _Label('Jours affichés à l\'avance'),
          _TextField(
            controller: _windowDaysController,
            hint: '10',
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Heures creuses / pleines activées',
                  style: AppTypography.labelLarge,
                ),
              ),
              Switch(
                value: _policy.peakHoursEnabled,
                onChanged: (v) => setState(
                  () => _policy = _policy.copyWith(peakHoursEnabled: v),
                ),
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
          if (_policy.peakHoursEnabled) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Label('Max heures pleines en cours'),
                      const SizedBox(height: AppSpacing.sm),
                      _TextField(
                        controller: _peakLimitController,
                        hint: 'Illimité',
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Label('Max heures creuses en cours'),
                      const SizedBox(height: AppSpacing.sm),
                      _TextField(
                        controller: _offPeakLimitController,
                        hint: 'Illimité',
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Label('Créneaux max / jour'),
                    const SizedBox(height: AppSpacing.sm),
                    _TextField(
                      controller: _maxPerDayController,
                      hint: 'Illimité',
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Label('Créneaux max / semaine'),
                    const SizedBox(height: AppSpacing.sm),
                    _TextField(
                      controller: _maxPerWeekController,
                      hint: 'Illimité',
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_maxPerWeekController.text.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(
                      () => _policy = _policy.copyWith(
                        weekPeriod: WeekPeriod.calendar,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _policy.weekPeriod == WeekPeriod.calendar
                          ? AppColors.primary
                          : null,
                      foregroundColor:
                          _policy.weekPeriod == WeekPeriod.calendar
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                    child: const Text('Semaine calendaire'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(
                      () => _policy = _policy.copyWith(
                        weekPeriod: WeekPeriod.rolling,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _policy.weekPeriod == WeekPeriod.rolling
                          ? AppColors.primary
                          : null,
                      foregroundColor: _policy.weekPeriod == WeekPeriod.rolling
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                    child: const Text('Fenêtre glissante 7j'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: _isEditing ? 'Enregistrer' : 'Créer le scénario',
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
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const _TextField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
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
