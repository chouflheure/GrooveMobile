import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/models/models.dart';
import '../../atoms/atoms.dart';
import 'manager_view_model.dart';

/// Create/edit a tournament's own info — title, club, description, and
/// optionally its starting roster. Pass `tournament: null` to create a new
/// one (always starts in `TournamentStatus.registration`, no bracket yet).
/// Pre-selecting players here (rather than leaving the roster empty for
/// open self-registration) also skips the "nouveau tournoi" push to the
/// whole club on creation — see `functions/index.js`'s `onTournamentCreated`.
/// Further roster changes and the bracket itself are managed from
/// `TournamentManageScreen`, reached by tapping the tournament once it
/// exists.
class TournamentFormScreen extends ConsumerStatefulWidget {
  final TournamentModel? tournament;
  final List<ClubModel> clubs;
  final List<UserModel> players;

  const TournamentFormScreen({
    super.key,
    required this.tournament,
    required this.clubs,
    required this.players,
  });

  @override
  ConsumerState<TournamentFormScreen> createState() =>
      _TournamentFormScreenState();
}

class _TournamentFormScreenState extends ConsumerState<TournamentFormScreen> {
  late final _titleController = TextEditingController(
    text: widget.tournament?.title ?? '',
  );
  late final _descriptionController = TextEditingController(
    text: widget.tournament?.description ?? '',
  );
  late String? _clubId = widget.tournament?.clubId.isNotEmpty == true
      ? widget.tournament!.clubId
      : (widget.clubs.length == 1 ? widget.clubs.first.id : null);
  late final Set<String> _selectedPlayerIds = {
    ...?widget.tournament?.participantIds,
  };
  final _playerSearchController = TextEditingController();
  bool _isSaving = false;

  bool get _isEditing => widget.tournament != null;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _playerSearchController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _titleController.text.trim().isNotEmpty && _clubId != null;

  Future<void> _save() async {
    if (!_isValid) return;
    setState(() => _isSaving = true);

    final club = widget.clubs.firstWhere((c) => c.id == _clubId);
    final tournament = TournamentModel(
      id: widget.tournament?.id ?? '',
      clubId: club.id,
      clubName: club.name,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      status: widget.tournament?.status ?? TournamentStatus.registration,
      participantIds: _selectedPlayerIds.toList(),
      matches: widget.tournament?.matches ?? const [],
      createdAt: widget.tournament?.createdAt ?? DateTime.now(),
    );

    final ok = await ref
        .read(managerViewModelProvider.notifier)
        .saveTournament(tournament, isNew: !_isEditing);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (ok) Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.clubs.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          scrolledUnderElevation: 0,
          title: const Text('Tournoi'),
          leading: GestureDetector(
            onTap: () => Navigator.of(context, rootNavigator: true).pop(),
            child: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Text(
              "Tu n'es membre d'aucun club, tu ne peux donc pas créer de tournoi.",
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
        title: Text(_isEditing ? 'Modifier le tournoi' : 'Ajouter un tournoi'),
        leading: GestureDetector(
          onTap: () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _Label('Titre'),
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
          _Label('Joueurs'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _clubId == null
                ? 'Choisis un club pour voir ses membres.'
                : 'Optionnel — présélectionner des joueurs ici évite '
                      "d'envoyer une notification à tout le club à la "
                      'création (utile si tu constitues déjà la liste '
                      "toi-même plutôt que d'ouvrir les inscriptions).",
            style: AppTypography.bodySmall,
          ),
          if (_clubId != null) ...[
            const SizedBox(height: AppSpacing.sm),
            if (_selectedPlayerIds.isNotEmpty)
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: _selectedPlayerIds.map((id) {
                  final name = widget.players
                      .where((u) => u.id == id)
                      .firstOrNull
                      ?.name ??
                      id;
                  return Chip(
                    label: Text(name, style: AppTypography.labelMedium),
                    onDeleted: () =>
                        setState(() => _selectedPlayerIds.remove(id)),
                    backgroundColor: AppColors.primaryContainer,
                    deleteIconColor: AppColors.primary,
                  );
                }).toList(),
              ),
            const SizedBox(height: AppSpacing.sm),
            _TextField(
              controller: _playerSearchController,
              hint: 'Rechercher un membre du club...',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...widget.players
                .where((u) => u.clubIds.contains(_clubId))
                .where((u) => !_selectedPlayerIds.contains(u.id))
                .where(
                  (u) =>
                      _playerSearchController.text.trim().isEmpty ||
                      u.name.toLowerCase().contains(
                        _playerSearchController.text.trim().toLowerCase(),
                      ),
                )
                .take(8)
                .map(
                  (u) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(u.name, style: AppTypography.bodyMedium),
                    trailing: const Icon(
                      Icons.add_circle_rounded,
                      color: AppColors.primary,
                    ),
                    onTap: () =>
                        setState(() => _selectedPlayerIds.add(u.id)),
                  ),
                ),
          ],
          const SizedBox(height: AppSpacing.lg),
          _Label('Description'),
          _TextField(
            controller: _descriptionController,
            maxLines: 4,
            hint: 'Description du tournoi',
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: _isEditing ? 'Enregistrer' : 'Créer le tournoi',
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
