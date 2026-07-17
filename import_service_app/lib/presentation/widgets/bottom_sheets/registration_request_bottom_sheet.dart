import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/error/exceptions.dart';
import 'package:import_service_app/core/ui/app_feedback_kind.dart';
import 'package:import_service_app/core/ui/app_feedback_service.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/core/ui/app_form_behavior.dart';
import 'package:import_service_app/data/datasources/remote/registration_request_remote_data_source.dart';
import 'package:import_service_app/data/models/registration_request_model.dart';
import 'package:import_service_app/presentation/helpers/masked_field_validation.dart';
import 'package:import_service_app/presentation/widgets/bottom_sheets/app_modal_bottom_sheet.dart';
import 'package:import_service_app/presentation/widgets/bottom_sheets/sheet_header.dart';
import 'package:import_service_app/presentation/widgets/buttons/app_primary_filled_wide_button.dart';
import 'package:import_service_app/presentation/widgets/forms/app_labeled_text_field.dart';
import 'package:import_service_app/presentation/widgets/forms/fields/app_clearable_labeled_field.dart';
import 'package:import_service_app/presentation/widgets/forms/fields/app_inn_field.dart';
import 'package:import_service_app/presentation/widgets/forms/fields/app_phone_ru_field.dart';
import 'package:import_service_app/presentation/widgets/forms/input_formatters/inn_input_formatter.dart';
import 'package:import_service_app/presentation/widgets/selection/organization_type_selector.dart';

class RegistrationRequestBottomSheet extends StatefulWidget {
  const RegistrationRequestBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return AppModalBottomSheet.show<void>(
      context: context,
      materialColor: AppTheme.pageBackground,
      child: const RegistrationRequestBottomSheet(),
    );
  }

  @override
  State<RegistrationRequestBottomSheet> createState() =>
      _RegistrationRequestBottomSheetState();
}

class _RegistrationRequestBottomSheetState
    extends State<RegistrationRequestBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _innController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  OrganizationType _organizationType = OrganizationType.ooo;
  bool _submitting = false;

  void _clampInnToOrgType() =>
      clampInnController(_innController, _organizationType);

  void _onFieldChanged() => setState(() {});

  /// См. [AppFormBehavior] — «ввод начат» = не пустая форма (телефон: больше чем `+7`).
  bool get _userStartedInput {
    if (_nameController.text.trim().isNotEmpty) return true;
    if (innDigitsOnly(_innController.text).isNotEmpty) return true;
    final phoneDigits = ruPhoneDigitsOnly(_phoneController.text);
    if (phoneDigits.length > 1) return true;
    if (_emailController.text.trim().isNotEmpty) return true;
    return false;
  }

  /// Совпадает с validator-ами полей — без дублирования правил не включать кнопку.
  bool get _canSubmit {
    final strings = sl<JsonStringsService>();
    final name = _nameController.text.trim();
    if (name.isEmpty) return false;

    final inn = innDigitsOnly(_innController.text);
    if (validateInnValue(inn, _organizationType, strings) != null) return false;

    if (validateRuPhoneValue(_phoneController.text, strings) != null) return false;

    final email = _emailController.text.trim();
    if (email.isEmpty) return false;
    if (!_isValidEmailFormat(email)) return false;

    return true;
  }

  @override
  void initState() {
    super.initState();
    _phoneController.text = '+7';
    _nameController.addListener(_onFieldChanged);
    _innController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFieldChanged);
    _innController.removeListener(_onFieldChanged);
    _phoneController.removeListener(_onFieldChanged);
    _emailController.removeListener(_onFieldChanged);
    _nameController.dispose();
    _innController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_canSubmit) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    final strings = sl<JsonStringsService>();

    final normalizedPhone = normalizeRuPhoneForApi(_phoneController.text);
    final normalizedInn = innDigitsOnly(_innController.text);
    final request = RegistrationRequestModel(
      organizationType: _organizationType,
      companyOrFullName: _nameController.text.trim(),
      inn: normalizedInn,
      phone: normalizedPhone,
      email: _emailController.text.trim(),
    );

    try {
      final message = await sl<RegistrationRequestRemoteDataSource>().send(
        request,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      sl<AppFeedbackService>().show(
        message,
        kind: AppFeedbackKind.success,
      );
    } on ServerException catch (e) {
      if (!mounted) return;
      sl<AppFeedbackService>().show(e.message, kind: AppFeedbackKind.error);
    } catch (_) {
      if (!mounted) return;
      sl<AppFeedbackService>().show(
        strings.requestUnknownError,
        kind: AppFeedbackKind.error,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = sl<JsonStringsService>();

    return Form(
      key: _formKey,
      autovalidateMode:
          AppFormBehavior.autovalidateMode(_userStartedInput),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(title: strings.requestSheetTitle),
          Text(
            strings.requestSheetSubtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const Gap(12),
          OrganizationTypeSelector(
            selected: _organizationType,
            onChanged: (value) => setState(() {
              _organizationType = value;
              _clampInnToOrgType();
            }),
            oooLabel: strings.orgTypeOoo,
            ipLabel: strings.orgTypeIp,
          ),
          const Gap(12),
          AppLabeledTextField(
            label: _organizationType == OrganizationType.ooo
                ? strings.companyNameLabel
                : strings.fullNameLabel,
            textCapitalization: TextCapitalization.sentences,
            controller: _nameController,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return strings.fieldRequiredError;
              }
              return null;
            },
            textInputAction: TextInputAction.next,
          ),
          const Gap(12),
          AppInnField(
            label: strings.innLabel,
            controller: _innController,
            organizationType: _organizationType,
            textInputAction: TextInputAction.next,
            density: AppLabeledFieldDensity.compact,
          ),
          const Gap(12),
          AppPhoneRuField(
            label: strings.phoneLabel,
            controller: _phoneController,
            textInputAction: TextInputAction.next,
            density: AppLabeledFieldDensity.compact,
          ),
          const Gap(12),
          AppLabeledTextField(
            label: strings.emailLabel,
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isEmpty) return strings.fieldRequiredError;
              if (!_isValidEmailFormat(email)) return strings.emailFormatError;
              return null;
            },
            textInputAction: TextInputAction.done,
          ),
          const Gap(16),
          AppPrimaryFilledWideButton(
            label: strings.submitRequestButton,
            isLoading: _submitting,
            onPressed: (_submitting || !_canSubmit) ? null : _submit,
          ),
        ],
      ),
    );
  }

  /// В т.ч. локальная часть с «+», цифрами и точкой ([\w] в Dart не даёт +).
  static bool _isValidEmailFormat(String email) {
    final e = email.trim();
    if (e.length < 5) return false;
    final at = e.indexOf('@');
    if (at <= 0 || at >= e.length - 1) return false;
    final local = e.substring(0, at);
    final domain = e.substring(at + 1);
    if (!domain.contains('.') || domain.startsWith('.') || domain.endsWith('.')) {
      return false;
    }
    final localOk = RegExp(r'^[a-zA-Z0-9._%+\-]+$').hasMatch(local);
    final domainOk = RegExp(r'^[a-zA-Z0-9.\-]+$').hasMatch(domain);
    return localOk && domainOk;
  }
}
