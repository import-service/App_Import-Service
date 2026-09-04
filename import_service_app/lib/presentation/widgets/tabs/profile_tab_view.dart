import 'package:flutter/material.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
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
  });

  final bool isDemo;
  /// Заголовок под аватаром: имя демо или логин пользователя.
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

  @override
  State<ProfileTabView> createState() => _ProfileTabViewState();
}

class _ProfileTabViewState extends State<ProfileTabView> {
  String? _versionLabel;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _versionLabel = '${info.version}+${info.buildNumber}';
      });
    } catch (_) {
      // версия опциональна
    }
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
                          if (widget.showCompany &&
                              !widget.isPersonApplicant &&
                              (widget.companyName ?? '').trim().isNotEmpty)
                            ProfileMetaRow(
                              label: widget.companyLabel,
                              value: widget.companyName!.trim(),
                            ),
                          if (widget.showInn &&
                              (widget.inn ?? '').trim().isNotEmpty)
                            ProfileMetaRow(
                              label: widget.innLabel,
                              value: InnInputFormatter.formatDigits(
                                widget.inn!.trim(),
                                maxDigits:
                                    widget.inn!.trim().length == 12 ? 12 : 10,
                              ),
                            ),
                          if (widget.showManager &&
                              (widget.managerName ?? '').trim().isNotEmpty)
                            ProfileMetaRow(
                              label: widget.managerLabel,
                              value: widget.managerName!.trim(),
                            ),
                          if ((widget.phone ?? '').trim().isNotEmpty &&
                              widget.phone!.trim() != '-')
                            ProfileMetaRow(
                              label: widget.phoneLabel,
                              value: PhoneRuInputFormatter.formatDisplay(
                                widget.phone,
                              ),
                            ),
                          if ((widget.email ?? '').trim().isNotEmpty)
                            ProfileMetaRow(
                              label: widget.emailLabel,
                              value: widget.email!.trim(),
                            ),
                        ],
                      ),
              ),
            ),
          ),
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
              '${s.text('profileAppVersionLabel')} $_versionLabel',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
