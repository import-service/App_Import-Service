import 'package:flutter/material.dart';
import 'package:import_service_app/core/auth/recent_account.dart';
import 'package:import_service_app/core/auth/recent_accounts_service.dart';
import 'package:import_service_app/core/auth/session_role.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/themes/app_theme.dart';

/// Список недавних входов: email + роль, новые сверху.
class RecentAccountsList extends StatefulWidget {
  const RecentAccountsList({
    super.key,
    required this.onSelect,
    this.enabled = true,
    this.excludeEmail,
  });

  final Future<void> Function(RecentAccount account) onSelect;
  final bool enabled;

  /// Если задан — эта строка без перехода (текущий аккаунт).
  final String? excludeEmail;

  @override
  State<RecentAccountsList> createState() => _RecentAccountsListState();
}

class _RecentAccountsListState extends State<RecentAccountsList> {
  List<RecentAccount>? _accounts;
  String? _busyEmail;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final items = await sl<RecentAccountsService>().list();
    if (!mounted) return;
    setState(() => _accounts = items);
  }

  Future<void> _onTap(RecentAccount account) async {
    if (!widget.enabled || _busyEmail != null) return;
    final exclude = (widget.excludeEmail ?? '').trim().toLowerCase();
    if (exclude.isNotEmpty && account.email == exclude) return;

    setState(() => _busyEmail = account.email);
    try {
      await widget.onSelect(account);
      if (mounted) await _reload();
    } finally {
      if (mounted) setState(() => _busyEmail = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = _accounts;
    if (accounts == null || accounts.isEmpty) {
      return const SizedBox.shrink();
    }

    final strings = sl<JsonStringsService>();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          strings.text('recentAccountsTitle'),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ...accounts.map((account) {
          final busy = _busyEmail == account.email;
          final exclude = (widget.excludeEmail ?? '').trim().toLowerCase();
          final isCurrent =
              exclude.isNotEmpty && account.email == exclude;
          final roleLabel = roleDisplayLabel(account.role);
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.55,
              ),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: (!widget.enabled || busy || isCurrent)
                    ? null
                    : () => _onTap(account),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              account.email,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              roleLabel,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (busy)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else if (!isCurrent)
                        Icon(
                          Icons.chevron_right_rounded,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
