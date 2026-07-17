import 'package:flutter/material.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/presentation/helpers/masked_field_validation.dart';
import 'package:import_service_app/presentation/widgets/forms/fields/app_clearable_labeled_field.dart';
import 'package:import_service_app/presentation/widgets/forms/input_formatters/phone_ru_input_formatter.dart';

/// Поле телефона РФ: `+7 (999) 000-00-00`, валидация, крестик очистки.
class AppPhoneRuField extends StatelessWidget {
  const AppPhoneRuField({
    super.key,
    required this.label,
    required this.controller,
    this.validator,
    this.markRequired = true,
    this.textInputAction,
    this.density = AppLabeledFieldDensity.request,
    this.validate = true,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final bool markRequired;
  final TextInputAction? textInputAction;
  final AppLabeledFieldDensity density;
  final bool validate;

  static const _hint = '+7 (999) 000-00-00';

  @override
  Widget build(BuildContext context) {
    final strings = sl<JsonStringsService>();

    return AppClearableLabeledField(
      label: label,
      hintText: _hint,
      controller: controller,
      keyboardType: TextInputType.phone,
      textInputAction: textInputAction,
      markRequired: markRequired,
      density: density,
      inputFormatters: [PhoneRuInputFormatter()],
      validator: validate
          ? (value) =>
              validator?.call(value) ??
              validateRuPhoneValue(value, strings)
          : null,
    );
  }
}
