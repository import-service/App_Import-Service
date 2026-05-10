import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:import_service_app/presentation/widgets/forms/app_field_decoration.dart';

/// Подпись + поле ввода: единый стиль по всему приложению (обводка 1 px + фокус).
///
/// Используется на экране входа, в заявке и др. формах. Для пароля —
/// [isPassword] и переключатель видимости.
class AppLabeledTextField extends StatefulWidget {
  const AppLabeledTextField({
    super.key,
    required this.label,
    required this.controller,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.isPassword = false,
    this.markRequired = true,
    this.textCapitalization = TextCapitalization.none,
    this.errorMaxLines = 3,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final bool isPassword;
  /// Звёздочка «обязательное поле» в подписи (цвет [ColorScheme.error]).
  final bool markRequired;
  /// Поведение клавиатуры (заглавные): для названий — [TextCapitalization.sentences].
  final TextCapitalization textCapitalization;
  /// Строк текста ошибки под полем (длинные сообщения i18n).
  final int errorMaxLines;

  @override
  State<AppLabeledTextField> createState() => _AppLabeledTextFieldState();
}

class _AppLabeledTextFieldState extends State<AppLabeledTextField> {
  bool _obscurePassword = true;

  Widget? _suffixIcon(BuildContext context) {
    const compactIconButton = BoxConstraints(minWidth: 40, minHeight: 36);

    if (widget.isPassword) {
      return IconButton(
        visualDensity: VisualDensity.compact,
        constraints: compactIconButton,
        padding: EdgeInsets.zero,
        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        icon: Icon(
          _obscurePassword
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          size: 22,
        ),
      );
    }

    if (widget.controller.text.isEmpty) return null;

    return IconButton(
      visualDensity: VisualDensity.compact,
      constraints: compactIconButton,
      padding: EdgeInsets.zero,
      onPressed: () {
        widget.controller.clear();
      },
      tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
      icon: const Icon(Icons.clear, size: 22),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hintColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final labelStyle =
        Theme.of(context).textTheme.bodySmall?.copyWith(color: hintColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: labelStyle,
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
        const SizedBox(height: 6),
        ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            return TextFormField(
              controller: widget.controller,
              validator: widget.validator,
              obscureText: widget.isPassword && _obscurePassword,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              textCapitalization: widget.textCapitalization,
              inputFormatters: widget.inputFormatters,
              decoration: buildAppOutlineInputDecoration(
                context,
                suffixIcon: _suffixIcon(context),
                errorMaxLines: widget.errorMaxLines,
              ),
              style: Theme.of(context).textTheme.bodyLarge,
            );
          },
        ),
      ],
    );
  }
}
