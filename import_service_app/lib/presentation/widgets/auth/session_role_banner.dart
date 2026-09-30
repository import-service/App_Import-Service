import 'package:flutter/material.dart';
import 'package:import_service_app/core/auth/auth_session_controller.dart';
import 'package:import_service_app/core/auth/session_role.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/themes/app_theme.dart';

/// Явная подпись: под какой ролью открыта сессия (клиент / СВХ / декларант).
class SessionRoleBanner extends StatelessWidget {
  const SessionRoleBanner({super.key, this.dense = false});

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final session = sl<AuthSessionController>();
    final s = sl<JsonStringsService>();
    final roleCode = session.isDemo ? kUserRole : (session.role ?? kUserRole);
    final roleLabel = roleDisplayLabel(roleCode);
    final text =
        s.text('sessionRoleSignedInAs').replaceAll('{role}', roleLabel);

    return Material(
      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: dense ? 6 : 10,
        ),
        child: Row(
          children: [
            Icon(
              Icons.badge_outlined,
              size: dense ? 18 : 20,
              color: AppTheme.primaryBlue,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryBlue,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
