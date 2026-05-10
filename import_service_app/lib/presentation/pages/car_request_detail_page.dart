import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:import_service_app/core/auth/auth_session_controller.dart';
import 'package:import_service_app/core/constants/api_config.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/extensions/navigation_context.dart';
import 'package:import_service_app/core/util/vin_display.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/ui/app_feedback_kind.dart';
import 'package:import_service_app/core/ui/app_feedback_service.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/domain/entities/car_list_item.dart';
import 'package:import_service_app/domain/entities/customs_request_file.dart';
import 'package:import_service_app/domain/entities/request_status.dart';
import 'package:import_service_app/domain/repositories/cars_repository.dart';
import 'package:import_service_app/presentation/bloc/car_inventory/car_inventory_cubit.dart';
import 'package:import_service_app/presentation/bloc/car_inventory/car_inventory_state.dart';
import 'package:import_service_app/presentation/widgets/app_bar/brand_primary_app_bar.dart';
import 'package:import_service_app/presentation/widgets/chips/request_status_pill.dart';
import 'package:import_service_app/presentation/helpers/request_detail_line_labels.dart';
import 'package:import_service_app/presentation/widgets/requests/request_detail_deliverable_doc_row.dart';
import 'package:import_service_app/presentation/widgets/requests/request_detail_finance_card.dart';
import 'package:import_service_app/presentation/widgets/requests/request_detail_photo_urls_row.dart';

/// Детализация заявки. Для [RequestStatus.newRequest] чат FAB не показывается.
class CarRequestDetailPage extends StatefulWidget {
  const CarRequestDetailPage({super.key, required this.requestId});

  final String requestId;

  @override
  State<CarRequestDetailPage> createState() => _CarRequestDetailPageState();
}

