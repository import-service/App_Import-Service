import 'package:flutter/material.dart';
import 'package:import_service_app/core/themes/app_theme.dart';

/// Табы статусов: серая подложка, неактивные — серый текст; активный — [AppTheme.accentRed],
/// тот же радиус скругления, что и у подложки; красная плашка на всю ширину ячейки (без боковых inset).
class CarStatusChipsBar extends StatelessWidget {
  const CarStatusChipsBar({
    super.key,
    required this.statuses,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> statuses;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const double _height = 46;
  static const double _radius = 14;

  /// Общие для таба и связанного контента (например [PageView]): одна длительность и кривая.
  static const Duration tabSlideDuration = Duration(milliseconds: 240);
  static const Curve tabSlideCurve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        if (w <= 0) {
          return const SizedBox(height: _height);
        }
        final n = statuses.length;
        final cellW = w / n;
        final selected = selectedIndex.clamp(0, n - 1);
        final radius = BorderRadius.circular(_radius);

        final children = <Widget>[
          Container(
            width: w,
            height: _height,
            decoration: BoxDecoration(
              color: const Color(0xFFDBDBDB),
              borderRadius: radius,
            ),
          ),
        ];

        for (int i = 0; i < n; i++) {
          if (i == selected) continue;
          children.add(
            _inactiveSlot(
              left: i * cellW,
              width: cellW,
              label: statuses[i],
              theme: theme,
              onTap: () => onSelected(i),
            ),
          );
        }

        children.add(
          _activeSlot(
            left: selected * cellW,
            width: cellW,
            label: statuses[selected],
            theme: theme,
            radius: radius,
            onTap: () => onSelected(selected),
          ),
        );

        return SizedBox(
          height: _height,
          child: Stack(
            clipBehavior: Clip.none,
            children: children,
          ),
        );
      },
    );
  }

  static Widget _inactiveSlot({
    required double left,
    required double width,
    required String label,
    required ThemeData theme,
    required VoidCallback onTap,
  }) {
    return Positioned(
      left: left,
      width: width,
      top: 0,
      bottom: 0,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _activeSlot({
    required double left,
    required double width,
    required String label,
    required ThemeData theme,
    required BorderRadius radius,
    required VoidCallback onTap,
  }) {
    return AnimatedPositioned(
      duration: tabSlideDuration,
      curve: tabSlideCurve,
      left: left,
      width: width,
      top: 0,
      bottom: 0,
      child: Material(
        elevation: 2,
        shadowColor: Colors.black26,
        borderRadius: radius,
        color: AppTheme.accentRed,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppTheme.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
