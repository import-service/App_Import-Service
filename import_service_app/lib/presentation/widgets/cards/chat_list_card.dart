import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/core/util/vin_display.dart';
import 'package:import_service_app/domain/entities/chat_list_item.dart';
import 'package:intl/intl.dart';

class ChatListCard extends StatelessWidget {
  const ChatListCard({
    super.key,
    required this.item,
    required this.hasUnread,
    required this.noPreviewText,
    required this.onTap,
    this.title,
    this.subtitle,
    this.pinned = false,
  });

  final ChatListItem item;
  final bool hasUnread;
  final String noPreviewText;
  final VoidCallback onTap;
  final String? title;
  final String? subtitle;
  final bool pinned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = (item.lastText ?? '').trim();
    final timeLabel = _formatTime(item.lastAt);
    final heading = (title ?? item.displayCarLine).trim();
    final sub = (subtitle ?? formatVinForList(item.vin)).trim();

    return Material(
      color: AppTheme.cardBackground,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: pinned
                ? AppTheme.accentRed.withValues(alpha: 0.04)
                : AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasUnread
                  ? AppTheme.accentRed.withValues(alpha: 0.45)
                  : AppTheme.requestCardBorder,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                if (pinned) ...[
                  Icon(
                    Icons.push_pin_rounded,
                    size: 18,
                    color: hasUnread
                        ? AppTheme.accentRed
                        : AppTheme.textSecondary,
                  ),
                  const Gap(10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        heading,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (sub.isNotEmpty) ...[
                        const Gap(4),
                        Text(
                          sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                      const Gap(8),
                      Text(
                        preview.isEmpty ? noPreviewText : preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: hasUnread
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
                          fontWeight:
                              hasUnread ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (timeLabel.isNotEmpty)
                      Text(
                        timeLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: hasUnread
                              ? AppTheme.accentRed
                              : AppTheme.textSecondary,
                          fontWeight:
                              hasUnread ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    const Gap(10),
                    if (hasUnread)
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppTheme.accentRed,
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox(width: 10, height: 10),
                      )
                    else
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppTheme.textSecondary.withValues(alpha: 0.7),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatTime(DateTime? at) {
    if (at == null) return '';
    final local = at.toLocal();
    final now = DateTime.now();
    final sameDay = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    if (sameDay) {
      return DateFormat('HH:mm').format(local);
    }
    return DateFormat('dd.MM').format(local);
  }
}
