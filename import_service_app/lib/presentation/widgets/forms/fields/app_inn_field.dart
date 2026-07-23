import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/data/models/registration_request_model.dart';
import 'package:import_service_app/presentation/helpers/masked_field_validation.dart';
import 'package:import_service_app/presentation/widgets/forms/fields/app_clearable_labeled_field.dart';
import 'package:import_service_app/presentation/widgets/forms/input_formatters/inn_input_formatter.dart';

/// Поле ИНН: маска, валидация по типу организации, крестик очистки.
class AppInnField extends StatelessWidget {
  const AppInnField({
    super.key,
    required this.label,
    required this.controller,
    required this.organizationType,
    this.validator,
    this.markRequired = true,
    this.textInputAction,
    this.density = AppLabeledFieldDensity.request,
    this.validate = true,
    this.readOnly = false,
  });

  final String label;
  final TextEditingController controller;
  final OrganizationType organizationType;
  final String? Function(String?)? validator;
  final bool markRequired;
  final TextInputAction? textInputAction;
  final AppLabeledFieldDensity density;
  final bool validate;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final strings = sl<JsonStringsService>();
    final maxDigits = organizationType.innMaxDigits;

    return AppClearableLabeledField(
      label: label,
      hintText: strings.innHintFor(organizationType),
      controller: controller,
      keyboardType: TextInputType.number,
      textInputAction: textInputAction,
      markRequired: markRequired,
      density: density,
      readOnly: readOnly,
      inputFormatters: [
        InnInputFormatter(maxDigits: maxDigits),
        LengthLimitingTextInputFormatter(
          InnInputFormatter.formattedCharLimit(maxDigits),
        ),
      ],
      validator: validate
          ? (value) =>
              validator?.call(value) ??
              validateInnValue(value, organizationType, strings)
          : null,
    );
  }
}
