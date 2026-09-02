import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/models/models.dart';
import '../../../data/providers/favorites_provider.dart';
import '../../atoms/atoms.dart';
import '../profile/profile_view_model.dart';

class BookingDetailScreen extends ConsumerStatefulWidget {
  final BookingModel booking;

  const BookingDetailScreen({super.key, required this.booking});

  @override
  ConsumerState<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends ConsumerState<BookingDetailScreen> {
  late BookingModel _booking;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(_booking.date);
    final partner = _booking.partnerId != null
        ? MockData.allUsers.where((u) => u.id == _booking.partnerId).firstOrNull
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: const Text('Détails réservation'),
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _StatusCard(booking: _booking),
          const SizedBox(height: AppSpacing.lg),
          _InfoSection(
            title: 'Terrain',
            icon: Icons.sports_tennis_rounded,
            children: [
              _InfoRow(label: 'Nom', value: _booking.courtName),
              if (_booking.courtAddress != null)
                _InfoRow(label: 'Adresse', value: _booking.courtAddress!),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _InfoSection(
            title: 'Créneau',
            icon: Icons.access_time_rounded,
            children: [
              _InfoRow(
                label: 'Date',
                value: _capitalize(dateStr),
              ),
              _InfoRow(
                label: 'Horaire',
                value: '${_booking.startTime} – ${_booking.endTime}',
              ),
              _InfoRow(label: 'Tarif', value: '${_booking.price.toInt()}€'),
            ],
          ),
          if (partner != null) ...[
            const SizedBox(height: AppSpacing.md),
            _InfoSection(
              title: 'Partenaire',
              icon: Icons.person_rounded,
              children: [
                _PartnerRow(partner: partner),
                _InfoRow(label: 'Classement', value: partner.ranking),
                _InfoRow(label: 'Localisation', value: partner.location),
              ],
            ),
          ],
          if (_booking.gateCode != null) ...[
            const SizedBox(height: AppSpacing.md),
            _GateCodeCard(code: _booking.gateCode!),
          ],
          if (_booking.score != null) ...[
            const SizedBox(height: AppSpacing.md),
            _InfoSection(
              title: 'Résultat',
              icon: Icons.emoji_events_rounded,
              children: [
                _InfoRow(
                  label: 'Score',
                  value: _booking.score!,
                ),
                if (_booking.result != null)
                  _InfoRow(
                    label: 'Issue',
                    value: _booking.result == BookingResult.win
                        ? 'Victoire 🏆'
                        : 'Défaite',
                  ),
              ],
            ),
          ],
          if (_booking.isUpcoming) ...[
            const SizedBox(height: AppSpacing.xl),
            _ActionButton(
              icon: Icons.person_add_alt_1_rounded,
              label: _booking.partnerId == null
                  ? 'Ajouter un partenaire'
                  : 'Modifier le partenaire',
              color: AppColors.primary,
              onTap: () => _showPartnerPicker(),
            ),
            const SizedBox(height: AppSpacing.md),
            _ActionButton(
              icon: Icons.cancel_outlined,
              label: 'Annuler la réservation',
              color: AppColors.error,
              onTap: () => _confirmCancel(),
            ),
          ],
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  void _showPartnerPicker() {
    final favorites = ref.read(favoritesProvider);
    final candidates = MockData.allUsers
        .where((u) => u.id != MockData.currentUser.id && !u.isAdmin)
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PartnerPickerSheet(
        users: candidates,
        selectedId: _booking.partnerId,
        favorites: favorites,
        onSelect: (user) {
          Navigator.of(context).pop();
          final updated = _booking.copyWith(
            partnerId: user.id,
            partnerName:
                '${user.name.split(' ').first} ${user.name.split(' ').last[0]}.',
          );
          setState(() => _booking = updated);
          ref.read(profileViewModelProvider.notifier).updateBooking(updated);
        },
      ),
    );
  }

  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler la réservation'),
        content: const Text(
          'Es-tu sûr de vouloir annuler cette réservation ? Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Annuler la réservation',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ref.read(profileViewModelProvider.notifier).cancelBooking(_booking.id);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Réservation annulée.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _StatusCard extends StatelessWidget {
  final BookingModel booking;
  const _StatusCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final isConfirmed = booking.status == BookingStatus.confirmed;
    final isPast = booking.isPast;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPast
              ? [AppColors.surfaceVariant, AppColors.surface]
              : [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isConfirmed ? Icons.check_circle_rounded : Icons.pending_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.courtName,
                  style: AppTypography.headlineMedium
                      .copyWith(color: Colors.white),
                ),
                Text(
                  isConfirmed ? 'Réservation confirmée' : 'En attente de confirmation',
                  style: AppTypography.bodySmall
                      .copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _InfoSection({
    required this.title,
    required this.icon,
    required this.children,
  });

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
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(title, style: AppTypography.headlineSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: AppTypography.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _PartnerRow extends StatelessWidget {
  final UserModel partner;
  const _PartnerRow({required this.partner});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text('Joueur',
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
          ),
          AppAvatar(initials: partner.initials, size: 28),
          const SizedBox(width: AppSpacing.sm),
          Text(partner.name, style: AppTypography.bodyMedium),
        ],
      ),
    );
  }
}

class _GateCodeCard extends StatelessWidget {
  final String code;
  const _GateCodeCard({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_open_rounded,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text("Code d'accès portail",
                  style: AppTypography.headlineSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: Text(
                    code,
                    style: AppTypography.headlineLarge.copyWith(
                      color: AppColors.primary,
                      letterSpacing: 4,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Code copié !'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: const Icon(Icons.copy_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Valable uniquement le jour de votre réservation.',
            style: AppTypography.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: AppSpacing.md),
            Text(label,
                style: AppTypography.headlineSmall.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

class _PartnerPickerSheet extends StatefulWidget {
  final List<UserModel> users;
  final String? selectedId;
  final List<String> favorites;
  final ValueChanged<UserModel> onSelect;

  const _PartnerPickerSheet({
    required this.users,
    required this.selectedId,
    required this.favorites,
    required this.onSelect,
  });

  @override
  State<_PartnerPickerSheet> createState() => _PartnerPickerSheetState();
}

class _PartnerPickerSheetState extends State<_PartnerPickerSheet> {
  String _query = '';
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<UserModel> get _filtered {
    final q = _query.toLowerCase().trim();
    return widget.users
        .where((u) =>
            q.isEmpty ||
            u.name.toLowerCase().contains(q) ||
            u.location.toLowerCase().contains(q) ||
            u.ranking.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.xxxl)),
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
            child: Text('Choisir un partenaire',
                style: AppTypography.headlineLarge),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: TextField(
              controller: _controller,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Rechercher un joueur…',
                hintStyle: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textTertiary),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusFull),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusFull),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusFull),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final user = _filtered[i];
                final isSelected = user.id == widget.selectedId;
                final isFav = widget.favorites.contains(user.id);
                return ListTile(
                  onTap: () => widget.onSelect(user),
                  leading: Stack(
                    children: [
                      AppAvatar(
                        initials: user.initials,
                        size: 44,
                        backgroundColor: isSelected
                            ? AppColors.primary
                            : AppColors.surfaceVariant,
                        textColor:
                            isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                      if (isFav)
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
                  title: Text(user.name, style: AppTypography.headlineSmall),
                  subtitle: Text('${user.location} · ${user.ranking}',
                      style: AppTypography.bodySmall),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle_rounded,
                          color: AppColors.primary)
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
