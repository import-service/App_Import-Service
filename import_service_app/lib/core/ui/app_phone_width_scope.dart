import 'package:flutter/material.dart';

/// На широком экране (iPad / landscape) — колонка как на iPhone, по центру.
/// На телефоне (≤ [wideBreakpoint]) — без изменений.
class AppPhoneWidthScope extends StatelessWidget {
  const AppPhoneWidthScope({required this.child, super.key});

  static const double maxContentWidth = 520;
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
