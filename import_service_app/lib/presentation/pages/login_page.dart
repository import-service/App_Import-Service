import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:import_service_app/core/auth/auth_session_controller.dart';
import 'package:import_service_app/core/auth/auth_service.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/error/exceptions.dart';
import 'package:import_service_app/core/ui/app_feedback_kind.dart';
import 'package:import_service_app/core/ui/app_feedback_service.dart';
import 'package:import_service_app/core/auth/session_preferences_keys.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/logging/app_log.dart';
import 'package:import_service_app/domain/repositories/cars_repository.dart';
import 'package:import_service_app/domain/entities/car_list_item.dart';
import 'package:import_service_app/presentation/widgets/app_bar/brand_primary_app_bar.dart';
import 'package:import_service_app/presentation/widgets/app_bar/settings_app_bar_action.dart';
import 'package:import_service_app/presentation/widgets/auth/login_brand_logo.dart';
import 'package:import_service_app/presentation/widgets/bottom_sheets/registration_request_bottom_sheet.dart';
import 'package:import_service_app/presentation/widgets/buttons/app_accent_underlined_text_button.dart';
import 'package:import_service_app/presentation/widgets/buttons/app_primary_filled_wide_button.dart';
import 'package:import_service_app/presentation/widgets/buttons/app_primary_outlined_wide_button.dart';
import 'package:import_service_app/presentation/widgets/forms/app_labeled_text_field.dart';
import 'package:import_service_app/presentation/bloc/car_inventory/car_inventory_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loggingIn = false;
  static final RegExp _emailPattern = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  bool get _canSubmit {
    return _loginController.text.trim().isNotEmpty &&
        _passwordController.text.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _loginController.addListener(_onFieldsChanged);
    _passwordController.addListener(_onFieldsChanged);
    final prefs = sl<SharedPreferences>();
    _loginController.text = prefs.getString(SessionPreferencesKeys.authLastEmail) ?? '';
    _passwordController.text =
        prefs.getString(SessionPreferencesKeys.authLastPassword) ?? '';
  }

  void _onFieldsChanged() => setState(() {});

  bool _isValidEmail(String value) {
    if (value.contains('..')) {
      return false;
    }
    return _emailPattern.hasMatch(value);
  }

  @override
  void dispose() {
    _loginController.removeListener(_onFieldsChanged);
    _passwordController.removeListener(_onFieldsChanged);
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loggingIn) return;
    final strings = sl<JsonStringsService>();
    final login = _loginController.text.trim();
    final password = _passwordController.text;

    if (login.isEmpty || password.isEmpty) {
      sl<AppFeedbackService>().show(
        strings.fieldRequiredError,
        kind: AppFeedbackKind.warning,
      );
      return;
    }
    if (!_isValidEmail(login)) {
      sl<AppFeedbackService>().show(
        strings.emailFormatError,
        kind: AppFeedbackKind.warning,
      );
      return;
    }

    setState(() => _loggingIn = true);
    try {
      await sl<AuthService>().login(login: login, password: password);
      await sl<CarInventoryCubit>().replaceAll(const <CarListItem>[]);
      await sl<CarsRepository>().listVehicles();
      final prefs = sl<SharedPreferences>();
      await prefs.setString(SessionPreferencesKeys.authLastEmail, login);
      await prefs.setString(SessionPreferencesKeys.authLastPassword, password);
      if (!mounted) return;
      context.go('/home');
    } on ServerException catch (e) {
      if (!mounted) return;
      sl<AppFeedbackService>().show(e.message, kind: AppFeedbackKind.error);
    } catch (_) {
      if (!mounted) return;
      sl<AppFeedbackService>().show(
        strings.loginUnknownError,
        kind: AppFeedbackKind.error,
      );
    } finally {
      if (mounted) setState(() => _loggingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = sl<JsonStringsService>();

    return Scaffold(
      appBar: BrandPrimaryAppBar(
        title: strings.authTitle,
        actions: [SettingsAppBarAction(tooltip: strings.settingsTitle)],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  const Gap(45),
                  const LoginBrandLogo(),
                  const Gap(45),
                  AppLabeledTextField(
                    label: strings.emailLabel,
                    controller: _loginController,
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const Gap(14),
                  AppLabeledTextField(
                    label: strings.passwordLabel,
                    controller: _passwordController,
                    isPassword: true,
                    textInputAction: TextInputAction.done,
                  ),
                  const Gap(18),
                  AppPrimaryFilledWideButton(
                    label: strings.loginButton,
                    isLoading: _loggingIn,
                    onPressed: (_loggingIn || !_canSubmit) ? null : _login,
                  ),
                  const Gap(10),
                  AppAccentUnderlinedTextButton(
                    label: strings.demoLoginButton,
                    onPressed: () async {
                      AppLog.trace('demo: enableDemo + bootstrap', tag: 'Auth');
                      sl<AuthSessionController>().enableDemo();
                      final boot = await sl<CarsRepository>().bootstrapDemoRequests();
                      if (!context.mounted) return;
                      boot.fold(
                        (f) {
                          AppLog.error(
                            'demo bootstrap fail',
                            error: f,
                            tag: 'Auth',
                          );
                          sl<AuthSessionController>().clear();
                          sl<AppFeedbackService>().show(
                            f.message,
                            kind: AppFeedbackKind.error,
                          );
                        },
                        (_) {
                          AppLog.trace('demo: go /home', tag: 'Auth');
                          if (!context.mounted) return;
                          context.go('/home');
                        },
                      );
                    },
                  ),
                  const Gap(18),
                  Text(
                    strings.notClientYet,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Gap(10),
                  AppPrimaryOutlinedWideButton(
                    label: strings.submitRequestButton,
                    onPressed: () {
                      RegistrationRequestBottomSheet.show(context);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
