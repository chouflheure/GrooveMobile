import 'package:flutter/material.dart';

/// Shown on launch when the installed app version is below the one Remote
/// Config requires. Dismissible by tapping outside unless [mandatory] is
/// true, in which case there is no way to close it short of updating.
class UpdateRequiredDialog extends StatelessWidget {
  const UpdateRequiredDialog({super.key, required this.mandatory});

  final bool mandatory;

  static Future<void> show(BuildContext context, {required bool mandatory}) {
    return showDialog(
      context: context,
      barrierDismissible: !mandatory,
      builder: (_) => PopScope(
        canPop: !mandatory,
        child: UpdateRequiredDialog(mandatory: mandatory),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mise à jour disponible'),
      content: Text(
        mandatory
            ? 'Une nouvelle version de CourtConnect est disponible et est '
                  'nécessaire pour continuer à utiliser l\'application.'
            : 'Une nouvelle version de CourtConnect est disponible. '
                  'Nous vous recommandons de mettre à jour l\'application.',
      ),
      actions: [
        if (!mandatory)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Plus tard'),
          ),
        FilledButton(
          onPressed: () {
            // TODO: brancher les liens App Store / Play Store réels.
          },
          child: const Text('Mettre à jour'),
        ),
      ],
    );
  }
}
