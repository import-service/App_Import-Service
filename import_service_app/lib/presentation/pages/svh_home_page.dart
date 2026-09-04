import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:import_service_app/core/app_update/app_update_service.dart';
import 'package:import_service_app/core/auth/auth_session_controller.dart';
import 'package:import_service_app/core/auth/auth_service.dart';
import 'package:import_service_app/core/auth/session_preferences_keys.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/error/exceptions.dart';
import 'package:import_service_app/core/i18n/app_locale.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/ui/app_feedback_kind.dart';
import 'package:import_service_app/core/ui/app_feedback_service.dart';
import 'package:import_service_app/data/models/registration_request_model.dart';
import 'package:import_service_app/presentation/bloc/car_inventory/car_inventory_cubit.dart';
import 'package:import_service_app/presentation/bloc/chat_list/chat_list_cubit.dart';
import 'package:import_service_app/presentation/bloc/request_chat_unread/request_chat_unread_cubit.dart';
import 'package:import_service_app/presentation/bloc/request_draft/request_draft_cubit.dart';
import 'package:import_service_app/presentation/pages/svh_qr_scan_page.dart';
import 'package:import_service_app/presentation/widgets/app_bar/brand_primary_app_bar.dart';
import 'package:import_service_app/presentation/widgets/bottom_sheets/logout_confirm_bottom_sheet.dart';
import 'package:import_service_app/presentation/widgets/navigation/svh_bottom_nav_bar.dart';
import 'package:import_service_app/presentation/widgets/tabs/profile_tab_view.dart';
import 'package:import_service_app/presentation/widgets/tabs/svh_cars_tab_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shell менеджера СВХ: отдельные экраны от клиентского [HomePage].
class SvhHomePage extends StatefulWidget {
  const SvhHomePage({super.key});

  @override
  State<SvhHomePage> createState() => _SvhHomePageState();
}

class _SvhHomePageState extends State<SvhHomePage> {
  static const int _tabCars = 0;
  static const int _tabProfile = 1;

  final GlobalKey<SvhCarsTabViewState> _carsTabKey =
      GlobalKey<SvhCarsTabViewState>();

  int _tabIndex = _tabCars;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (sl<AuthSessionController>().isAuthenticated) {
        unawaited(() async {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          if (!mounted) return;
          await sl<AppUpdateService>().maybePromptForUpdate(context);
        }());
      }
    });
  }

  Future<void> _openQrScanner() async {
    final vin = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const SvhQrScanPage()),
    );
    if (!mounted || vin == null || vin.trim().isEmpty) return;
    setState(() => _tabIndex = _tabCars);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _carsTabKey.currentState?.applyVinSearch(vin.trim());
    });
  }

  Future<void> _clearPrefsKeepLanguage() async {
    final prefs = sl<SharedPreferences>();
    final lang = prefs.getString('app_language');
    final lastEmail = prefs.getString(SessionPreferencesKeys.authLastEmail);
    final lastPassword = prefs.getString(SessionPreferencesKeys.authLastPassword);
    await prefs.clear();
    if (lang != null) {
      await prefs.setString('app_language', lang);
    }
    if (lastEmail != null) {
      await prefs.setString(SessionPreferencesKeys.authLastEmail, lastEmail);
    }
    if (lastPassword != null) {
      await prefs.setString(SessionPreferencesKeys.authLastPassword, lastPassword);
    }
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await LogoutConfirmBottomSheet.show(context);
    if (!confirmed || !context.mounted) return;

    final strings = sl<JsonStringsService>();
    final session = sl<AuthSessionController>();
    try {
      if (session.isAuthenticated) {
        await sl<AuthService>().logout();
      } else {
        session.clear();
      }
      await _clearPrefsKeepLanguage();
      await sl<RequestDraftCubit>().clearAll();
      await sl<CarInventoryCubit>().reloadFromDisk();
      sl<RequestChatUnreadCubit>().clearAll();
      sl<ChatListCubit>().reset();
      sl<AppUpdateService>().resetSessionFlag();
      if (!context.mounted) return;
      context.go('/login');
    } on ServerException catch (e) {
      if (!context.mounted) return;
      sl<AppFeedbackService>().show(e.message, kind: AppFeedbackKind.error);
    } catch (_) {
      if (!context.mounted) return;
      sl<AppFeedbackService>().show(
        strings.logoutUnknownError,
        kind: AppFeedbackKind.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        appLocale,
        sl<AuthSessionController>(),
      ]),
      builder: (context, _) {
        final strings = sl<JsonStringsService>();
        final session = sl<AuthSessionController>();

        final isPersonApplicant =
            OrganizationTypeInn.tryParse(session.orgType) ==
            OrganizationType.person;
        final displayName = (session.companyName?.trim().isNotEmpty == true
                ? session.companyName!.trim()
                : session.login?.trim()) ??
            '—';

        final appBarTitle = _tabIndex == _tabProfile
            ? strings.profileTabTitle
            : strings.text('svhCarsTabTitle');

        return Scaffold(
          appBar: BrandPrimaryAppBar(
            title: appBarTitle,
            automaticallyImplyLeading: false,
            leading: _tabIndex == _tabCars
                ? IconButton(
                    onPressed: _openQrScanner,
                    icon: const Icon(Icons.qr_code_scanner),
                    tooltip: strings.text('svhQrScanTooltip'),
                  )
                : null,
          ),
          body: IndexedStack(
            index: _tabIndex,
            children: [
              SvhCarsTabView(key: _carsTabKey),
              ProfileTabView(
                isDemo: false,
                headlineTitle: displayName,
                isPersonApplicant: isPersonApplicant,
                managerLabel: strings.profileManagerLabel,
                phoneLabel: strings.profilePhoneLabel,
                emailLabel: strings.profileEmailLabel,
                companyLabel: strings.profileCompanyLabel,
                innLabel: strings.profileInnLabel,
                logoutLabel: strings.logoutButton,
                onLogout: () => _logout(context),
                companyName: session.companyName,
                inn: session.inn,
                phone: session.phone,
                email: session.email,
                managerName: session.managerName,
              ),
            ],
          ),
          bottomNavigationBar: SvhBottomNavBar(
            currentIndex: _tabIndex,
            carsLabel: strings.text('svhCarsTabTitle'),
            profileLabel: strings.profileTabTitle,
            onTap: (value) => setState(() => _tabIndex = value),
          ),
        );
      },
    );
  }
}
