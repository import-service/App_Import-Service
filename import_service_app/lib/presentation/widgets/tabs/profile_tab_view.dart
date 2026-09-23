import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:import_service_app/core/app_update/app_update_service.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/logging/app_log.dart';
import 'package:import_service_app/core/push/push_ios_diagnostics.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/core/themes/app_theme_mode.dart';
import 'package:import_service_app/core/ui/app_feedback_kind.dart';
import 'package:import_service_app/core/ui/app_feedback_service.dart';
import 'package:import_service_app/data/demo/demo_profile_snapshot.dart';
import 'package:import_service_app/presentation/pages/feedback_page.dart';
import 'package:import_service_app/presentation/widgets/auth/login_brand_logo.dart';
import 'package:import_service_app/presentation/widgets/buttons/app_logout_outlined_wide_button.dart';
import 'package:import_service_app/presentation/widgets/buttons/app_primary_outlined_wide_button.dart';
import 'package:import_service_app/presentation/widgets/forms/input_formatters/inn_input_formatter.dart';
import 'package:import_service_app/presentation/widgets/forms/input_formatters/phone_ru_input_formatter.dart';
import 'package:import_service_app/presentation/widgets/profile/profile_meta_row.dart';
import 'package:import_service_app/presentation/widgets/profile/profile_placeholder_avatar.dart';
import 'package:import_service_app/presentation/widgets/profile/profile_role_switch_section.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileTabView extends StatefulWidget {
  const ProfileTabView({
    super.key,
    required this.isDemo,
    required this.headlineTitle,
    required this.managerLabel,
    required this.phoneLabel,
    required this.emailLabel,
    required this.companyLabel,
    required this.innLabel,
    required this.logoutLabel,
    required this.onLogout,
    this.isPersonApplicant = false,
    this.showInn = true,
    this.showManager = true,
    this.showCompany = true,
    this.companyName,
    this.inn,
    this.phone,
    this.email,
    this.managerName,
    /// Вкладка сейчас видима (IndexedStack). При каждом показе — refresh версии APK.
    this.isActive = true,
  });

  final bool isDemo;
  /// Заголовок под аватаром: наименование орг / демо-имя (не email).
  final String headlineTitle;
  final String managerLabel;
  final String phoneLabel;
  final String emailLabel;
  final String companyLabel;
  final String innLabel;
  final String logoutLabel;
  final VoidCallback onLogout;
  /// Заявитель — физическое лицо: без строки «Название компании».
  final bool isPersonApplicant;
  /// Скрыть ИНН (профиль менеджера СВХ).
  final bool showInn;
  /// Скрыть строку менеджера 1С.
  final bool showManager;
  /// Показать название компании (для юрлица клиента).
  final bool showCompany;
  final String? companyName;
  final String? inn;
  final String? phone;
  final String? email;
  final String? managerName;
  final bool isActive;

  @override
  State<ProfileTabView> createState() => _ProfileTabViewState();
}

