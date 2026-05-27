import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:import_service_admin/core/catalog/customs_request_labels.dart';
import 'package:import_service_admin/core/di/injection_container.dart';
import 'package:import_service_admin/core/error/exceptions.dart';
import 'package:import_service_admin/core/logging/one_c_log.dart';
import 'package:import_service_admin/core/theme/app_theme.dart';
import 'package:import_service_admin/core/ui/app_snackbars.dart';
import 'package:import_service_admin/core/ui/server_error_ui.dart';
import 'package:import_service_admin/domain/entities/customs_request.dart';
import 'package:import_service_admin/domain/entities/customs_request_delivered_document.dart';
import 'package:import_service_admin/domain/entities/customs_request_file.dart';
import 'package:import_service_admin/domain/entities/customs_request_finance_item.dart';
import 'package:import_service_admin/domain/repositories/customs_requests_repository.dart';
import 'package:import_service_admin/presentation/widgets/requests/request_status_chip.dart';

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

  Future<void> _resendCreate(CustomsRequest item) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await sl<CustomsRequestsRepository>().resendTo1C(item.id);
      if (!mounted) return;
      AppSnackBars.showSuccess('Заявка ${item.id} отправлена в 1С', context: context);
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
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _resendUpdate(CustomsRequest item) async {
    if (_sending) return;
    setState(() => _sending = true);
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
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Заявка № ${widget.requestId}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
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
          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _OneCActionsCard(
                  item: item,
                  sending: _sending,
                  onResendCreate:
                      item.canSendTo1C ? () => _resendCreate(item) : null,
                  onResendUpdate:
                      item.canResendUpdateTo1C ? () => _resendUpdate(item) : null,
                ),
                const Gap(16),
                _Section(
                  title: 'Статус',
                  children: [
                    _Row('Статус', requestStatusLabel(item.status)),
                    if (item.statusSubType != null &&
                        item.statusSubType!.trim().isNotEmpty)
                      _Row('Подстатус', statusSubTypeLabel(item.statusSubType)),
                    if (item.statusSinceDateLabel != null &&
                        item.statusSinceDateLabel!.trim().isNotEmpty)
                      _Row('Дата статуса', item.statusSinceDateLabel!),
                    if (item.statusSubTypeDateTime != null)
                      _Row(
                        'Подстатус с',
                        formatDateTimeLabel(item.statusSubTypeDateTime),
                      ),
                    if (item.dealType != null && item.dealType!.trim().isNotEmpty)
                      _Row('Тип сделки', dealTypeLabel(item.dealType)),
                  ],
                ),
                const Gap(16),
                _Section(
                  title: 'Автомобиль',
                  children: [
                    _Row('Марка / модель', item.carTitle),
                    _Row('VIN', item.vin),
                    if (item.engineSpec != null && item.engineSpec!.trim().isNotEmpty)
                      _Row('Двигатель', item.engineSpec!),
                    if (item.engineVolume != null &&
                        item.engineVolume!.trim().isNotEmpty)
                      _Row('Объём', item.engineVolume!),
                    _Row('Люк / панорама', yesNoLabel(item.hasSunroof)),
                    _Row('Полный привод', yesNoLabel(item.hasAllWheelDrive)),
                    _Row(
                      'Ввоз за 12 мес.',
                      yesNoLabel(item.importedLast12Months),
                    ),
                    _Row('Другие авто', yesNoLabel(item.ownsOtherCars)),
                  ],
                ),
                const Gap(16),
                _Section(
                  title: 'Клиент',
                  children: [
                    _Row('Владелец (отображение)', item.ownerFullName),
                    _Row('Юр. лицо / ИП', item.legalEntityName),
                    _Row('Email', item.legalEmail),
                    _Row('Телефон организации', item.legalPhone),
                    _Row('ФИО физлица', item.individualFullName),
                    _Row('Телефон физлица', item.individualPhone),
                    _Row('СНИЛС', item.individualSnils),
                    if (item.commentText != null &&
                        item.commentText!.trim().isNotEmpty)
                      _Row('Комментарий', item.commentText!),
                  ],
                ),
                const Gap(16),
                _Section(
                  title: '1С',
                  children: [
                    _Row(
                      'ID в 1С',
                      item.external1cId?.trim().isNotEmpty == true
                          ? item.external1cId!
                          : '—',
                    ),
                    _Row(
                      'Менеджер',
                      item.managerFullName?.trim().isNotEmpty == true
                          ? item.managerFullName!
                          : '—',
                    ),
                    if (item.managerExternal1cId != null &&
                        item.managerExternal1cId!.trim().isNotEmpty)
                      _Row('ID менеджера в 1С', item.managerExternal1cId!),
                    _Row(
                      'Update не доставлен',
                      item.oneCUpdatePending ? 'Да' : 'Нет',
                    ),
                    if (item.oneCUpdateLastAttemptAt != null)
                      _Row(
                        'Последняя попытка update',
                        formatDateTimeLabel(item.oneCUpdateLastAttemptAt),
                      ),
                    if (item.oneCUpdateLastError != null) ...[
                      const Gap(8),
                      Text(
                        'Ошибка последнего update',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: const Color(0xFFC62828),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const Gap(4),
                      SelectableText(
                        _formatOneCError(item.oneCUpdateLastError!),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
                if (item.financeItems.isNotEmpty) ...[
                  const Gap(16),
                  _Section(
                    title: 'Оплаты и квитанции',
                    children: [
                      for (final f in item.financeItems) _FinanceTile(item: f),
                    ],
                  ),
                ],
                if (item.files.isNotEmpty) ...[
                  const Gap(16),
                  _Section(
                    title: 'Файлы заявки',
                    children: [
                      for (final f in item.files) _FileLinkTile(file: f),
                    ],
                  ),
                ],
                if (item.vehiclePhotoUrls.isNotEmpty) ...[
                  const Gap(16),
                  _Section(
                    title: 'Фото автомобиля',
                    children: [
                      for (final url in item.vehiclePhotoUrls)
                        _UrlLinkTile(label: 'Фото', url: url),
                    ],
                  ),
                ],
                if (item.deliveredDocuments.isNotEmpty) ...[
                  const Gap(16),
                  _Section(
                    title: 'Итоговые документы',
                    children: [
                      for (final d in item.deliveredDocuments)
                        _DeliveredDocTile(doc: d),
                    ],
                  ),
                ],
                const Gap(16),
                _Section(
                  title: 'Служебное',
                  children: [
                    _Row('Тестовая', item.isTest ? 'Да' : 'Нет'),
                    _Row('Создана', formatDateTimeLabel(item.createdAt)),
                    _Row('Обновлена', formatDateTimeLabel(item.updatedAt)),
                  ],
                ),
                const Gap(24),
              ],
            ),
          );
        },
      ),
    );
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

