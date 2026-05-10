import 'package:flutter/material.dart';
import 'package:import_service_app/core/themes/app_theme.dart';

/// Общая обводка и заливка полей ввода (логин, заявка, формы).
InputDecoration buildAppOutlineInputDecoration(
  BuildContext context, {
  Widget? suffixIcon,
  Widget? prefixIcon,
  String? hintText,
  EdgeInsetsGeometry contentPadding = const EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 12,
  ),
  bool isDense = true,
  int? errorMaxLines = 3,
}) {
  const radius = BorderRadius.all(Radius.circular(14));
  final surface = Theme.of(context).colorScheme.surface;
  final error = Theme.of(context).colorScheme.error;

  return InputDecoration(
    hintText: hintText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    isDense: isDense,
    contentPadding: contentPadding,
    errorMaxLines: errorMaxLines,
    filled: true,
    fillColor: surface,
    enabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: AppTheme.inputOutlineGray, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: error, width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: error, width: 2),
    ),
  );
}
