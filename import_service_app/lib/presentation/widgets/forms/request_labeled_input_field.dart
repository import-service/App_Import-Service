import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:import_service_app/presentation/widgets/forms/fields/app_clearable_labeled_field.dart';

/// Подпись + поле ввода формы заявки (с крестиком очистки).
class RequestLabeledInputField extends StatelessWidget {
  const RequestLabeledInputField({
    super.key,
    required this.label,
    required this.hintText,
    required this.controller,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.markRequired = true,
    this.minLines,
    this.maxLines,
  });

  final String label;
  final String hintText;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final bool markRequired;
  final int? minLines;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return AppClearableLabeledField(
      label: label,
      hintText: hintText,
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      markRequired: markRequired,
      minLines: minLines,
      maxLines: maxLines,
      density: AppLabeledFieldDensity.request,
    );
  }
}
