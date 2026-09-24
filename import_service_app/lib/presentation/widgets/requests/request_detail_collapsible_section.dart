import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/data/local/request_detail_section_prefs.dart';

/// Сворачиваемая секция: persist, urgent, бейджи new/changed.
class RequestDetailCollapsibleSection extends StatefulWidget {
  const RequestDetailCollapsibleSection({
    super.key,
    required this.requestId,
    required this.sectionKey,
    required this.title,
    required this.needsAction,
    required this.children,
    this.subtitle,
    this.newCount = 0,
    this.hasChanged = false,
    this.onOpened,
  });

  final String requestId;
  final String sectionKey;
  final String title;
  final bool needsAction;
  final List<Widget> children;

  /// Виден и в свёрнутом, и в раскрытом состоянии (под заголовком).
  final Widget? subtitle;

  /// Число новых файлов в секции — красный кружок.
  final int newCount;

  /// Есть изменённые файлы — жёлтый «!».
  final bool hasChanged;

  /// Секцию раскрыли (для гашения бейджей).
  final VoidCallback? onOpened;

  @override
  State<RequestDetailCollapsibleSection> createState() =>
      _RequestDetailCollapsibleSectionState();
}

class _RequestDetailCollapsibleSectionState
    extends State<RequestDetailCollapsibleSection> {
  bool? _expanded;
  bool _loaded = false;
  bool _openedNotified = false;

  static const Color _changedAmber = Color(0xFFE6A817);

  @override
  void initState() {
    super.initState();
    _loadExpanded();
  }

  @override
  void didUpdateWidget(RequestDetailCollapsibleSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.needsAction && !widget.needsAction && _expanded == true) {
      _setExpanded(false, persist: true);
    } else if (!oldWidget.needsAction && widget.needsAction) {
      _setExpanded(true, persist: false);
    }
    if (widget.newCount > oldWidget.newCount ||
        (widget.hasChanged && !oldWidget.hasChanged)) {
      _openedNotified = false;
    }
  }

  Future<void> _loadExpanded() async {
    final prefs = sl<RequestDetailSectionPrefs>();
    final saved = prefs.readExpanded(widget.requestId, widget.sectionKey);
    if (!mounted) return;
    setState(() {
      _loaded = true;
      _expanded = widget.needsAction ? true : (saved ?? false);
    });
  }

  void _notifyOpened() {
    if (_openedNotified) return;
    _openedNotified = true;
    widget.onOpened?.call();
  }

  void _setExpanded(bool value, {required bool persist}) {
    setState(() => _expanded = value);
    if (persist) {
      unawaited(
        sl<RequestDetailSectionPrefs>().saveExpanded(
          widget.requestId,
          widget.sectionKey,
          value,
        ),
      );
    }
  }

  void _onExpansionChanged(bool expanded) {
    if (widget.needsAction && !expanded) {
      setState(() => _expanded = false);
      return;
    }
    _setExpanded(expanded, persist: !widget.needsAction);
    if (expanded) {
      _notifyOpened();
    }
  }

  Widget? _leadingBadges() {
    final urgent = widget.needsAction;
    final showNew = widget.newCount > 0;
    final showChanged = widget.hasChanged;
    if (!urgent && !showNew && !showChanged) return null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showChanged)
          const Icon(Icons.error, color: _changedAmber, size: 22),
        if (showChanged && (showNew || urgent)) const Gap(4),
        if (showNew)
          Container(
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            padding: const EdgeInsets.symmetric(horizontal: 5),
            decoration: const BoxDecoration(
              color: AppTheme.accentRed,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              widget.newCount > 99 ? '99+' : '${widget.newCount}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ),
        if (showNew && urgent) const Gap(4),
        if (urgent && !showNew)
          const Icon(Icons.error_outline_rounded, color: AppTheme.accentRed, size: 22),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _expanded == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    const radius = 14.0;
    final urgent = widget.needsAction;
    final attention = urgent || widget.newCount > 0 || widget.hasChanged;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sectionBg = urgent
        ? AppTheme.accentRed.withValues(alpha: isDark ? 0.16 : 0.06)
        : AppTheme.sectionTint;
    final borderColor = urgent
        ? AppTheme.accentRed.withValues(alpha: 0.55)
        : attention
            ? _changedAmber.withValues(alpha: 0.65)
            : AppTheme.primaryBlue.withValues(alpha: 0.6);
    final roundedClip = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: sectionBg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
      ),
      child: Theme(
        data: theme.copyWith(
          dividerColor: Colors.transparent,
          splashColor: (urgent ? AppTheme.accentRed : AppTheme.primaryBlue)
              .withValues(alpha: 0.12),
          highlightColor: (urgent ? AppTheme.accentRed : AppTheme.primaryBlue)
              .withValues(alpha: 0.08),
          listTileTheme: const ListTileThemeData(
            tileColor: Colors.transparent,
            selectedTileColor: Colors.transparent,
          ),
          expansionTileTheme: ExpansionTileThemeData(
            backgroundColor: Colors.transparent,
            collapsedBackgroundColor: Colors.transparent,
            shape: roundedClip,
            collapsedShape: roundedClip,
          ),
        ),
        child: ExpansionTile(
          key: ValueKey('${widget.sectionKey}_$_expanded'),
          initiallyExpanded: _expanded!,
          onExpansionChanged: _onExpansionChanged,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          expandedAlignment: Alignment.centerLeft,
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          shape: roundedClip,
          collapsedShape: roundedClip,
          leading: _leadingBadges(),
          title: Text(
            widget.title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: urgent ? AppTheme.accentRed : AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: widget.subtitle,
          children: [
            for (var i = 0; i < widget.children.length; i++) ...[
              widget.children[i],
              if (i < widget.children.length - 1) const Gap(8),
            ],
          ],
        ),
      ),
    );
  }
}
