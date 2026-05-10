import 'package:flutter/material.dart';
import 'package:import_service_app/presentation/widgets/forms/app_field_decoration.dart';

/// Поле поиска — та же обводка, что у [AppLabeledTextField].
class AppSearchBarField extends StatelessWidget {
  const AppSearchBarField({
    super.key,
    required this.hintText,
    this.controller,
    this.onChanged,
    this.clearTooltip,
  });

  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  /// Подсказка для кнопки сброса. С [controller] — справа крестик, пока поле не пустое.
  final String? clearTooltip;

  @override
  Widget build(BuildContext context) {
    if (clearTooltip == null || controller == null) {
      return _field(context, null);
    }
    return ListenableBuilder(
      listenable: controller!,
      builder: (context, child) {
        return _field(
          context,
          controller!.text.isEmpty
              ? null
              : _ClearSuffix(
                  tooltip: clearTooltip!,
                  onPressed: () {
                    controller!.clear();
                    onChanged?.call('');
                  },
                ),
        );
      },
    );
  }

  Widget _field(BuildContext context, Widget? clearSuffix) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: buildAppOutlineInputDecoration(
        context,
        hintText: hintText,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: clearSuffix,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 12,
        ),
      ),
    );
  }
}

class _ClearSuffix extends StatelessWidget {
  const _ClearSuffix({
    required this.tooltip,
    required this.onPressed,
  });

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        style: IconButton.styleFrom(visualDensity: VisualDensity.compact),
        padding: const EdgeInsets.all(4),
        icon: const Icon(Icons.close, size: 20),
      ),
    );
  }
}
