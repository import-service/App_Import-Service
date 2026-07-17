import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
import 'package:import_service_admin/presentation/widgets/auth_network_image.dart';
import 'package:import_service_admin/presentation/widgets/requests/request_detail_file_row.dart';
import 'package:import_service_admin/presentation/widgets/requests/request_detail_files_sections.dart';
import 'package:import_service_admin/presentation/widgets/requests/request_detail_finance_card.dart';
import 'package:import_service_admin/presentation/widgets/requests/request_labeled_value.dart';
import 'package:import_service_admin/presentation/widgets/requests/request_status_pill.dart';
import 'package:url_launcher/url_launcher.dart';

// Web-only blob open (admin is Flutter Web).
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show Blob, Url, IFrameElement;
import 'dart:ui_web' as ui_web;

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
    if (url == null) {
      AppSnackBars.showError('Нет URL файла', context: context);
      return;
    }
    final mime = (file.mimeType ?? '').toLowerCase();
    final doc = file.docType.toLowerCase();
    final name = file.fileName.toLowerCase();
    final stored = (file.storedName ?? '').toLowerCase();
    final looksImageByMeta = mime.startsWith('image/') ||
        doc.startsWith('transit_archive_photo') ||
        doc.contains('_photo') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.webp') ||
        name.endsWith('.gif') ||
        stored.endsWith('.jpg') ||
        stored.endsWith('.jpeg') ||
        stored.endsWith('.png');
    final looksPdfByMeta =
        mime.contains('pdf') || name.endsWith('.pdf') || stored.endsWith('.pdf');
    final token = _token?.trim();
    final headers = <String, String>{
      'Accept': '*/*',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    if (looksImageByMeta && mounted) {
      await _showImageDialog(file, url, token);
      return;
    }

    try {
      final resp = await sl<Dio>().get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: headers,
          contentType: null,
          receiveTimeout: const Duration(seconds: 60),
          extra: const {'skipSessionExpired': true},
        ),
      );
      final data = resp.data;
      if (data == null || data.isEmpty) {
        if (mounted) {
          AppSnackBars.showError('Пустой файл', context: context);
        }
        return;
      }
      final bytes = Uint8List.fromList(data);
      final sniffed = _sniffFileKind(bytes);

      if (sniffed == _SniffedKind.image) {
        if (!mounted) return;
        await _showImageDialog(file, url, token, bytes: bytes);
        return;
      }

      if (sniffed == _SniffedKind.pdf || looksPdfByMeta) {
        if (!mounted) return;
        await _showPdfDialog(file, bytes);
        return;
      }

      if (sniffed == _SniffedKind.archive) {
        if (mounted) {
          AppSnackBars.showError(
            'Это архив (RAR/ZIP), а не фото — просмотр недоступен',
            context: context,
          );
        }
        return;
      }

      if (sniffed == _SniffedKind.unknown &&
          (mime.contains('octet-stream') ||
              name.endsWith('.bin') ||
              stored.endsWith('.bin'))) {
        if (mounted) {
          AppSnackBars.showError(
            'Этот тип файла нельзя открыть (.bin / неизвестный формат)',
            context: context,
          );
        }
        return;
      }

      if (kIsWeb) {
        final blobMime = mime.isNotEmpty && !mime.contains('octet-stream')
            ? mime
            : 'application/octet-stream';
        if (blobMime.contains('octet-stream')) {
          if (mounted) {
            AppSnackBars.showError(
              'Этот тип файла нельзя открыть',
              context: context,
            );
          }
          return;
        }
        // Не PDF и не картинка — не предлагаем скачивание/новую вкладку.
        if (mounted) {
          AppSnackBars.showError(
            'Этот тип файла нельзя открыть в окне просмотра',
            context: context,
          );
        }
        return;
      }
      final uri = Uri.tryParse(url);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBars.showError('Не удалось открыть файл: $e', context: context);
      }
    }
  }

  Future<void> _showPdfDialog(CustomsRequestFile file, Uint8List bytes) async {
    if (!kIsWeb) {
      AppSnackBars.showError('Просмотр PDF доступен в веб-админке', context: context);
      return;
    }
    final blob = html.Blob([bytes], 'application/pdf');
    final objUrl = html.Url.createObjectUrlFromBlob(blob);
    final viewType =
        'admin-pdf-${identityHashCode(bytes)}-${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = objUrl
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      return iframe;
    });

    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          docTypeLabel(file.docType, fileName: file.fileName),
                          style: Theme.of(ctx).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: HtmlElementView(viewType: viewType),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      html.Url.revokeObjectUrl(objUrl);
    }
  }

  Future<void> _showImageDialog(
    CustomsRequestFile file,
    String url,
    String? token, {
    Uint8List? bytes,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        docTypeLabel(file.docType, fileName: file.fileName),
                        style: Theme.of(ctx).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: InteractiveViewer(
                  child: bytes != null
                      ? Image.memory(bytes, fit: BoxFit.contain)
                      : AuthNetworkImage(
                          url: url,
                          authToken: token,
                          fit: BoxFit.contain,
                          errorWidget: const Center(
                            child: Icon(Icons.broken_image_outlined, size: 48),
                          ),
                        ),
                ),
              ),
              if ((file.sourceFileName ?? '').isNotEmpty ||
                  (file.sourceMimeType ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Upload: ${[
                      if ((file.sourceFileName ?? '').isNotEmpty) file.sourceFileName,
                      if ((file.sourceMimeType ?? '').isNotEmpty) file.sourceMimeType,
                      if ((file.mimeType ?? '').isNotEmpty) '→ ${file.mimeType}',
                    ].join(' · ')}',
                    style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                          color: AppTheme.textSecondary,
                          fontFamily: 'monospace',
                        ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static _SniffedKind _sniffFileKind(Uint8List bytes) {
    if (bytes.length < 4) return _SniffedKind.unknown;
    if (bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff) {
      return _SniffedKind.image;
    }
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47) {
      return _SniffedKind.image;
    }
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
      return _SniffedKind.image;
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return _SniffedKind.image;
    }
    if (bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46) {
      return _SniffedKind.pdf;
    }
    // RAR
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x61 &&
        bytes[2] == 0x72 &&
        bytes[3] == 0x21) {
      return _SniffedKind.archive;
    }
    // ZIP
    if (bytes[0] == 0x50 && bytes[1] == 0x4b) {
      return _SniffedKind.archive;
    }
    return _SniffedKind.unknown;
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Информация'),
              Tab(text: 'Документы'),
            ],
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
            return Stack(
              children: [
                TabBarView(
                  children: [
                    RefreshIndicator(
                      onRefresh: () async {
                        _reload();
                        await _future;
                      },
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                        children: _buildInfoSections(context, item),
                      ),
                    ),
                    RefreshIndicator(
                      onRefresh: () async {
                        _reload();
                        await _future;
                      },
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                        children: _buildDocsSections(context, item),
                      ),
                    ),
                  ],
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
      ),
    );
  }

  List<Widget> _buildInfoSections(BuildContext context, CustomsRequest item) {
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

  List<Widget> _buildDocsSections(BuildContext context, CustomsRequest item) {
    final theme = Theme.of(context);
    final collapsed = _collapseArchiveGroups(item.files);
    return [
      Text(
        'Документы',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      const Gap(10),
      RequestDetailFilesSections(
        files: collapsed.files,
        deliveredDocuments: item.deliveredDocuments,
        vehiclePhotoUrls: item.vehiclePhotoUrls,
        authToken: _token,
        buildFileRow: (f) {
          final children = collapsed.groups[f.id];
          if (children != null && children.length > 1) {
            return RequestDetailFileRow(
              file: f,
              authToken: _token,
              groupCount: children.length,
              onOpen: () => _openArchiveCarousel(f, children),
            );
          }
          return RequestDetailFileRow(
            file: f,
            authToken: _token,
            onOpen: () => _openFile(f),
          );
        },
      ),
    ];
  }

  /// Свернуть файлы одного архива (X_1..X_N с общим sourceFileName) в один вход.
  ({List<CustomsRequestFile> files, Map<String, List<CustomsRequestFile>> groups})
      _collapseArchiveGroups(List<CustomsRequestFile> files) {
    final re = RegExp(r'^(.+)_(\d+)$');
    final byKey = <String, List<CustomsRequestFile>>{};
    final keyOf = <String, String>{};
    for (final f in files) {
      final src = (f.sourceFileName ?? '').trim();
      final m = re.firstMatch(f.docType.trim());
      if (src.isEmpty || m == null) continue;
      final key = '${m.group(1)}|$src';
      byKey.putIfAbsent(key, () => []).add(f);
      keyOf[f.id] = key;
    }
    final qualifying = <String>{
      for (final e in byKey.entries)
        if (e.value.length >= 2) e.key,
    };

    final resultFiles = <CustomsRequestFile>[];
    final groups = <String, List<CustomsRequestFile>>{};
    final seen = <String>{};
    for (final f in files) {
      final key = keyOf[f.id];
      if (key != null && qualifying.contains(key)) {
        if (seen.contains(key)) continue;
        seen.add(key);
        final children = [...byKey[key]!]
          ..sort((a, b) => _suffixNum(a.docType).compareTo(_suffixNum(b.docType)));
        final rep = _archiveRepresentative(children.first);
        resultFiles.add(rep);
        groups[rep.id] = children;
      } else {
        resultFiles.add(f);
      }
    }
    return (files: resultFiles, groups: groups);
  }

  static int _suffixNum(String docType) {
    final m = RegExp(r'_(\d+)$').firstMatch(docType.trim());
    return m == null ? 0 : int.tryParse(m.group(1)!) ?? 0;
  }

  static CustomsRequestFile _archiveRepresentative(CustomsRequestFile first) {
    final base =
        RegExp(r'^(.+)_(\d+)$').firstMatch(first.docType.trim())?.group(1) ??
            first.docType;
    return CustomsRequestFile(
      id: first.id,
      docType: base,
      fileName: first.fileName,
      fileUrl: first.fileUrl,
      mimeType: first.mimeType,
      fileSizeBytes: first.fileSizeBytes,
      previewUrl: first.previewUrl,
      storedName: first.storedName,
      sourceFileName: first.sourceFileName,
      sourceMimeType: first.sourceMimeType,
      uploadSource: first.uploadSource,
    );
  }

  Future<void> _openArchiveCarousel(
    CustomsRequestFile rep,
    List<CustomsRequestFile> children,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _ArchiveCarouselDialog(
        title: docTypeLabel(rep.docType, fileName: rep.fileName),
        files: children,
        authToken: _token?.trim(),
        onOpenFile: (f) {
          Navigator.pop(ctx);
          _openFile(f);
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

enum _SniffedKind { image, pdf, archive, unknown }

/// Карусель картинок/файлов, извлечённых из одного архива.
class _ArchiveCarouselDialog extends StatefulWidget {
  const _ArchiveCarouselDialog({
    required this.title,
    required this.files,
    required this.onOpenFile,
    this.authToken,
  });

  final String title;
  final List<CustomsRequestFile> files;
  final String? authToken;
  final void Function(CustomsRequestFile file) onOpenFile;

  @override
  State<_ArchiveCarouselDialog> createState() => _ArchiveCarouselDialogState();
}

class _ArchiveCarouselDialogState extends State<_ArchiveCarouselDialog> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isImage(CustomsRequestFile f) {
    final m = (f.mimeType ?? '').toLowerCase();
    if (m.startsWith('image/')) return true;
    if (m.contains('pdf')) return false;
    final n = f.fileName.toLowerCase();
    final s = (f.storedName ?? '').toLowerCase();
    for (final e in const ['.jpg', '.jpeg', '.png', '.webp', '.gif']) {
      if (n.endsWith(e) || s.endsWith(e)) return true;
    }
    final d = f.docType.toLowerCase();
    return d.contains('_photo') || d.startsWith('transit_archive_photo');
  }

  void _go(int delta) {
    final next = (_index + delta).clamp(0, widget.files.length - 1);
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = widget.files.length;
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 820),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${widget.title} · ${_index + 1}/$total',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PageView.builder(
                    controller: _controller,
                    itemCount: total,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (_, i) {
                      final f = widget.files[i];
                      final full = resolveFileUrl(f.fileUrl);
                      final preview = resolveFileUrl(f.displayUrl);
                      if (!_isImage(f) || full == null) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.insert_drive_file_outlined, size: 48),
                              const Gap(12),
                              Text(f.fileName, textAlign: TextAlign.center),
                              const Gap(12),
                              FilledButton.icon(
                                onPressed: () => widget.onOpenFile(f),
                                icon: const Icon(Icons.open_in_new),
                                label: const Text('Открыть файл'),
                              ),
                            ],
                          ),
                        );
                      }
                      return InteractiveViewer(
                        child: AuthNetworkImage(
                          url: full,
                          fallbackUrls: [
                            if (preview != null && preview != full) preview,
                          ],
                          authToken: widget.authToken,
                          fit: BoxFit.contain,
                          errorWidget: const Center(
                            child: Icon(Icons.broken_image_outlined, size: 48),
                          ),
                        ),
                      );
                    },
                  ),
                  if (total > 1) ...[
                    Positioned(
                      left: 8,
                      child: _CarouselNavButton(
                        icon: Icons.chevron_left,
                        onTap: _index > 0 ? () => _go(-1) : null,
                      ),
                    ),
                    Positioned(
                      right: 8,
                      child: _CarouselNavButton(
                        icon: Icons.chevron_right,
                        onTap: _index < total - 1 ? () => _go(1) : null,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarouselNavButton extends StatelessWidget {
  const _CarouselNavButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }
}
