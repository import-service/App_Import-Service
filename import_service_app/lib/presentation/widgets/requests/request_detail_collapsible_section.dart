import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/data/local/request_detail_section_prefs.dart';

/// Сворачиваемая секция детализации: persist, красная рамка при [needsAction].
class RequestDetailCollapsibleSection extends StatefulWidget {
  const RequestDetailCollapsibleSection({
    super.key,
    required this.requestId,
    required this.sectionKey,
    required this.title,
    required this.needsAction,
    required this.children,
    this.subtitle,
  });

  final String requestId;
  final String sectionKey;
  final String title;
  final bool needsAction;
  final List<Widget> children;

  /// Виден и в свёрнутом, и в раскрытом состоянии (под заголовком).
  final Widget? subtitle;

  @override
  State<RequestDetailCollapsibleSection> createState() =>
      _RequestDetailCollapsibleSectionState();
}

class _RequestDetailCollapsibleSectionState
    extends State<RequestDetailCollapsibleSection> {
  bool? _expanded;
  bool _loaded = false;

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
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _expanded == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    const radius = 14.0;
    final urgent = widget.needsAction;
    final sectionBg = urgent
        ? AppTheme.accentRed.withValues(alpha: 0.06)
        : const Color(0xFFF2F7FD);
    final borderColor = urgent
        ? AppTheme.accentRed.withValues(alpha: 0.55)
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
          shape: roundedClip,
          collapsedShape: roundedClip,
          leading: urgent
              ? Icon(Icons.error_outline_rounded, color: AppTheme.accentRed, size: 22)
              : null,
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