class _OneCActionsCard extends StatelessWidget {
  const _OneCActionsCard({
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
    final theme = Theme.of(context);
    final needsUpdate = item.oneCUpdatePending;
    final isNew = item.status == 'new';

    return Card(
      elevation: 0,
      color: isNew
          ? const Color(0xFFFFF8E1)
          : needsUpdate
              ? const Color(0xFFFFEBEE)
              : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isNew
              ? const Color(0xFFFFB300)
              : needsUpdate
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
              children: [
                Expanded(
                  child: Text(
                    item.carTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                RequestStatusChip(status: item.status),
              ],
            ),
            const Gap(4),
            Text('№ ${item.id} · ${item.ownerFullName}'),
            if (needsUpdate) ...[
              const Gap(8),
              Text(
                'Изменения не доставлены в 1С',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFC62828),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (onResendCreate != null) ...[
              const Gap(12),
              FilledButton.icon(
                onPressed: sending ? null : onResendCreate,
                icon: _sendingIcon(sending),
                label: const Text('Отправить в 1С'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                ),
              ),
            ],
            if (onResendUpdate != null) ...[
              const Gap(12),
              FilledButton.icon(
                onPressed: sending ? null : onResendUpdate,
                icon: _sendingIcon(sending),
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

  static Widget _sendingIcon(bool sending) {
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const Gap(12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF757575),
                  ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceTile extends StatelessWidget {
  const _FinanceTile({required this.item});

  final CustomsRequestFinanceItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            financeLineLabel(lineType: item.lineType, title: item.title),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (item.amountText != null && item.amountText!.trim().isNotEmpty)
            Text('Сумма: ${item.amountText}'),
          if (item.paymentQrUrl != null && item.paymentQrUrl!.trim().isNotEmpty)
            _UrlLinkTile(label: 'Квитанция / QR', url: item.paymentQrUrl!),
          if (item.receiptUrl != null && item.receiptUrl!.trim().isNotEmpty)
            _UrlLinkTile(label: 'Чек', url: item.receiptUrl!),
        ],
      ),
    );
  }
}

class _FileLinkTile extends StatelessWidget {
  const _FileLinkTile({required this.file});

  final CustomsRequestFile file;

  @override
  Widget build(BuildContext context) {
    return _UrlLinkTile(
      label: docTypeLabel(file.docType, fileName: file.fileName),
      url: file.fileUrl,
      subtitle: file.fileName,
    );
  }
}

class _DeliveredDocTile extends StatelessWidget {
  const _DeliveredDocTile({required this.doc});

  final CustomsRequestDeliveredDocument doc;

  @override
  Widget build(BuildContext context) {
    final title = doc.title.trim().isNotEmpty ? doc.title : 'Документ';
    return _UrlLinkTile(label: title, url: doc.downloadUrl);
  }
}

class _UrlLinkTile extends StatelessWidget {
  const _UrlLinkTile({
    required this.label,
    required this.url,
    this.subtitle,
  });

  final String label;
  final String url;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.link, size: 18, color: AppTheme.primaryBlue),
          const Gap(8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty)
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                SelectableText(
                  url,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.primaryBlue,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
