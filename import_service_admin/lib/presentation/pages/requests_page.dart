import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_admin/core/di/injection_container.dart';
import 'package:import_service_admin/core/error/exceptions.dart';
import 'package:import_service_admin/core/logging/one_c_log.dart';
import 'package:import_service_admin/core/theme/app_theme.dart';
import 'package:import_service_admin/core/ui/app_snackbars.dart';
import 'package:import_service_admin/core/ui/server_error_ui.dart';
import 'package:import_service_admin/domain/entities/customs_request_summary.dart';
import 'package:import_service_admin/domain/repositories/customs_requests_repository.dart';

class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key});

  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  late Future<({List<CustomsRequestSummary> items, int total})> _future;
  final _sending = <String>{};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = sl<CustomsRequestsRepository>().listRequests(limit: 200);
    });
  }

  Future<void> _resendUpdateTo1C(CustomsRequestSummary item) async {
    if (_sending.contains(item.id)) return;
    setState(() => _sending.add(item.id));
    try {
      await sl<CustomsRequestsRepository>().resendUpdateTo1C(item.id);
      if (!mounted) return;
      AppSnackBars.showSuccess(
        'Изменения заявки ${item.id} отправлены в 1С',
        context: context,
      );
      _reload();
    } on UnauthorizedException {
      return;
    } on OneCCreateFailedException catch (e) {
      OneCLog.failure(e, action: 'resend-update-to-1c #${item.id}');
      if (!mounted) return;
      AppSnackBars.showError(e.message, context: context);
    } on ServerException catch (e) {
      if (!mounted) return;
      AppSnackBars.showError(e.message, context: context);
    } catch (e) {
      if (!mounted) return;
      AppSnackBars.showError('Ошибка: $e', context: context);
    } finally {
      if (mounted) setState(() => _sending.remove(item.id));
    }
  }

  Future<void> _sendTo1C(CustomsRequestSummary item) async {
    if (_sending.contains(item.id)) return;
    setState(() => _sending.add(item.id));
    try {
      final updated = await sl<CustomsRequestsRepository>().resendTo1C(item.id);
      if (!mounted) return;
      final manager = updated.managerFullName?.trim();
      final extId = updated.external1cId?.trim();
      var okText = 'Заявка ${item.id} отправлена в 1С';
      if (extId != null && extId.isNotEmpty) {
        okText += ' · $extId';
      }
      if (manager != null && manager.isNotEmpty) {
        okText += ' · $manager';
      }
      AppSnackBars.showSuccess(okText, context: context);
      _reload();
    } on UnauthorizedException {
      return;
    } on OneCCreateFailedException catch (e) {
      OneCLog.failure(e, action: 'resend-to-1c #${item.id}');
      if (!mounted) return;
      AppSnackBars.showError(e.message, context: context);
    } on ServerException catch (e) {
      if (!mounted) return;
      AppSnackBars.showError(e.message, context: context);
    } catch (e) {
      if (!mounted) return;
      AppSnackBars.showError('Ошибка: $e', context: context);
    } finally {
      if (mounted) setState(() => _sending.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({List<CustomsRequestSummary> items, int total})>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          final panel = buildRetryErrorPanel(
            error: snapshot.error,
            onRetry: _reload,
          );
          if (panel != null) return panel;
          return const SizedBox.shrink();
        }

        final items = snapshot.data?.items ?? const [];
        if (items.isEmpty) {
          return const Center(child: Text('Заявок нет'));
        }

        return RefreshIndicator(
          onRefresh: () async {
            _reload();
            await _future;
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Gap(12),
            itemBuilder: (context, index) {
              final item = items[index];
              return _RequestCard(
                item: item,
                sending: _sending.contains(item.id),
                onSendTo1C: item.canSendTo1C ? () => _sendTo1C(item) : null,
                onResendUpdateTo1C:
                    item.canResendUpdateTo1C ? () => _resendUpdateTo1C(item) : null,
              );
            },
          ),
        );
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.item,
    required this.sending,
    this.onSendTo1C,
    this.onResendUpdateTo1C,
  });

  final CustomsRequestSummary item;
  final bool sending;
  final VoidCallback? onSendTo1C;
  final VoidCallback? onResendUpdateTo1C;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNew = item.status == 'new';
    final needsUpdateResend = item.oneCUpdatePending;

    return Card(
      elevation: 0,
      color: isNew
          ? const Color(0xFFFFF8E1)
          : needsUpdateResend
              ? const Color(0xFFFFEBEE)
              : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isNew
              ? const Color(0xFFFFB300)
              : needsUpdateResend
                  ? const Color(0xFFE53935)
                  : const Color(0xFFE0E0E0),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.carTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Gap(4),
                      Text('№ ${item.id} · ${item.ownerFullName}'),
                    ],
                  ),
                ),
                _StatusChip(status: item.status),
              ],
            ),
            const Gap(8),
            Text('VIN: ${item.vin}', style: theme.textTheme.bodySmall),
            if (item.external1cId != null && item.external1cId!.isNotEmpty)
              Text(
                '1С: ${item.external1cId}',
                style: theme.textTheme.bodySmall,
              ),
            if (item.managerFullName != null) ...[
              const Gap(4),
              Text(
                'Менеджер: ${item.managerFullName}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (item.isTest)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Тестовая',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.accentRed,
                  ),
                ),
              ),
            if (needsUpdateResend && onSendTo1C == null) ...[
              const Gap(8),
              Text(
                'Изменения не доставлены в 1С',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFC62828),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (onSendTo1C != null) ...[
              const Gap(12),
              FilledButton.icon(
                onPressed: sending ? null : onSendTo1C,
                icon: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_upload_outlined, size: 20),
                label: const Text('Отправить в 1С'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                ),
              ),
            ],
            if (onResendUpdateTo1C != null) ...[
              const Gap(12),
              FilledButton.icon(
                onPressed: sending ? null : onResendUpdateTo1C,
                icon: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sync_outlined, size: 20),
                label: const Text('Повторить update в 1С'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFC62828),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  String get _label => switch (status) {
        'new' => 'Новая',
        'in_progress' => 'В работе',
        'in_transit' => 'В пути',
        'delivered' => 'Доставлена',
        _ => status,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.primaryBlue,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