class _ProfileTabViewState extends State<ProfileTabView> {
  String? _versionLabel;
  String? _serverVersionLabel;
  String? _googlePlayVersionLabel;
  String? _ruStoreVersionLabel;
  String? _appStoreVersionLabel;
  bool _serverApkAvailable = false;
  bool _serverUpdateBusy = false;

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;
  bool get _isIos => !kIsWeb && Platform.isIOS;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      unawaited(_loadVersions());
    } else {
      unawaited(_loadLocalVersionOnly());
    }
  }

  @override
  void didUpdateWidget(covariant ProfileTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      unawaited(_loadVersions());
    }
  }

  Future<void> _loadLocalVersionOnly() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _versionLabel = '${info.version}+${info.buildNumber}';
      });
    } catch (_) {}
  }

  Future<void> _loadVersions() async {
    if (widget.isDemo) {
      await _loadLocalVersionOnly();
      return;
    }
    try {
      final snap = await sl<AppUpdateService>().loadProfileVersionInfo();
      if (!mounted) return;
      setState(() {
        _versionLabel = snap.localLabel;
        _serverVersionLabel = _isAndroid ? snap.serverApkLabel : null;
        _googlePlayVersionLabel = _isAndroid ? snap.googlePlayLabel : null;
        _ruStoreVersionLabel = _isAndroid ? snap.ruStoreLabel : null;
        _appStoreVersionLabel = _isIos ? snap.appStoreLabel : null;
        _serverApkAvailable =
            _isAndroid && (snap.serverApkLabel?.trim().isNotEmpty ?? false);
      });
    } catch (e, st) {
      AppLog.error(
        'profile version load failed',
        tag: 'Profile',
        error: e,
        stackTrace: st,
      );
      await _loadLocalVersionOnly();
      if (!mounted) return;
      setState(() {
        _serverApkAvailable = false;
        _serverVersionLabel = null;
        _googlePlayVersionLabel = null;
        _ruStoreVersionLabel = null;
        _appStoreVersionLabel = null;
      });
    }
  }

  Future<bool> _confirmSameOrOlderInstall() async {
    final s = sl<JsonStringsService>();
    final local = _versionLabel ?? '—';
    final server = _serverVersionLabel ?? '—';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.text('appUpdateServerSameOrOlderTitle')),
        content: Text(
          s
              .text('appUpdateServerSameOrOlderBody')
              .replaceAll('{server}', server)
              .replaceAll('{local}', local),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.text('appUpdateServerSameOrOlderCancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.text('appUpdateServerSameOrOlderConfirm')),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _onServerUpdate() async {
    if (!_isAndroid || _serverUpdateBusy) return;
    setState(() => _serverUpdateBusy = true);
    try {
      final newer = await sl<AppUpdateService>().isServerApkUpdateAvailable();
      if (!mounted) return;
      if (!newer) {
        final confirmed = await _confirmSameOrOlderInstall();
        if (!confirmed || !mounted) return;
      }
      await sl<AppUpdateService>().installFromServer(context);
      if (!mounted) return;
      await _loadVersions();
    } finally {
      if (mounted) setState(() => _serverUpdateBusy = false);
    }
  }

  String _displayOrEmpty(String? raw, JsonStringsService s) {
    final v = (raw ?? '').trim();
    if (v.isEmpty || v == '-') return s.text('profileEmptyValue');
    return v;
  }

  Future<void> _onThemeMode(Set<ThemeMode> selection) async {
    if (selection.isEmpty) return;
    await setAppThemeMode(sl<SharedPreferences>(), selection.first);
  }

  @override
  Widget build(BuildContext context) {
    final s = sl<JsonStringsService>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        children: [
          if (widget.isDemo)
            const LoginBrandLogo(widthFactor: 0.42)
          else
            const ProfilePlaceholderAvatar(usePhoto: false),
          const SizedBox(height: 12),
          Text(
            widget.headlineTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: SingleChildScrollView(
                child: widget.isDemo
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ProfileMetaRow(
                            label: widget.companyLabel,
                            value: DemoProfileSnapshot.companyName,
                          ),
                          ProfileMetaRow(
                            label: widget.innLabel,
                            value: InnInputFormatter.formatDigits(
                              DemoProfileSnapshot.inn,
                              maxDigits: 10,
                            ),
                          ),
                          ProfileMetaRow(
                            label: widget.managerLabel,
                            value: DemoProfileSnapshot.managerDisplayName,
                          ),
                          ProfileMetaRow(
                            label: widget.phoneLabel,
                            value: DemoProfileSnapshot.phoneDisplay,
                          ),
                          ProfileMetaRow(
                            label: widget.emailLabel,
                            value: DemoProfileSnapshot.email,
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.showCompany && !widget.isPersonApplicant)
                            ProfileMetaRow(
                              label: widget.companyLabel,
                              value: _displayOrEmpty(widget.companyName, s),
                            ),
                          if (widget.showInn &&
                              (widget.inn ?? '').trim().isNotEmpty)
                            ProfileMetaRow(
                              label: () {
                                final digits = widget.inn!
                                    .replaceAll(RegExp(r'\D'), '');
                                return digits.length == 10
                                    ? s.text('innLabelLegal')
                                    : s.text('innLabelPerson');
                              }(),
                              value: InnInputFormatter.formatDigits(
                                widget.inn!.trim(),
                                maxDigits:
                                    widget.inn!.trim().replaceAll(RegExp(r'\D'), '').length ==
                                            12
                                        ? 12
                                        : 10,
                              ),
                            ),
                          if (widget.showManager &&
                              (widget.managerName ?? '').trim().isNotEmpty)
                            ProfileMetaRow(
                              label: widget.managerLabel,
                              value: widget.managerName!.trim(),
                            ),
                          ProfileMetaRow(
                            label: widget.phoneLabel,
                            value: () {
                              final phone = (widget.phone ?? '').trim();
                              if (phone.isEmpty || phone == '-') {
                                return s.text('profileEmptyValue');
                              }
                              return PhoneRuInputFormatter.formatDisplay(phone);
                            }(),
                          ),
                          ProfileMetaRow(
                            label: widget.emailLabel,
                            value: _displayOrEmpty(widget.email, s),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const ProfileRoleSwitchSection(),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              s.text('profileThemeLabel'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: appThemeMode,
            builder: (context, mode, _) {
              return SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  segments: [
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.light,
                      label: Text(s.text('profileThemeLight')),
                      tooltip: s.text('profileThemeLight'),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.dark,
                      label: Text(s.text('profileThemeDark')),
                      tooltip: s.text('profileThemeDark'),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.system,
                      label: Text(s.text('profileThemeSystem')),
                      tooltip: s.text('profileThemeSystem'),
                    ),
                  ],
                  selected: {mode},
                  onSelectionChanged: _onThemeMode,
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          if (_isAndroid && _serverApkAvailable)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppPrimaryOutlinedWideButton(
                label: s.text('appUpdateServerProfileButton'),
                onPressed: _serverUpdateBusy ? null : _onServerUpdate,
              ),
            ),
          AppPrimaryOutlinedWideButton(
            label: s.text('feedbackMenuTitle'),
            onPressed: () {
              if (widget.isDemo) {
                sl<AppFeedbackService>().show(
                  s.text('feedbackDemoUnavailable'),
                  kind: AppFeedbackKind.error,
                );
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const FeedbackPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          AppLogoutOutlinedWideButton(
            label: widget.logoutLabel,
            onPressed: widget.onLogout,
          ),
          if (_versionLabel != null) ...[
            const SizedBox(height: 12),
            Text(
              _buildVersionFooter(s),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ],
          if (_isIos) ...[
            const SizedBox(height: 12),
            Text(
              s.text('profilePushDiagnosticsTitle'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 6),
            SelectableText(
              PushIosDiagnostics.text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontFamily: 'monospace',
                    fontSize: 11,
                    height: 1.35,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  String _buildVersionFooter(JsonStringsService s) {
    final local = _versionLabel ?? '—';
    final parts = <String>[
      '${s.text('profileAppVersionLabel')} $local',
    ];
    if (_isAndroid) {
      final server = _serverVersionLabel?.trim();
      if (server != null && server.isNotEmpty) {
        parts.add(
          s.text('profileServerVersionParen').replaceAll('{version}', server),
        );
      }
      final play = _googlePlayVersionLabel?.trim();
      if (play != null && play.isNotEmpty) {
        parts.add(
          s.text('profileGooglePlayVersionParen').replaceAll('{version}', play),
        );
      }
      final ru = _ruStoreVersionLabel?.trim();
      if (ru != null && ru.isNotEmpty) {
        parts.add(
          s.text('profileRuStoreVersionParen').replaceAll('{version}', ru),
        );
      }
    } else if (_isIos) {
      final appStore = _appStoreVersionLabel?.trim();
      if (appStore != null && appStore.isNotEmpty) {
        parts.add(
          s.text('profileAppStoreVersionParen').replaceAll('{version}', appStore),
        );
      }
    }
    return parts.join(' · ');
  }
}
