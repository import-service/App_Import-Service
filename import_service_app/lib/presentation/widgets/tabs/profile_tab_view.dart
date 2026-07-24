import 'package:flutter/material.dart';
import 'package:import_service_app/data/demo/demo_profile_snapshot.dart';
import 'package:import_service_app/presentation/widgets/auth/login_brand_logo.dart';
import 'package:import_service_app/presentation/widgets/buttons/app_logout_outlined_wide_button.dart';
import 'package:import_service_app/presentation/widgets/forms/input_formatters/inn_input_formatter.dart';
import 'package:import_service_app/presentation/widgets/forms/input_formatters/phone_ru_input_formatter.dart';
import 'package:import_service_app/presentation/widgets/profile/profile_meta_row.dart';
import 'package:import_service_app/presentation/widgets/profile/profile_placeholder_avatar.dart';

class ProfileTabView extends StatelessWidget {
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
  final String? companyName;
  final String? inn;
  final String? phone;
  final String? email;
  final String? managerName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        children: [
          if (isDemo)
            const LoginBrandLogo(widthFactor: 0.42)
          else
            const ProfilePlaceholderAvatar(usePhoto: false),
          const SizedBox(height: 12),
          Text(
            headlineTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: isDemo
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProfileMetaRow(
                          label: companyLabel,
                          value: DemoProfileSnapshot.companyName,
                        ),
                        ProfileMetaRow(
                          label: innLabel,
                          value: InnInputFormatter.formatDigits(
                            DemoProfileSnapshot.inn,
                            maxDigits: 10,
                          ),
                        ),
                        ProfileMetaRow(
                          label: managerLabel,
                          value: DemoProfileSnapshot.managerDisplayName,
                        ),
                        ProfileMetaRow(
                          label: phoneLabel,
                          value: DemoProfileSnapshot.phoneDisplay,
                        ),
                        ProfileMetaRow(
                          label: emailLabel,
                          value: DemoProfileSnapshot.email,
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isPersonApplicant &&
                            (companyName ?? '').trim().isNotEmpty)
                          ProfileMetaRow(
                            label: companyLabel,
                            value: companyName!.trim(),
                          ),
                        if ((inn ?? '').trim().isNotEmpty)
                          ProfileMetaRow(
                            label: innLabel,
                            value: InnInputFormatter.formatDigits(
                              inn!.trim(),
                              maxDigits: inn!.trim().length == 12 ? 12 : 10,
                            ),
                          ),
                        if ((managerName ?? '').trim().isNotEmpty)
                          ProfileMetaRow(
                            label: managerLabel,
                            value: managerName!.trim(),
                          ),
                        if ((phone ?? '').trim().isNotEmpty)
                          ProfileMetaRow(
                            label: phoneLabel,
                            value: PhoneRuInputFormatter.formatDisplay(phone),
                          ),
                        if ((email ?? '').trim().isNotEmpty)
                          ProfileMetaRow(
                            label: emailLabel,
                            value: email!.trim(),
                          ),
                      ],
                    ),
            ),
          ),
          AppLogoutOutlinedWideButton(
            label: logoutLabel,
            onPressed: onLogout,
          ),
        ],
      ),
    );
  }
}
