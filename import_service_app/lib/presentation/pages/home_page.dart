import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:import_service_app/core/auth/auth_session_controller.dart';
import 'package:import_service_app/core/auth/auth_service.dart';
import 'package:import_service_app/core/auth/session_preferences_keys.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/navigation/home_cars_navigation_controller.dart';
import 'package:import_service_app/data/models/registration_request_model.dart';
import 'package:import_service_app/presentation/bloc/car_inventory/car_inventory_cubit.dart';
import 'package:import_service_app/presentation/bloc/request_draft/request_draft_cubit.dart';
import 'package:import_service_app/core/error/exceptions.dart';
import 'package:import_service_app/core/i18n/app_locale.dart';
import 'package:import_service_app/core/ui/app_feedback_kind.dart';
import 'package:import_service_app/core/ui/app_feedback_service.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/domain/repositories/cars_repository.dart';
import 'package:import_service_app/presentation/widgets/app_bar/brand_primary_app_bar.dart';
import 'package:import_service_app/presentation/widgets/app_bar/settings_app_bar_action.dart';
import 'package:import_service_app/presentation/widgets/bottom_sheets/logout_confirm_bottom_sheet.dart';
import 'package:import_service_app/presentation/pages/request_create_page.dart';
import 'package:import_service_app/presentation/widgets/navigation/home_bottom_nav_bar.dart';
import 'package:import_service_app/presentation/pages/cars_filters_page.dart';
import 'package:import_service_app/presentation/widgets/tabs/cars_tab_view.dart';
import 'package:import_service_app/presentation/widgets/tabs/profile_tab_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// Стартовый таб — «Мои авто» (индекс 1).
  int _tabIndex = 1;

  @override
  void initState() {
    super.initState();
    sl<HomeCarsNavigationController>().addListener(_onCarsNavigationIntent);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onCarsNavigationIntent());
  }

  @override
  void dispose() {
    sl<HomeCarsNavigationController>().removeListener(_onCarsNavigationIntent);
    super.dispose();
  }

  void _onCarsNavigationIntent() {
    final nav = sl<HomeCarsNavigationController>();
    if (!nav.focusCarsTab || !mounted) return;
    if (_tabIndex != 1) {
      setState(() => _tabIndex = 1);
    }
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

  Future<void> _refreshCars() async {
    await sl<CarsRepository>().listVehicles();
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
        final isDemo = session.isDemo;

        final isPersonApplicant =
            OrganizationTypeInn.tryParse(session.orgType) ==
            OrganizationType.person;
        final displayName = isDemo
            ? strings.demoClientName
            : (isPersonApplicant
                ? ((session.fullName?.trim().isNotEmpty == true
                        ? session.fullName!.trim()
                        : session.companyName?.trim()) ??
                    session.login?.trim() ??
                    '—')
                : ((session.companyName?.trim().isNotEmpty == true
                        ? session.companyName!.trim()
                        : session.login?.trim()) ??
                    '—'));

        final appBarTitle = _tabIndex == 0
            ? strings.profileTabTitle
            : strings.carsTabTitle;
        final appBarActions = _tabIndex == 1
            ? <Widget>[
                IconButton(
                  onPressed: () async => _refreshCars(),
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: strings.carsRefreshTooltip,
                ),
                IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CarsFiltersPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.tune_outlined),
                  tooltip: strings.carsFilterTooltip,
                ),
              ]
            : <Widget>[SettingsAppBarAction(tooltip: strings.settingsTitle)];

        return Scaffold(
          appBar: BrandPrimaryAppBar(
            title: appBarTitle,
            actions: appBarActions,
          ),
          body: IndexedStack(
            index: _tabIndex,
            children: [
              ProfileTabView(
                isDemo: isDemo,
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
              CarsTabView(
                key: ValueKey<bool>(isDemo),
                noDataText: strings.carsNoDataText,
                searchHint: strings.carsSearchHint,
                statuses: [
                  strings.carStatusInWork,
                  strings.carStatusOnWay,
                  strings.carStatusDelivered,
                ],
              ),
            ],
          ),
          floatingActionButton: _tabIndex == 1
              ? FloatingActionButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const RequestCreatePage(),
                      ),
                    );
                  },
                  tooltip: strings.carsAddButtonTooltip,
                  backgroundColor: AppTheme.accentRed,
                  foregroundColor: AppTheme.white,
                  shape: const CircleBorder(),
                  child: const Icon(Icons.add_rounded),
                )
              : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          bottomNavigationBar: HomeBottomNavBar(
            currentIndex: _tabIndex,
            profileLabel: strings.profileTabTitle,
            carsLabel: strings.carsTabTitle,
            onTap: (value) => setState(() => _tabIndex = value),
          ),
        );
      },
    );
  }
}
