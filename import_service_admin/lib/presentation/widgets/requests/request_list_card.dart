import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_admin/core/auth/auth_session_controller.dart';
import 'package:import_service_admin/core/catalog/customs_request_labels.dart';
import 'package:import_service_admin/core/di/injection_container.dart';
import 'package:import_service_admin/core/theme/app_theme.dart';
import 'package:import_service_admin/core/util/file_url_resolver.dart';
import 'package:import_service_admin/domain/entities/customs_request.dart';
import 'package:import_service_admin/presentation/widgets/requests/request_status_pill.dart';

class RequestListCard extends StatelessWidget {
  const RequestListCard({
    super.key,
    required this.item,
    required this.sending,
    required this.onOpenDetail,
    this.onSendTo1C,
    this.onResendUpdateTo1C,
  });

  final CustomsRequest item;
  final bool sending;
  final VoidCallback onOpenDetail;
  final VoidCallback? onSendTo1C;
  final VoidCallback? onResendUpdateTo1C;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNew = item.status == 'new';
    final needsUpdate = item.oneCUpdatePending;
    final needsCreate = item.oneCCreatePending;
    final outboundPending = item.hasOutboundPending;
    final subLabel = statusSubTypeLabel(item.statusSubType);
    final hasSub =
        item.statusSubType != null && item.statusSubType!.trim().isNotEmpty;

    final borderColor = isNew
        ? AppTheme.requestCardNewBorder
        : outboundPending
            ? AppTheme.requestCardPendingBorder
            : AppTheme.requestCardBorder;
    final bgColor = isNew
        ? AppTheme.requestCardNewBg
        : outboundPending
            ? AppTheme.requestCardPendingBg
            : AppTheme.white;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onOpenDetail,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Thumbnail(url: item.listThumbnailUrl),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.ownerFullName.trim().isNotEmpty
                                ? item.ownerFullName.trim()
                                : '—',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Gap(4),
                          Text(
                            item.organizationLine,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const Gap(4),
                          Text(
                            item.displayCarLine,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          if (item.managerFullName != null &&
                              item.managerFullName!.trim().isNotEmpty) ...[
                            const Gap(4),
                            Text(
                              'Менеджер: ${item.managerFullName!.trim()}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                          const Gap(10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              RequestStatusPill(
                                label: requestStatusLabel(item.status),
                              ),
                              if (hasSub)
                                Text(
                                  subLabel,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                          if (item.isTest) ...[
                            const Gap(6),
                            Text(
                              'Тестовая',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppTheme.accentRed,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (needsCreate) ...[
                            const Gap(6),
                            Text(
                              item.oneCCreateHoursPending != null
                                  ? 'Create в 1С не отправлен · ${item.oneCCreateHoursPending} ч'
                                  : 'Create в 1С не отправлен',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.accentRed,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (needsUpdate) ...[
                            const Gap(6),
                            Text(
                              item.oneCUpdateHoursPending != null
                                  ? 'Update в 1С не доставлен · ${item.oneCUpdateHoursPending} ч'
                                  : 'Изменения не доставлены в 1С',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.accentRed,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (item.oneCOutboundStaleOver24h) ...[
                            const Gap(4),
                            Text(
                              'Более суток не удаётся отправить в 1С',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppTheme.accentRed,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Gap(8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppTheme.requestCardStatusPillBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: AppTheme.accentRed,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (onSendTo1C != null || onResendUpdateTo1C != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (onSendTo1C != null) ...[
                    FilledButton.icon(
                      onPressed: sending ? null : onSendTo1C,
                      icon: _busyIcon(sending),
                      label: const Text('Отправить в 1С'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                  if (onResendUpdateTo1C != null) ...[
                    if (onSendTo1C != null) const Gap(8),
                    FilledButton.icon(
                      onPressed: sending ? null : onResendUpdateTo1C,
                      icon: _busyIcon(sending),
                      label: const Text('Повторить update в 1С'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.accentRed,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  static Widget _busyIcon(bool sending) {
    return sending
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : const Icon(Icons.cloud_upload_outlined, size: 20);
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final resolved = resolveFileUrl(url);
    final token = sl<AuthSessionController>().accessToken?.trim();
    final headers = (token != null && token.isNotEmpty)
        ? <String, String>{'Authorization': 'Bearer $token'}
        : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppTheme.pageBackground,
          border: Border.all(color: AppTheme.requestCardBorder),
        ),
        child: resolved != null
            ? Image.network(
                resolved,
                headers: headers,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Icon(
      Icons.directions_car_outlined,
      size: 32,
      color: AppTheme.textSecondary.withValues(alpha: 0.5),
    );
  }
}
