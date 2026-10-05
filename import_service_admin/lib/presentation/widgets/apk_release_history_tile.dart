import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Формат: «10 октября 2026 год».
String formatApkReleaseDateRu(String? raw) {
  final s = (raw ?? '').trim();
  if (s.isEmpty) return '';
  final dt = DateTime.tryParse(s);
  if (dt == null) return s;
  final local = dt.toLocal();
  const months = <String>[
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];
  final month = months[local.month - 1];
  return '${local.day} $month ${local.year} год';
}

List<String> apkChangelogLines(String? changelog) {
  final text = (changelog ?? '').trim();
  if (text.isEmpty) return const [];
  return text
      .split(RegExp(r'\r?\n'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);
}

class ApkReleaseHistoryTile extends StatefulWidget {
  const ApkReleaseHistoryTile({super.key, required this.row});

  final Map<String, dynamic> row;

  @override
  State<ApkReleaseHistoryTile> createState() => _ApkReleaseHistoryTileState();
}

class _ApkReleaseHistoryTileState extends State<ApkReleaseHistoryTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final name = widget.row['versionName']?.toString() ?? '—';
    final code = widget.row['versionCode'];
    final dateLine = formatApkReleaseDateRu(widget.row['updatedAt']?.toString());
    final lines = apkChangelogLines(widget.row['changelog']?.toString());
    final canExpand = lines.length > 2;
    final visible = (!canExpand || _expanded) ? lines : lines.take(2).toList();

    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$name${code != null ? ' (build $code)' : ''}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (dateLine.isNotEmpty) ...[
            const Gap(2),
            Text(
              dateLine,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
            ),
          ],
          const Gap(6),
          if (lines.isEmpty)
            Text(
              'Без описания изменений',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black45,
                  ),
            )
          else ...[
            for (final line in visible)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('• $line', style: Theme.of(context).textTheme.bodyMedium),
              ),
            if (canExpand)
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? 'Свернуть' : 'Ещё ${lines.length - 2}'),
              ),
          ],
        ],
      ),
    );
  }
}
