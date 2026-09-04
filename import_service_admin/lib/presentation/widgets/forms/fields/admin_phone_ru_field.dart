import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:import_service_admin/presentation/widgets/forms/input_formatters/phone_ru_input_formatter.dart';
import 'package:import_service_admin/presentation/widgets/forms/required_field_label.dart';

/// Телефон РФ: маска `+7 (999) 000-00-00`, только цифры, цифровая клавиатура.
/// Переиспользуемый блок для админки.
class AdminPhoneRuField extends StatelessWidget {
  const AdminPhoneRuField({
    super.key,
    required this.controller,
    this.label = 'Телефон',
    this.markRequired = false,
    this.textInputAction,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final bool markRequired;
  final TextInputAction? textInputAction;
  final bool enabled;

  static const _hint = '+7 (999) 000-00-00';

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      textInputAction: textInputAction,
      inputFormatters: <TextInputFormatter>[
        PhoneRuInputFormatter(),
      ],
      decoration: InputDecoration(
        label: RequiredFieldLabel(text: label, required: markRequired),
        hintText: _hint,
      ),
      validator: (value) {
        if (PhoneRuInputFormatter.isEmptyRuPhone(value)) {
          return markRequired ? 'Введите телефон' : null;
        }
        if (!PhoneRuInputFormatter.isCompleteRuPhone(value)) {
          return 'Формат: +7 (999) 000-00-00';
        }
        return null;
      },
    );
  }
}
