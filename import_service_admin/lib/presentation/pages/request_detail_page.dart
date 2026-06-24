import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:import_service_admin/core/auth/auth_session_controller.dart';
import 'package:import_service_admin/core/catalog/customs_request_labels.dart';
import 'package:import_service_admin/core/di/injection_container.dart';
import 'package:import_service_admin/core/error/exceptions.dart';
import 'package:import_service_admin/core/logging/one_c_log.dart';
import 'package:import_service_admin/core/theme/app_theme.dart';
import 'package:import_service_admin/core/ui/app_snackbars.dart';
import 'package:import_service_admin/core/ui/server_error_ui.dart';
import 'package:import_service_admin/core/util/file_url_resolver.dart';
import 'package:import_service_admin/domain/entities/customs_request.dart';
import 'package:import_service_admin/domain/entities/customs_request_file.dart';
import 'package:import_service_admin/data/datasources/remote/storage_remote_data_source.dart';
import 'package:import_service_admin/domain/repositories/customs_requests_repository.dart';
import 'package:import_service_admin/presentation/widgets/requests/request_detail_file_row.dart';
import 'package:import_service_admin/presentation/widgets/requests/request_detail_files_sections.dart';
import 'package:import_service_admin/presentation/widgets/requests/request_detail_finance_card.dart';
import 'package:import_service_admin/presentation/widgets/requests/request_labeled_value.dart';
import 'package:import_service_admin/presentation/widgets/requests/request_status_pill.dart';
import 'package:url_launcher/url_launcher.dart';

class RequestDetailPage extends StatefulWidget {
  const RequestDetailPage({super.key, required this.requestId});

  final String requestId;

  @override
  State<RequestDetailPage> createState() => _RequestDetailPageState();
}

