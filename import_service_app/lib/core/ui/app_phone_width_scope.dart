import 'package:flutter/material.dart';

/// На широком окне (iPad compat / resize) — колонка шириной iPhone, по центру.
/// На телефоне в портрете (≤ [wideBreakpoint]) — без изменений.
class AppPhoneWidthScope extends StatelessWidget {
  const AppPhoneWidthScope({required this.child, super.key});

  /// Ширина колонки ≈ iPhone Pro Max (430 pt).
  static const double maxContentWidth = 430;
  static const double wideBreakpoint = 600;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= wideBreakpoint) {
          return child;
        }
        final surface = Theme.of(context).colorScheme.surfaceContainerHighest;
        return ColoredBox(
          color: surface,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: maxContentWidth,
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
