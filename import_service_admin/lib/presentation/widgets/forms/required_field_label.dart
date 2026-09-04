import 'package:flutter/material.dart';

/// Подпись поля с красной «*» для обязательных.
class RequiredFieldLabel extends StatelessWidget {
  const RequiredFieldLabel({
    super.key,
    required this.text,
    this.required = false,
  });

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    if (!required) return Text(text);
    final base = Theme.of(context).textTheme.bodyLarge;
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: text),
          TextSpan(
            text: ' *',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
