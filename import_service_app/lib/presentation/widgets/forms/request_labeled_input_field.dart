import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:import_service_app/presentation/widgets/forms/app_field_decoration.dart';

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
  });

  final String label;
  final String hintText;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final bool markRequired;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: const Color(0xFF7C7C7C),
          fontWeight: FontWeight.w500,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: labelStyle,
            children: [
              TextSpan(text: label),
              if (markRequired)
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
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          decoration: buildAppOutlineInputDecoration(context, hintText: hintText),
        ),
      ],
    );
  }
}
