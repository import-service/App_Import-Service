import 'package:flutter/material.dart';

/// Обертка для bottom sheet: высота по содержимому, без обрезания снизу
/// (прозрачный route + [Material] + [SafeArea] + отступ только под клавиатуру).
class AppModalBottomSheet extends StatelessWidget {
  const AppModalBottomSheet({super.key, required this.child});

  final Widget child;

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    Color? materialColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      useSafeArea: false,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      barrierColor: Colors.black54,
      showDragHandle: false,
      builder: (sheetContext) {
        final mq = MediaQuery.of(sheetContext);
        final kb = mq.viewInsets.bottom;

        /// Высота области над клавиатурой — без этого [Column] внутри шторки
        /// переполняется при фокусе в поле.
        final maxSheetBodyHeight = mq.size.height - kb;

        void dismissSheet() {
          if (Navigator.of(sheetContext).canPop()) {
            Navigator.of(sheetContext).pop();
          }
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: dismissSheet,
              ),
            ),
            AnimatedPadding(
              padding: EdgeInsets.only(bottom: kb),
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Material(
                  color: materialColor ?? colorScheme.surface,
                  elevation: 4,
                  shadowColor: Colors.black26,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxSheetBodyHeight),
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      physics: const ClampingScrollPhysics(),
                      child: SafeArea(
                        top: false,
                        minimum: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: AppModalBottomSheet(child: child),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
