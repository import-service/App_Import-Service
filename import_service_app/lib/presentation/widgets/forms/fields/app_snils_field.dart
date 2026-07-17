import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/presentation/helpers/masked_field_validation.dart';
import 'package:import_service_app/presentation/widgets/forms/fields/app_clearable_labeled_field.dart';
import 'package:import_service_app/presentation/widgets/forms/input_formatters/snils_input_formatter.dart';

/// Поле СНИЛС: 11 цифр, контрольная сумма, крестик очистки.
class AppSnilsField extends StatelessWidget {
  const AppSnilsField({
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

  @override
  Widget build(BuildContext context) {
    final strings = sl<JsonStringsService>();

    return AppClearableLabeledField(
      label: label,
      hintText: strings.snilsHint,
      controller: controller,
      keyboardType: TextInputType.number,
      textInputAction: textInputAction,
      markRequired: markRequired,
      density: density,
      inputFormatters: [
        const SnilsInputFormatter(),
        LengthLimitingTextInputFormatter(snilsFormattedCharLimit),
      ],
      validator: validate
          ? (value) =>
              validator?.call(value) ??
              validateSnilsValue(value, strings)
          : null,
    );
  }
}
