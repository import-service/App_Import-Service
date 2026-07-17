import 'package:flutter/material.dart';

/// Крестик очистки для полей ввода — единый вид по всему приложению.
Widget buildAppFieldClearButton(
  BuildContext context, {
  required VoidCallback onPressed,
}) {
  return IconButton(
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
    padding: EdgeInsets.zero,
    onPressed: onPressed,
    tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
    icon: const Icon(Icons.clear, size: 22),
  );
}
