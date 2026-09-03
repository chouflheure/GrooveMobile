import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/models/models.dart';
import '../../atoms/atoms.dart';
import 'manager_view_model.dart';

/// Create form for a club event — reached from the Manager screen's
/// "Événements" section.
class EventFormScreen extends ConsumerStatefulWidget {
  final List<ClubModel> clubs;
  final List<CourtModel> courts;

  const EventFormScreen({super.key, required this.clubs, required this.courts});

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();

  late String? _clubId = widget.clubs.length == 1 ? widget.clubs.first.id : null;
  DateTime? _date;
  final Set<String> _selectedCourtIds = {};
  bool _isSaving = false;

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
      _date != null;

  Future<void> _save() async {
    if (!_isValid) return;
    setState(() => _isSaving = true);

    final club = widget.clubs.firstWhere((c) => c.id == _clubId);
    final courtNames = widget.courts
        .where((c) => _selectedCourtIds.contains(c.id))
        .map((c) => c.name)
        .toList();

    final event = ClubEventModel(
      id: '',
      clubId: club.id,
      clubName: club.name,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      date: _date!,
      address: _addressController.text.trim(),
      courtNames: courtNames,
      createdAt: DateTime.now(),
    );

    final ok = await ref.read(managerViewModelProvider.notifier).createEvent(event);
    if (!mounted) return;
    setState(() => _isSaving = false);
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

    final courtsForClub = widget.courts.where((c) => c.clubId == _clubId).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: const Text('Créer un événement'),
        leading: GestureDetector(
          onTap: () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _Label('Titre'),
          const SizedBox(height: AppSpacing.sm),
          _TextField(controller: _titleController, hint: 'Tournoi de printemps'),
          const SizedBox(height: AppSpacing.lg),
          _Label('Club'),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String?>(
            initialValue: _clubId,
            hint: Text('Choisir un club', style: AppTypography.bodySmall),
            isExpanded: true,
            decoration: _decoration(),
            items: widget.clubs
                .map((c) => DropdownMenuItem<String?>(value: c.id, child: Text(c.name, style: AppTypography.bodyMedium)))
                .toList(),
            onChanged: (id) => setState(() {
              _clubId = id;
              _selectedCourtIds.clear();
            }),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Label('Description'),
          const SizedBox(height: AppSpacing.sm),
          _TextField(controller: _descriptionController, maxLines: 4, hint: "Description de l'événement"),
          const SizedBox(height: AppSpacing.lg),
          _Label('Date'),
          const SizedBox(height: AppSpacing.sm),
          GestureDetector(
            onTap: _pickDate,
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
                  Text(_date != null ? _fmt(_date!) : 'Choisir une date', style: AppTypography.bodySmall),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Label('Adresse'),
          const SizedBox(height: AppSpacing.sm),
          _TextField(controller: _addressController, hint: 'Paris 12e'),
          const SizedBox(height: AppSpacing.lg),
          _Label('Terrains pris'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Les terrains occupés par cet événement (informatif).',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (courtsForClub.isEmpty)
            Text('Choisis un club pour voir ses terrains.', style: AppTypography.bodySmall)
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
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.background,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                      border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
                    ),
                    child: Text(
                      c.name,
                      style: AppTypography.labelMedium.copyWith(
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Créer l\'événement',
            onTap: _isValid ? _save : null,
            isLoading: _isSaving,
          ),
          SizedBox(height: AppSpacing.xxl + MediaQuery.paddingOf(context).bottom),
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
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(text, style: AppTypography.labelLarge);
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  const _TextField({required this.controller, required this.hint, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
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
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      ),
    );
  }
}