class _RequestDetailPageState extends State<RequestDetailPage> {
  late Future<CustomsRequest> _future;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = sl<CustomsRequestsRepository>().getRequest(widget.requestId);
    });
  }

  String? get _token => sl<AuthSessionController>().accessToken;

  Future<void> _resendCreate(CustomsRequest item) async {
    await _runOneC(
      () => sl<CustomsRequestsRepository>().resendTo1C(item.id),
      logAction: 'resend-to-1c #${item.id}',
    );
  }

  Future<void> _resendUpdate(CustomsRequest item) async {
    await _runOneC(
      () => sl<CustomsRequestsRepository>().resendUpdateTo1C(item.id),
      success: 'Изменения отправлены в 1С',
      logAction: 'resend-update-to-1c #${item.id}',
    );
  }

  Future<void> _runOneC(
    Future<CustomsRequest> Function() action, {
    String success = 'Заявка отправлена в 1С',
    String logAction = '',
  }) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await action();
      if (!mounted) return;
      AppSnackBars.showSuccess(success, context: context);
      _reload();
    } on UnauthorizedException {
      return;
    } on OneCCreateFailedException catch (e) {
      if (logAction.isNotEmpty) OneCLog.failure(e, action: logAction);
      if (!mounted) return;
      AppSnackBars.showError(e.message, context: context);
    } on ServerException catch (e) {
      if (!mounted) return;
      AppSnackBars.showError(e.message, context: context);
    } catch (e) {
      if (!mounted) return;
      AppSnackBars.showError('Ошибка: $e', context: context);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openFile(CustomsRequestFile file) async {
    final url = resolveFileUrl(file.fileUrl);
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _deleteRequest(CustomsRequest item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить заявку?'),
        content: Text(
          'Заявка №${item.id} и все файлы будут удалены безвозвратно.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.accentRed),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _sending = true);
    try {
      await sl<StorageRemoteDataSource>().deleteRequest(item.id);
      if (!mounted) return;
      AppSnackBars.showSuccess('Заявка удалена', context: context);
      context.pop();
    } catch (e) {
      if (!mounted) return;
      AppSnackBars.showError('$e', context: context);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: AppBar(
        title: const Text('Заявка'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          FutureBuilder<CustomsRequest>(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Удалить заявку',
                onPressed: _sending ? null : () => _deleteRequest(snapshot.data!),
                icon: const Icon(Icons.delete_outline, color: AppTheme.accentRed),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<CustomsRequest>(
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
          final item = snapshot.data!;
          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async {
                  _reload();
                  await _future;
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: _buildSections(context, item),
                ),
              ),
              if (_sending)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x44000000),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildSections(BuildContext context, CustomsRequest item) {
    final theme = Theme.of(context);
    final subLabel = statusSubTypeLabel(item.statusSubType);
    final hasSub =
        item.statusSubType != null && item.statusSubType!.trim().isNotEmpty;

    final out = <Widget>[
      if (item.canSendTo1C || item.canResendUpdateTo1C) ...[
        _AdminActions(
          item: item,
          sending: _sending,
          onResendCreate:
              item.canSendTo1C ? () => _resendCreate(item) : null,
          onResendUpdate:
              item.canResendUpdateTo1C ? () => _resendUpdate(item) : null,
        ),
        const Gap(20),
      ],
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Статус',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    RequestStatusPill(label: requestStatusLabel(item.status)),
                  ],
                ),
                if (hasSub) ...[
                  const Gap(6),
                  Text(
                    subLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (item.statusSinceDateLabel != null &&
              item.statusSinceDateLabel!.trim().isNotEmpty)
            Text(
              item.statusSinceDateLabel!.trim(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
        ],
      ),
      const Gap(20),
      RequestLabeledValue(label: 'Клиент', value: item.ownerFullName),
      const Gap(14),
      RequestLabeledValue(label: 'Организация', value: item.organizationLine),
      const Gap(14),
      RequestLabeledValue(label: 'Email', value: item.legalEmail),
      const Gap(14),
      RequestLabeledValue(label: 'Телефон организации', value: item.legalPhone),
      const Gap(14),
      RequestLabeledValue(
        label: 'ФИО физлица',
        value: item.individualFullName,
      ),
      const Gap(14),
      RequestLabeledValue(
        label: 'Телефон физлица',
        value: item.individualPhone,
      ),
      const Gap(14),
      RequestLabeledValue(label: 'СНИЛС', value: item.individualSnils),
      if (item.commentText != null && item.commentText!.trim().isNotEmpty) ...[
        const Gap(14),
        RequestLabeledValue(label: 'Комментарий', value: item.commentText!.trim()),
      ],
      const Gap(14),
      RequestLabeledValue(label: 'Люк / панорама', value: yesNoLabel(item.hasSunroof)),
      const Gap(14),
      RequestLabeledValue(label: 'Полный привод', value: yesNoLabel(item.hasAllWheelDrive)),
      const Gap(14),
      RequestLabeledValue(
        label: 'Ввоз за 12 мес.',
        value: yesNoLabel(item.importedLast12Months),
      ),
      const Gap(14),
      RequestLabeledValue(
        label: 'Другие авто',
        value: yesNoLabel(item.ownsOtherCars),
      ),
    ];

    if (item.dealType != null && item.dealType!.trim().isNotEmpty) {
      out
        ..add(const Gap(14))
        ..add(
          RequestLabeledValue(
            label: 'Тип сделки',
            value: dealTypeLabel(item.dealType),
          ),
        );
    }

    if (item.managerFullName != null &&
        item.managerFullName!.trim().isNotEmpty) {
      out
        ..add(const Gap(14))
        ..add(
          RequestLabeledValue(
            label: 'Менеджер',
            value: item.managerFullName!.trim(),
          ),
        );
    }

    out
      ..add(const Gap(14))
      ..add(
        RequestLabeledValue(
          label: 'Автомобиль',
          value: item.displayCarLine,
        ),
      );

    if ((item.engineSpec != null && item.engineSpec!.trim().isNotEmpty) ||
        (item.engineVolume != null && item.engineVolume!.trim().isNotEmpty)) {
      out.add(const Gap(14));
      if (item.engineSpec != null && item.engineSpec!.trim().isNotEmpty) {
        out.add(RequestLabeledValue(label: 'Двигатель', value: item.engineSpec!.trim()));
      }
      if (item.engineVolume != null && item.engineVolume!.trim().isNotEmpty) {
        out.add(const Gap(14));
        out.add(
          RequestLabeledValue(
            label: 'Объём двигателя',
            value: item.engineVolume!.trim(),
          ),
        );
      }
    }

    if (item.financeItems.isNotEmpty) {
      out
        ..add(const Gap(24))
        ..add(
          Text(
            'Оплаты и квитанции',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        )
        ..add(const Gap(10));
      for (var i = 0; i < item.financeItems.length; i++) {
        out.add(RequestDetailFinanceCard(line: item.financeItems[i]));
        if (i < item.financeItems.length - 1) out.add(const Gap(10));
      }
    }

    out
      ..add(const Gap(24))
      ..add(
        Text(
          'Документы',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      )
      ..add(const Gap(10))
      ..add(
        RequestDetailFilesSections(
          files: item.files,
          deliveredDocuments: item.deliveredDocuments,
          vehiclePhotoUrls: item.vehiclePhotoUrls,
          authToken: _token,
          buildFileRow: (f) => RequestDetailFileRow(
            file: f,
            authToken: _token,
            onOpen: () => _openFile(f),
          ),
        ),
      );

    out
      ..add(const Gap(24))
      ..add(
        Text(
          'Интеграция 1С',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      )
      ..add(const Gap(10))
      ..add(
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.requestCardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RequestLabeledValue(
                label: 'ID в 1С',
                value: item.external1cId?.trim().isNotEmpty == true
                    ? item.external1cId!
                    : '—',
              ),
              if (item.managerExternal1cId != null &&
                  item.managerExternal1cId!.trim().isNotEmpty) ...[
                const Gap(14),
                RequestLabeledValue(
                  label: 'ID менеджера в 1С',
                  value: item.managerExternal1cId!,
                ),
              ],
              const Gap(14),
              RequestLabeledValue(
                label: 'Create не отправлен',
                value: item.oneCCreatePending ? 'Да' : 'Нет',
              ),
              if (item.oneCCreateHoursPending != null) ...[
                const Gap(14),
                RequestLabeledValue(
                  label: 'Часов без create в 1С',
                  value: '${item.oneCCreateHoursPending}',
                ),
              ],
              const Gap(14),
              RequestLabeledValue(
                label: 'Update не доставлен',
                value: item.oneCUpdatePending ? 'Да' : 'Нет',
              ),
              if (item.oneCUpdateHoursPending != null) ...[
                const Gap(14),
                RequestLabeledValue(
                  label: 'Часов без update в 1С',
                  value: '${item.oneCUpdateHoursPending}',
                ),
              ],
              if (item.oneCUpdateLastAttemptAt != null) ...[
                const Gap(14),
                RequestLabeledValue(
                  label: 'Последняя попытка update',
                  value: formatDateTimeLabel(item.oneCUpdateLastAttemptAt),
                ),
              ],
              if (item.oneCCreateLastError != null) ...[
                const Gap(14),
                Text(
                  'Ошибка create',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.accentRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Gap(4),
                SelectableText(
                  _formatOneCError(item.oneCCreateLastError!),
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (item.oneCUpdateLastError != null) ...[
                const Gap(14),
                Text(
                  'Ошибка update',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.accentRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Gap(4),
                SelectableText(
                  _formatOneCError(item.oneCUpdateLastError!),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      );

    out
      ..add(const Gap(24))
      ..add(
        Text(
          'Служебное',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      )
      ..add(const Gap(10))
      ..add(
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.requestCardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RequestLabeledValue(label: '№ заявки', value: item.id),
              const Gap(14),
              RequestLabeledValue(
                label: 'Тестовая',
                value: item.isTest ? 'Да' : 'Нет',
              ),
              const Gap(14),
              RequestLabeledValue(
                label: 'Создана',
                value: formatDateTimeLabel(item.createdAt),
              ),
              const Gap(14),
              RequestLabeledValue(
                label: 'Обновлена',
                value: formatDateTimeLabel(item.updatedAt),
              ),
            ],
          ),
        ),
      );

    return out;
  }

  static String _formatOneCError(Map<String, dynamic> err) {
    final parts = <String>[];
    final code = err['code'];
    if (code != null) parts.add('$code');
    final msg = err['oneCMessage'] ?? err['message'];
    if (msg != null && '$msg'.trim().isNotEmpty) parts.add('$msg');
    final http = err['httpStatus'];
    if (http != null) parts.add('HTTP $http');
    return parts.isEmpty ? err.toString() : parts.join(' · ');
  }
}

class _AdminActions extends StatelessWidget {
  const _AdminActions({
    required this.item,
    required this.sending,
    this.onResendCreate,
    this.onResendUpdate,
  });

  final CustomsRequest item;
  final bool sending;
  final VoidCallback? onResendCreate;
  final VoidCallback? onResendUpdate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onResendCreate != null)
          FilledButton.icon(
            onPressed: sending ? null : onResendCreate,
            icon: const Icon(Icons.cloud_upload_outlined),
            label: const Text('Отправить в 1С'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
            ),
          ),
        if (onResendUpdate != null) ...[
          if (onResendCreate != null) const Gap(8),
          FilledButton.icon(
            onPressed: sending ? null : onResendUpdate,
            icon: const Icon(Icons.sync_outlined),
            label: const Text('Повторить update в 1С'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.accentRed,
            ),
          ),
        ],
      ],
    );
  }
}
