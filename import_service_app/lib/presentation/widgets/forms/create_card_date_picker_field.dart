import 'package:flutter/material.dart';
import 'package:import_service_app/presentation/widgets/forms/app_field_decoration.dart';

class CreateCardDatePickerField extends StatelessWidget {
  const CreateCardDatePickerField({
    super.key,
    required this.label,
    required this.hintText,
    required this.controller,
    required this.onTap,
  });

  final String label;
  final String hintText;
  final TextEditingController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF7C7C7C),
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: true,
          onTap: onTap,
          decoration: buildAppOutlineInputDecoration(
            context,
            hintText: hintText,
            suffixIcon: const Icon(Icons.calendar_month_outlined),
          ),
        ),
      ],
    );
  }
}
