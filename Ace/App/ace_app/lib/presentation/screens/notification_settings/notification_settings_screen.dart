import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/models/models.dart';
import '../auth/auth_view_model.dart';

class _NotificationMeta {
  final IconData icon;
  final String subtitle;
  const _NotificationMeta(this.icon, this.subtitle);
}

const _kMeta = <String, _NotificationMeta>{
  'Messages': _NotificationMeta(
    Icons.chat_bubble_outline_rounded,
    'Recevoir des notifs de message',
  ),
  'Demandes de jeu': _NotificationMeta(
    Icons.sports_tennis_rounded,
    'Recevoir des notifs de demande de jeu',
  ),
  'Rappel de créneau': _NotificationMeta(
    Icons.notifications_active_outlined,
    'Recevoir des notifs 1 heure avant créneau',
  ),
  'Nouveaux créneaux': _NotificationMeta(
    Icons.event_available_rounded,
    'Nouveau créneau dispo',
  ),
};

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  Future<void> _toggle(WidgetRef ref, UserModel user, String key, bool value) {
    final notifications = {...user.notifications, key: value};
    return ref
        .read(userRepositoryProvider)
        .update(user.copyWith(notifications: notifications));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: const Text('Notifications'),
        leading: GestureDetector(
          onTap: () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: user == null
          ? Center(
              child: Text(
                'Connecte-toi pour gérer tes notifications.',
                style: AppTypography.bodySmall,
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
              ),
              itemCount: kNotificationKeys.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (_, i) {
                final key = kNotificationKeys[i];
                final meta = _kMeta[key]!;
                return _NotificationToggle(
                  icon: meta.icon,
                  label: key,
                  subtitle: meta.subtitle,
                  value: user.isNotificationEnabled(key),
                  onChanged: (v) => _toggle(ref, user, key, v),
                );
              },
            ),
    );
  }
}

class _NotificationToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotificationToggle({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
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
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.textPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(icon, color: AppColors.textPrimary, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.headlineSmall),
                Text(subtitle, style: AppTypography.bodySmall),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}
