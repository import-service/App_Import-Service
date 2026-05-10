import 'package:flutter/material.dart';
import 'package:import_service_app/core/themes/app_theme.dart';

/// Фирменный синий AppBar без скругления, заголовок по центру.
class BrandPrimaryAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const BrandPrimaryAppBar({super.key, required this.title, this.actions});

  final String title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      centerTitle: true,
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      backgroundColor: AppTheme.primaryBlue,
      foregroundColor: AppTheme.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