class _CarRequestDetailPageState extends State<CarRequestDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await sl<CarsRepository>().listVehicles();
      if (mounted) setState(() {});
      if (!sl<AuthSessionController>().isDemo) {
        await sl<CarsRepository>().getVehicle(widget.requestId);
        if (mounted) setState(() {});
      }
    });
  }

  void _onDemoBlock() {
    sl<AppFeedbackService>().show(
      sl<JsonStringsService>().demoActionUnavailable,
      kind: AppFeedbackKind.warning,
    );
  }

  Widget _buildServerFileRow({
    required ThemeData theme,
    required CustomsRequestFile f,
    required VoidCallback? onTap,
  }) {
    final title = _docTypeLabel(f, sl<JsonStringsService>());
    final url = _resolveFileUrl(f.fileUrl);
    final tappable = url != null && url.isNotEmpty;
    final token = sl<AuthSessionController>().accessToken?.trim();
    final headers = (token != null && token.isNotEmpty)
        ? <String, String>{'Authorization': 'Bearer $token'}
        : null;

    return Material(
      color: AppTheme.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: tappable ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.pageBackground,
                    border: Border.all(color: AppTheme.requestCardBorder),
                  ),
                  child: tappable
                      ? Image.network(
                          url,
                          headers: headers,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.insert_drive_file_outlined,
                            size: 24,
                            color: AppTheme.textSecondary.withValues(alpha: 0.85),
                          ),
                        )
                      : Icon(
                          Icons.insert_drive_file_outlined,
                          size: 24,
                          color: AppTheme.textSecondary.withValues(alpha: 0.85),
                        ),
                ),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    if (f.fileName != null && f.fileName!.trim().isNotEmpty) ...[
                      const Gap(4),
                      Text(
                        f.fileName!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildScrollChildren({
    required BuildContext context,
    required JsonStringsService s,
    required ThemeData theme,
    required CarListItem item,
  }) {
    final st = item.statusSubType;
    final chipText = (st != null && st.isNotEmpty)
        ? s.requestDetailStatusSubTypeLabel(st)
        : _statusLabel(item.status);
    final statusDateText = _statusDateText(item);

    final out = <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 6,
              children: [
                Text(
                  s.requestDetailStatusLabel,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                RequestStatusPill(label: chipText),
              ],
            ),
          ),
          if (statusDateText != null)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Text(
                statusDateText,
                textAlign: TextAlign.right,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
        ],
      ),
      const Gap(20),
    ];

    for (var i = 0; i < item.deliveredDocuments.length; i++) {
      final d = item.deliveredDocuments[i];
      out.add(
        RequestDetailDeliverableDocRow(
          title: d.title,
          downloadUrl: d.downloadUrl,
          onOpenFailed: () async => _onDemoBlock(),
        ),
      );
      if (i < item.deliveredDocuments.length - 1) {
        out.add(const Gap(8));
      }
    }
    if (item.deliveredDocuments.isNotEmpty) {
      out.add(const Gap(20));
    }

    out
      ..add(
        _LabeledValue(
          label: s.requestDetailOwner,
          value: item.ownerFullName,
          theme: theme,
        ),
      )
      ..add(const Gap(14))
      ..add(
        _LabeledValue(
          label: s.requestDetailVehicle,
          value: item.displayCarLine,
          theme: theme,
        ),
      );

    if ((item.engineSpec != null && item.engineSpec!.trim().isNotEmpty) ||
        (item.engineVolume != null && item.engineVolume!.trim().isNotEmpty)) {
      out
        ..add(const Gap(14))
        ..add(
          _EngineLabeled(
            label: s.requestDetailEngine,
            specLine: item.engineSpec != null && item.engineSpec!.trim().isNotEmpty
                ? item.engineSpec!.trim()
                : null,
            volumeLine: item.engineVolume != null && item.engineVolume!.trim().isNotEmpty
                ? item.engineVolume!.trim()
                : null,
            theme: theme,
          ),
        );
    }

    out
      ..add(const Gap(14))
      ..add(
        _LabeledValue(
          label: s.requestDetailVin,
          value: formatVinForDetail(item.vin),
          theme: theme,
        ),
      );

    if (item.financeItems.isNotEmpty) {
      out
        ..add(const Gap(24))
        ..add(
          Text(
            s.requestDetailFinances,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        )
        ..add(const Gap(10));
      for (var i = 0; i < item.financeItems.length; i++) {
        final line = item.financeItems[i];
        out.add(
          RequestDetailFinanceCard(
            line: line,
            label: financeItemLabel(line, s),
            receiptCaption: s.requestDetailReceiptCaption,
            uploadLabel: s.requestDetailUploadReceipt,
            openReceiptLabel: s.requestDetailOpenReceipt,
            onUploadTap: _onDemoBlock,
          ),
        );
        if (i < item.financeItems.length - 1) {
          out.add(const Gap(10));
        }
      }
      out.add(const Gap(20));
    }

    if (sl<AuthSessionController>().isDemo && item.vehiclePhotoUrls.isNotEmpty) {
      out
        ..add(const Gap(24))
        ..add(
          Text(
            s.requestDetailPhoto,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        )
        ..add(const Gap(10))
        ..add(
          RequestDetailPhotoUrlsRow(
            urls: item.vehiclePhotoUrls,
            onTileTap: (_) => _onDemoBlock(),
          ),
        );
    }

    if (item.files.isNotEmpty) {
      out
        ..add(const Gap(24))
        ..add(
          Container(
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.6)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: false,
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 8, bottom: 4),
                title: Text(
                  'Фото заявки',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                children: [
                  for (var i = 0; i < item.files.length; i++) ...[
                    _buildServerFileRow(
                      theme: theme,
                      f: item.files[i],
                      onTap: () => _openFilesCarousel(item.files, i),
                    ),
                    if (i < item.files.length - 1) const Gap(8),
                  ],
                ],
              ),
            ),
          ),
        );
    }

    out.add(
      SizedBox(
        height: 40 + MediaQuery.viewPaddingOf(context).bottom,
      ),
    );
    return out;
  }

  void _openFilesCarousel(List<CustomsRequestFile> files, int selectedIndex) {
    final prepared = <_CarouselPhotoItem>[];
    for (var i = 0; i < files.length; i++) {
      final f = files[i];
      final url = _resolveFileUrl(f.fileUrl);
      if (url == null || url.isEmpty) continue;
      prepared.add(
        _CarouselPhotoItem(
          url: url,
          title: _docTypeLabel(f, sl<JsonStringsService>()),
          sourceIndex: i,
        ),
      );
    }
    if (prepared.isEmpty) return;
    var startIndex = 0;
    for (var i = 0; i < prepared.length; i++) {
      if (prepared[i].sourceIndex == selectedIndex) {
        startIndex = i;
        break;
      }
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _RequestPhotoCarouselPage(
          items: prepared,
          initialIndex: startIndex,
          authToken: sl<AuthSessionController>().accessToken,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CarInventoryCubit, CarInventoryState>(
      bloc: sl<CarInventoryCubit>(),
      builder: (context, state) {
        if (state.items.isEmpty) {
          return Scaffold(
            appBar: BrandPrimaryAppBar(
              title: sl<JsonStringsService>().carsTabTitle,
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final item = _findItem(state.items, widget.requestId);
        if (item == null) {
          return const _NotFoundBody();
        }
        return _body(context, item);
      },
    );
  }

  Widget _body(BuildContext context, CarListItem item) {
    final s = sl<JsonStringsService>();
    final theme = Theme.of(context);
    final title = item.displayCarLine;
    final showChatFab = item.status != RequestStatus.newRequest;
    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: BrandPrimaryAppBar(title: title),
      floatingActionButton: showChatFab
          ? FloatingActionButton(
              onPressed: () {
                context.pushRequestChat(item.id);
              },
              backgroundColor: AppTheme.accentRed,
              foregroundColor: AppTheme.white,
              shape: const CircleBorder(),
              tooltip: s.requestDetailChatA11y,
              child: const Icon(Icons.chat_bubble_outline_rounded),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        children: _buildScrollChildren(
          context: context,
          s: s,
          theme: theme,
          item: item,
        ),
      ),
    );
  }
}

String? _resolveFileUrl(String? rawUrl) {
  final value = rawUrl?.trim();
  if (value == null || value.isEmpty) return null;
  if (value.startsWith('http://') || value.startsWith('https://')) return value;
  final base = ApiConfig.baseUrl.trim();
  final normalized = base.endsWith('/') ? base : '$base/';
  final apiUri = Uri.parse(normalized);
  return apiUri.resolve(value.startsWith('/') ? value.substring(1) : value).toString();
}

String _docTypeLabel(CustomsRequestFile file, JsonStringsService s) {
  switch ((file.docType ?? '').trim().toLowerCase()) {
    case 'passport_front':
      return s.text('reqPassportFrontLabel');
    case 'passport_registration':
      return s.text('reqPassportAddressLabel');
    case 'inn':
      return s.text('reqInnFileLabel');
    case 'snils':
      return s.text('reqSnilsFileLabel');
    case 'title_doc':
      return s.text('reqInvoiceFileLabel');
    case 'contract':
      return s.text('reqContractFileLabel');
    case 'payment_check':
      return s.text('reqPaymentReceiptFileLabel');
    case 'car_front_photo':
      return s.text('reqCarFrontFileLabel');
    case 'car_back_photo':
      return s.text('reqCarRearFileLabel');
    case 'additional_file':
      return s.text('reqAdditionalFile1Label');
    default:
      return file.fileName?.trim().isNotEmpty == true ? file.fileName!.trim() : 'Файл';
  }
}

String? _statusDateText(CarListItem item) {
  final source = item.status == RequestStatus.delivered
      ? (item.statusSinceDateLabel?.trim().isNotEmpty == true
          ? item.statusSinceDateLabel!.trim()
          : item.updatedAt?.trim())
      : item.createdAt?.trim();
  if (source == null || source.isEmpty) return null;
  final prefix = item.status == RequestStatus.delivered ? 'Прибыл' : 'Создано';
  final parsed = DateTime.tryParse(source);
  if (parsed == null) return '$prefix: $source';
  return '$prefix: ${DateFormat('dd.MM.yyyy HH:mm').format(parsed.toLocal())}';
}

final class _CarouselPhotoItem {
  const _CarouselPhotoItem({
    required this.url,
    required this.title,
    required this.sourceIndex,
  });

  final String url;
  final String title;
  final int sourceIndex;
}

class _RequestPhotoCarouselPage extends StatefulWidget {
  const _RequestPhotoCarouselPage({
    required this.items,
    required this.initialIndex,
    required this.authToken,
  });

  final List<_CarouselPhotoItem> items;
  final int initialIndex;
  final String? authToken;

  @override
  State<_RequestPhotoCarouselPage> createState() => _RequestPhotoCarouselPageState();
}

class _RequestPhotoCarouselPageState extends State<_RequestPhotoCarouselPage> {
  static const int _loopSeed = 1000;
  late final PageController _controller;
  late int _index;
  late int _page;

  @override
  void initState() {
    super.initState();
    final len = widget.items.length;
    _page = _loopSeed * len + widget.initialIndex;
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _page);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final token = widget.authToken?.trim();
    final headers = (token != null && token.isNotEmpty)
        ? <String, String>{'Authorization': 'Bearer $token'}
        : null;
    final current = widget.items[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_index + 1}/${widget.items.length}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (value) => setState(() {
                _page = value;
                _index = value % widget.items.length;
              }),
              itemBuilder: (context, index) {
                final item = widget.items[index % widget.items.length];
                return Center(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Image.network(
                      item.url,
                      headers: headers,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white70,
                        size: 56,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            height: 72,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: widget.items.length,
              separatorBuilder: (_, _) => const Gap(8),
              itemBuilder: (context, index) {
                final item = widget.items[index];
                final active = index == _index;
                return GestureDetector(
                  onTap: () {
                    _controller.animateToPage(
                      _nearestLoopPageIndex(index),
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: active ? Colors.white : Colors.white30,
                        width: active ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Image.network(
                        item.url,
                        headers: headers,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: Color(0xFF2B2B2B),
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white60,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Text(
              current.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _nearestLoopPageIndex(int targetIndex) {
    final len = widget.items.length;
    final currentCycle = _page ~/ len;
    final candidates = <int>[
      (currentCycle - 1) * len + targetIndex,
      currentCycle * len + targetIndex,
      (currentCycle + 1) * len + targetIndex,
    ];
    candidates.sort((a, b) => (a - _page).abs().compareTo((b - _page).abs()));
    return candidates.first;
  }
}

class _NotFoundBody extends StatelessWidget {
  const _NotFoundBody();

  @override
  Widget build(BuildContext context) {
    final s = sl<JsonStringsService>();
    return Scaffold(
      appBar: BrandPrimaryAppBar(title: s.requestDetailNotFound),
      body: const Center(
        child: Icon(
          Icons.search_off_rounded,
          size: 40,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}

class _LabeledValue extends StatelessWidget {
  const _LabeledValue({
    required this.label,
    required this.value,
    required this.theme,
  });

  final String label;
  final String value;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        const Gap(4),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EngineLabeled extends StatelessWidget {
  const _EngineLabeled({
    required this.label,
    this.specLine,
    this.volumeLine,
    required this.theme,
  });

  final String label;
  final String? specLine;
  final String? volumeLine;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        const Gap(4),
        if (specLine != null)
          Text(
            specLine!,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        if (specLine != null && volumeLine != null) const Gap(4),
        if (volumeLine != null)
          Text(
            volumeLine!,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

CarListItem? _findItem(List<CarListItem> items, String id) {
  for (final e in items) {
    if (e.id == id) return e;
  }
  return null;
}

String _statusLabel(RequestStatus status) {
  final s = sl<JsonStringsService>();
  switch (status) {
    case RequestStatus.newRequest:
      return s.carStatusNew;
    case RequestStatus.inProgress:
      return s.carStatusInWork;
    case RequestStatus.inTransit:
      return s.carStatusOnWay;
    case RequestStatus.delivered:
      return s.carStatusDelivered;
  }
}
