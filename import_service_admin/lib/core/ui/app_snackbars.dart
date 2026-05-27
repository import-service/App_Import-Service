import 'package:flutter/material.dart';
import 'package:import_service_admin/core/theme/app_theme.dart';
import 'package:import_service_admin/core/ui/app_scaffold_messenger_key.dart';

/// SnackBar через [appScaffoldMessengerKey] — виден поверх shell и нижнего меню.
abstract final class AppSnackBars {
  static const _duration = Duration(seconds: 4);

  static void showSuccess(
    String message, {
    BuildContext? context,
  }) {
    _show(
      message,
      backgroundColor: const Color(0xFF2E7D32),
      context: context,
    );
  }

  static void showError(
    String message, {
    BuildContext? context,
  }) {
    _show(
      message,
      backgroundColor: AppTheme.accentRed,
      context: context,
    );
  }

  static void _show(
    String message, {
    required Color backgroundColor,
    BuildContext? context,
  }) {
    final messenger = appScaffoldMessengerKey.currentState;
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(16, 0, 16, _bottomMargin(context)),
          duration: _duration,
        ),
      );
  }

  static double _bottomMargin(BuildContext? context) {
    if (context == null) return 24;
    final media = MediaQuery.sizeOf(context);
    final padding = MediaQuery.viewPaddingOf(context);
    var margin = padding.bottom + 16;
    if (media.width < 800) {
      margin += kBottomNavigationBarHeight;
    }
    return margin;
  }
}
