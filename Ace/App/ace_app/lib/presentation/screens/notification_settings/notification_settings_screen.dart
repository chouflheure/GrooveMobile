import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _messages = false;
  bool _gameRequests = false;
  bool _slotReminder = false;
  bool _newSlotAvailable = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: const Text('Notifications'),
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _NotificationToggle(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Messages',
            subtitle: 'Recevoir des notifs de message',
            value: _messages,
            onChanged: (v) => setState(() => _messages = v),
          ),
          const SizedBox(height: AppSpacing.md),
          _NotificationToggle(
            icon: Icons.sports_tennis_rounded,
            label: 'Demandes de jeu',
            subtitle: 'Recevoir des notifs de demande de jeu',
            value: _gameRequests,
            onChanged: (v) => setState(() => _gameRequests = v),
          ),
          const SizedBox(height: AppSpacing.md),
          _NotificationToggle(
            icon: Icons.notifications_active_outlined,
            label: 'Rappel de créneau',
            subtitle: 'Recevoir des notifs 30 minutes avant créneau',
            value: _slotReminder,
            onChanged: (v) => setState(() => _slotReminder = v),
          ),
          const SizedBox(height: AppSpacing.md),
          _NotificationToggle(
            icon: Icons.event_available_rounded,
            label: 'Nouveaux créneaux',
            subtitle: 'Nouveau créneau dispo',
            value: _newSlotAvailable,
            onChanged: (v) => setState(() => _newSlotAvailable = v),
          ),
        ],
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
