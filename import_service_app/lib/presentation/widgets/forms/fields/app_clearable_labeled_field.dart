import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:import_service_app/presentation/widgets/forms/app_field_clear_button.dart';
import 'package:import_service_app/presentation/widgets/forms/app_field_decoration.dart';

/// Плотность подписи: компактная (шторки) или крупная (форма заявки).
enum AppLabeledFieldDensity { compact, request }

/// Подпись + поле ввода с крестиком очистки — база для маскированных полей.
class AppClearableLabeledField extends StatefulWidget {
  const AppClearableLabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.markRequired = true,
    this.density = AppLabeledFieldDensity.request,
    this.errorMaxLines = 3,
    this.minLines,
    this.maxLines,
  });

  final String label;
  final String? hintText;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final bool markRequired;
  final AppLabeledFieldDensity density;
  final int errorMaxLines;
  final int? minLines;
  final int? maxLines;

  @override
  State<AppClearableLabeledField> createState() =>
      _AppClearableLabeledFieldState();
}

class _AppClearableLabeledFieldState extends State<AppClearableLabeledField> {
  Widget? _suffixIcon(BuildContext context) {
    if (widget.controller.text.isEmpty) return null;

    return buildAppFieldClearButton(
      context,
      onPressed: widget.controller.clear,
    );
  }

  TextStyle? _labelStyle(BuildContext context) {
    if (widget.density == AppLabeledFieldDensity.request) {
      return Theme.of(context).textTheme.titleMedium?.copyWith(
            color: const Color(0xFF7C7C7C),
            fontWeight: FontWeight.w500,
          );
    }
    final hintColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Theme.of(context).textTheme.bodySmall?.copyWith(color: hintColor);
  }

  @override
  Widget build(BuildContext context) {
    final labelGap = widget.density == AppLabeledFieldDensity.request ? 8.0 : 6.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: _labelStyle(context),
            children: [
              TextSpan(text: widget.label),
              if (widget.markRequired)
                TextSpan(
                  text: ' *',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: labelGap),
        ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            return TextFormField(
              controller: widget.controller,
              validator: widget.validator,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              textCapitalization: widget.textCapitalization,
              inputFormatters: widget.inputFormatters,
              minLines: widget.minLines,
              maxLines: widget.maxLines,
              decoration: buildAppOutlineInputDecoration(
                context,
                hintText: widget.hintText,
                suffixIcon: _suffixIcon(context),
                errorMaxLines: widget.errorMaxLines,
              ),
              style: widget.density == AppLabeledFieldDensity.compact
                  ? Theme.of(context).textTheme.bodyLarge
                  : null,
            );
          },
        ),
      ],
    );
  }
}
