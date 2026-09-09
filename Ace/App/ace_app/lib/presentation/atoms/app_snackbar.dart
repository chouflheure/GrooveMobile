import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/material.dart';

enum AppSnackbarType { success, error, info }

/// App-wide snackbar look, built on `awesome_snackbar_content` — call this
/// instead of building a raw `SnackBar` directly, so every toast in the app
/// (errors, confirmations, info) shares the same style.
class AppSnackbar {
  AppSnackbar._();

  static void show(
    BuildContext context, {
    required String message,
    AppSnackbarType type = AppSnackbarType.info,
    String? title,
    Duration? duration,
  }) {
    final contentType = switch (type) {
      AppSnackbarType.success => ContentType.success,
      AppSnackbarType.error => ContentType.failure,
      AppSnackbarType.info => ContentType.help,
    };
    final resolvedTitle =
        title ??
        switch (type) {
          AppSnackbarType.success => 'Succès',
          AppSnackbarType.error => 'Erreur',
          AppSnackbarType.info => 'Info',
        };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          duration: duration ?? const Duration(seconds: 4),
          content: AwesomeSnackbarContent(
            title: resolvedTitle,
            message: message,
            contentType: contentType,
          ),
        ),
      );
  }
}
