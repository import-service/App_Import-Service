import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:import_service_app/core/auth/auth_service.dart';
import 'package:import_service_app/core/auth/auth_session_controller.dart';
import 'package:import_service_app/core/auth/session_role.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/error/exceptions.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/core/ui/app_feedback_kind.dart';
import 'package:import_service_app/core/ui/app_feedback_service.dart';

/// Переключатель активной роли (мульти-роль организации) в профиле.
class ProfileRoleSwitchSection extends StatefulWidget {
  const ProfileRoleSwitchSection({super.key});

  @override
  State<ProfileRoleSwitchSection> createState() =>
      _ProfileRoleSwitchSectionState();
}

class _ProfileRoleSwitchSectionState extends State<ProfileRoleSwitchSection> {
  bool _busy = false;

  Future<void> _onSelect(String role) async {
    final session = sl<AuthSessionController>();
    if (role == session.role || _busy) return;
    setState(() => _busy = true);
    final s = sl<JsonStringsService>();
    try {
      await sl<AuthService>().activateRole(role);
      if (!mounted) return;
      context.go(homeLocationForSession(sl<AuthSessionController>()));
      sl<AppFeedbackService>().show(
        s.text('profileRoleSwitched').replaceFirst('{role}', roleDisplayLabel(role)),
        kind: AppFeedbackKind.success,
      );
    } on ServerException catch (e) {
      if (!mounted) return;
      sl<AppFeedbackService>().show(e.message, kind: AppFeedbackKind.error);
    } catch (_) {
      if (!mounted) return;
      sl<AppFeedbackService>().show(
        s.text('profileRoleSwitchError'),
        kind: AppFeedbackKind.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sl<AuthSessionController>(),
      builder: (context, _) {
        final session = sl<AuthSessionController>();
        if (!session.hasMultipleRoles) return const SizedBox.shrink();
        final s = sl<JsonStringsService>();
        final roles = session.roles;
        final current = session.role ?? '';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.text('profileRoleSwitchLabel'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final role in roles)
                  ChoiceChip(
                    label: Text(roleDisplayLabel(role)),
                    selected: role == current,
                    onSelected: _busy
                        ? null
                        : (selected) {
                            if (selected) _onSelect(role);
                          },
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}
