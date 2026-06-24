import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:import_service_app/core/auth/auth_session_controller.dart';
import 'package:import_service_app/core/constants/customs_catalog.dart';
import 'package:import_service_app/core/constants/api_config.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/extensions/navigation_context.dart';
import 'package:import_service_app/core/push/push_request_handler.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/ui/app_feedback_kind.dart';
import 'package:import_service_app/core/ui/app_feedback_service.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:import_service_app/core/themes/request_status_list_style.dart';
import 'package:import_service_app/data/local/request_detail_section_prefs.dart';
import 'package:import_service_app/domain/entities/car_list_item.dart';
import 'package:import_service_app/domain/entities/customs_request_file.dart';
import 'package:import_service_app/domain/entities/request_status.dart';
import 'package:import_service_app/domain/repositories/cars_repository.dart';
import 'package:import_service_app/presentation/bloc/car_inventory/car_inventory_cubit.dart';
import 'package:import_service_app/presentation/bloc/car_inventory/car_inventory_state.dart';
import 'package:import_service_app/presentation/bloc/request_attention/request_attention_cubit.dart';
import 'package:import_service_app/presentation/bloc/request_attention/request_attention_state.dart';
import 'package:import_service_app/presentation/bloc/request_chat_unread/request_chat_unread_state.dart';
import 'package:import_service_app/presentation/bloc/request_chat_unread/request_chat_unread_cubit.dart';
import 'package:import_service_app/presentation/widgets/app_bar/brand_primary_app_bar.dart';
import 'package:import_service_app/presentation/widgets/chips/request_status_pill.dart';
import 'package:import_service_app/presentation/helpers/doc_type_labels.dart';
import 'package:import_service_app/presentation/helpers/request_status_action_hint.dart';
import 'package:import_service_app/presentation/helpers/request_status_labels.dart';
import 'package:import_service_app/presentation/pages/request_pdf_viewer_page.dart';
import 'package:import_service_app/presentation/helpers/request_file_preview_helper.dart';
import 'package:import_service_app/presentation/helpers/request_file_uploaded_indicator.dart';
import 'package:import_service_app/core/utils/request_file_upload_validation.dart';
import 'package:import_service_app/presentation/helpers/request_attach_failure_message.dart';
import 'package:import_service_app/presentation/helpers/request_detail_pending_actions.dart';
import 'package:import_service_app/presentation/helpers/request_status_sub_type_labels.dart';
import 'package:import_service_app/presentation/widgets/requests/request_detail_action_hint_banner.dart';
import 'package:import_service_app/presentation/widgets/requests/request_detail_files_sections.dart';
import 'package:import_service_app/presentation/widgets/requests/request_detail_deliverable_doc_row.dart';
import 'package:import_service_app/presentation/widgets/requests/request_detail_finances_block.dart';
import 'package:import_service_app/presentation/widgets/requests/request_detail_owner_section.dart';
import 'package:import_service_app/presentation/helpers/request_file_picker.dart';

/// Детализация заявки.
class CarRequestDetailPage extends StatefulWidget {
  const CarRequestDetailPage({
    super.key,
    required this.requestId,
    this.focusDocumentsOnOpen = false,
  });

  final String requestId;
  final bool focusDocumentsOnOpen;

  @override
  State<CarRequestDetailPage> createState() => _CarRequestDetailPageState();
}

class _CarRequestDetailPageState extends State<CarRequestDetailPage> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _documentsAnchorKey = GlobalKey();
  String? _uploadingDocType;
  bool _documentsFocused = false;

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
      if (widget.focusDocumentsOnOpen) {
        _focusDocumentsIfPossible();
      }
    });
  }

  @override
  void dispose() {
    syncCarsTabFromInventory(widget.requestId);
    sl<RequestAttentionCubit>().clearFileHighlights(widget.requestId);
    _scrollController.dispose();
    super.dispose();
  }

  void _focusDocumentsIfPossible() {
    if (_documentsFocused || !mounted) return;
    final ctx = _documentsAnchorKey.currentContext;
    if (ctx == null) return;
    _documentsFocused = true;
    sl<RequestAttentionCubit>().clearDocsAction(widget.requestId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignment: 0.05,
      );
    });
  }

  void _onDocumentOpenFailed() {
    sl<AppFeedbackService>().show(
      sl<JsonStringsService>().requestDocumentOpenFailed,
      kind: AppFeedbackKind.error,
    );
  }

  Future<void> _attachDocType(String docType, CarListItem item) async {
    if (_uploadingDocType != null) return;
    final path = await pickRequestDocumentPath(context);
    if (!mounted || path == null || path.isEmpty) return;
    final s = sl<JsonStringsService>();
    final sizeKey = requestFileSizeLimitMessageKey(path, docType: docType);
    if (sizeKey != null) {
      sl<AppFeedbackService>().show(
        s.text(sizeKey),
        kind: AppFeedbackKind.warning,
      );
      return;
    }
    setState(() => _uploadingDocType = docType);
    final result = await sl<CarsRepository>().attachRequestFile(
      requestId: item.id,
      docType: docType,
      localFilePath: path,
    );
    if (!mounted) return;
    setState(() => _uploadingDocType = null);
    final feedback = sl<AppFeedbackService>();
    await result.fold(
      (failure) async {
        await sl<CarsRepository>().getVehicle(item.id);
        if (!mounted) return;
        setState(() {});
        final updated = _itemFromInventory(item.id);
        final code = normalizeDocType(docType);
        final uploadedDespiteError = updated != null &&
            updated.files.any((f) => normalizeDocType(f.docType) == code);
        if (uploadedDespiteError) {
          await _onAttachSucceeded(docType: docType, itemId: item.id);
        } else {
          final sizeMsg = resolveRequestFileSizeLimitMessage(failure.message, s);
          feedback.show(
            sizeMsg ?? requestAttachFailureMessage(failure.message, s),
            kind: sizeMsg != null ? AppFeedbackKind.warning : AppFeedbackKind.error,
          );
        }
      },
      (_) async {
        await _onAttachSucceeded(docType: docType, itemId: item.id);
      },
    );
  }

  Future<void> _onAttachSucceeded({
    required String docType,
    required String itemId,
  }) async {
    final feedback = sl<AppFeedbackService>();
    final s = sl<JsonStringsService>();
    feedback.show(s.requestFileAttachSuccess, kind: AppFeedbackKind.success);
    final sectionKey = sectionKeyForUploadedDocType(docType);
    if (sectionKey != null) {
      await sl<RequestDetailSectionPrefs>().saveExpanded(
        widget.requestId,
        sectionKey,
        false,
      );
    }
    await sl<CarsRepository>().getVehicle(itemId);
    if (!mounted) return;
    setState(() {});
    final updated = _itemFromInventory(itemId);
    if (updated != null && !hasPendingClientUploadActions(updated)) {
      context.pop();
    }
  }

  CarListItem? _itemFromInventory(String id) {
    for (final candidate in sl<CarInventoryCubit>().state.items) {
      if (candidate.id == id) return candidate;
    }
    return null;
  }

  // Сохранение черновика с деталки временно отключено (v0.1.6).
  // Future<void> _saveAsDraft(CarListItem item) async { ... }

  Widget _buildServerFileRow({
    required ThemeData theme,
    required CustomsRequestFile f,
    required VoidCallback? onTap,
    bool highlight = false,
    String? badge,
    bool embedded = false,
  }) {
    final title = docTypeLabel(f, sl<JsonStringsService>());
    final showUploadedCheck = shouldShowUploadedCheck(f);
    final isVideo = isRequestFileVideo(f);
    final showPdfIcon = isRequestFilePdf(f);
    final rawPath = requestFileFullUrl(f);
    final localFile = rawPath != null &&
            rawPath.isNotEmpty &&
            !rawPath.startsWith('http') &&
            File(rawPath).existsSync()
        ? File(rawPath)
        : null;
    final thumbUrl = localFile == null
        ? _resolveFileUrl(requestFileThumbnailUrl(f))
        : null;
    final hasOpenTarget = localFile != null ||
        (rawPath != null && rawPath.isNotEmpty);
    final showThumbImage =
        localFile != null || (thumbUrl != null && thumbUrl.isNotEmpty);
    final showVideoIcon = isVideo && !showThumbImage;
    final tappable = onTap != null && hasOpenTarget;
    final token = sl<AuthSessionController>().accessToken?.trim();
    final headers = (token != null && token.isNotEmpty)
        ? <String, String>{'Authorization': 'Bearer $token'}
        : null;

    final borderColor = highlight
        ? AppTheme.accentRed.withValues(alpha: 0.55)
        : AppTheme.requestCardBorder;
    final bg = highlight ? AppTheme.accentRed.withValues(alpha: 0.06) : AppTheme.white;

    const outerRadius = 12.0;
    const thumbRadius = 8.0;

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppTheme.pageBackground,
            borderRadius: BorderRadius.circular(thumbRadius),
            border: Border.all(
              color: highlight && !embedded
                  ? AppTheme.requestCardBorder
                  : borderColor,
            ),
          ),
          child: showThumbImage
              ? localFile != null
                  ? Image.file(
                      localFile,
                      fit: BoxFit.cover,
                      width: 64,
                      height: 64,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.insert_drive_file_outlined,
                        size: 24,
                        color: AppTheme.textSecondary.withValues(alpha: 0.85),
                      ),
                    )
                  : Image.network(
                      thumbUrl!,
                      headers: headers,
                      fit: BoxFit.cover,
                      width: 64,
                      height: 64,
                      errorBuilder: (_, _, _) => Icon(
                        isVideo
                            ? Icons.videocam_outlined
                            : Icons.insert_drive_file_outlined,
                        size: 24,
                        color: AppTheme.textSecondary.withValues(alpha: 0.85),
                      ),
                    )
              : Icon(
                  showVideoIcon
                      ? Icons.play_circle_outline
                      : showPdfIcon
                          ? Icons.picture_as_pdf_outlined
                          : Icons.insert_drive_file_outlined,
                  size: showVideoIcon ? 32 : 24,
                  color: AppTheme.textSecondary.withValues(alpha: 0.85),
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
              if (badge != null && badge.isNotEmpty) ...[
                const Gap(4),
                Text(
                  badge,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.accentRed,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ] else if (f.fileName != null &&
                  !isTechnicalRequestFileName(f.fileName) &&
                  f.fileName!.trim().isNotEmpty) ...[
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
        if (showUploadedCheck) ...[
          const Gap(8),
          const Icon(
            Icons.check_circle_rounded,
            size: 24,
            color: Color(0xFF2E7D32),
          ),
        ],
      ],
    );

    if (embedded) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: tappable ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            child: row,
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(outerRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: tappable ? onTap : null,
        borderRadius: BorderRadius.circular(outerRadius),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(outerRadius),
            border: Border.all(color: borderColor),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          child: row,
        ),
      ),
    );
  }

  List<Widget> _buildScrollChildren({
    required BuildContext context,
    required JsonStringsService s,
    required ThemeData theme,
    required CarListItem item,
    required RequestAttentionState attentionState,
  }) {
    final chipText = requestStatusLabel(item.status, s);
    final subTypeLabel = requestStatusSubTypeLabel(item.statusSubType, s);
    final statusDateText = _statusDateText(item);

    final out = <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
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
                    RequestStatusPill(
                      label: chipText,
                      backgroundColor: item.status.listChipBackground,
                      foregroundColor: item.status.listChipForeground,
                    ),
                  ],
                ),
                if (subTypeLabel != null) ...[
                  const Gap(6),
                  Text(
                    subTypeLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
                if (attentionState.hasDocsAction(item.id)) ...[
                  const Gap(6),
                  Text(
                    s.requestCardDocsActionHint,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.accentRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else if (attentionState.hasStatusUpdate(item.id)) ...[
                  const Gap(6),
                  Text(
                    attentionState.statusUpdateSummaryFor(item.id)?.trim().isNotEmpty == true
                        ? attentionState.statusUpdateSummaryFor(item.id)!.trim()
                        : s.requestCardStatusUpdatedHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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

    final urgentHints = requestDetailUrgentActionHints(item, s).toSet().toList();
    for (var i = 0; i < urgentHints.length; i++) {
      if (i > 0) out.add(const Gap(10));
      out.add(RequestDetailActionHintBanner(message: urgentHints[i], urgent: true));
    }

    final infoHint = requestStatusActionHint(item, s);
    if (infoHint != null && !urgentHints.contains(infoHint)) {
      if (urgentHints.isNotEmpty) out.add(const Gap(10));
      out.add(RequestDetailActionHintBanner(message: infoHint));
    }

    if (urgentHints.isNotEmpty || infoHint != null) {
      out.add(const Gap(20));
    }

    out
      ..add(RequestDetailOwnerSection(
        requestId: widget.requestId,
        item: item,
        strings: s,
      ))
      ..add(const Gap(16));

    if (RequestDetailFinancesBlock.shouldShow(item)) {
      out
        ..add(
          RequestDetailFinancesBlock(
            requestId: widget.requestId,
            item: item,
            strings: s,
            onUploadReceipt: (docType) => _attachDocType(docType, item),
          ),
        )
        ..add(const Gap(16));
    }

    if (requestDetailShouldShowDocumentsBlock(item, s)) {
      out
        ..add(const Gap(8))
        ..add(
          KeyedSubtree(
            key: _documentsAnchorKey,
            child: Text(
              s.requestDetailDocumentsTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        )
        ..add(const Gap(10))
        ..add(
          RequestDetailFilesSections(
            requestId: widget.requestId,
            item: item,
            highlightedDocTypes: attentionState.highlightedDocTypesFor(item.id),
            uploadingDocType: _uploadingDocType,
            onUploadDocType: (docType) => _attachDocType(docType, item),
            onTransitPhotoTap: (url) => _openExternalUrl(url),
            buildDeliverableRow: (d) => RequestDetailDeliverableDocRow(
              title: d.title,
              downloadUrl: d.downloadUrl,
              onOpenFailed: () async => _onDocumentOpenFailed(),
            ),
            buildFileRow: (f, {required highlight, badge, embedded = false}) {
              return _buildServerFileRow(
                theme: theme,
                f: f,
                highlight: highlight,
                badge: badge,
                embedded: embedded,
                onTap: () => _openRequestFile(f),
              );
            },
          ),
        );
    }

    // Кнопка временно отключена (v0.1.6).
    // out
    //   ..add(const Gap(20))
    //   ..add(
    //     AppPrimaryOutlinedWideButton(
    //       label: s.requestSaveDraftButton,
    //       onPressed: () => _saveAsDraft(item),
    //     ),
    //   );

    out.add(
      SizedBox(
        height: 40 + MediaQuery.viewPaddingOf(context).bottom,
      ),
    );
    return out;
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _onDocumentOpenFailed();
      return;
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _onDocumentOpenFailed();
    }
  }

  Future<void> _openRequestFile(CustomsRequestFile file) async {
    final resolved = _resolveFileUrl(requestFileFullUrl(file));
    if (resolved == null || resolved.isEmpty) {
      _onDocumentOpenFailed();
      return;
    }
    if (isRequestFileVideo(file)) {
      await _openExternalUrl(resolved);
      return;
    }
    if (isRequestFileImage(file)) {
      final item = _itemFromInventory(widget.requestId);
      if (item == null) {
        _onDocumentOpenFailed();
        return;
      }
      final images = item.files.where(isRequestFileImage).toList();
      final index = images.indexWhere(
        (e) => e.docType == file.docType && e.fileUrl == file.fileUrl,
      );
      if (index < 0) {
        _onDocumentOpenFailed();
        return;
      }
      _openImageCarousel(images, index);
      return;
    }

    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final localPath = await downloadAuthenticatedRequestFile(resolved, file);
    if (mounted) Navigator.of(context, rootNavigator: true).pop();

    if (!mounted) return;
    if (localPath == null) {
      _onDocumentOpenFailed();
      return;
    }

    if (!mounted) return;
    if (await shouldOpenAsInAppPdf(localPath, file)) {
      if (!mounted) return;
      final title = docTypeLabel(file, sl<JsonStringsService>());
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => RequestPdfViewerPage(
            filePath: localPath,
            title: title,
          ),
        ),
      );
      return;
    }

    _onDocumentOpenFailed();
  }

  void _openImageCarousel(List<CustomsRequestFile> images, int selectedIndex) {
    final prepared = <_CarouselPhotoItem>[];
    for (var i = 0; i < images.length; i++) {
      final f = images[i];
      final fullUrl = _resolveFileUrl(requestFileFullUrl(f));
      if (fullUrl == null || fullUrl.isEmpty) continue;
      final thumbUrl =
          _resolveFileUrl(requestFileThumbnailUrl(f)) ?? fullUrl;
      prepared.add(
        _CarouselPhotoItem(
          fullUrl: fullUrl,
          thumbUrl: thumbUrl,
          title: docTypeLabel(f, sl<JsonStringsService>()),
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
    final showChatFab = requestChatAvailable(
      status: item.status,
      external1cId: item.external1cId,
      managerFullName: item.managerFullName,
    );
    final sub = RequestStatusSubType.tryParse(item.statusSubType);
    final shouldFocusDocs = sub == RequestStatusSubType.primaryDocumentsSent ||
        sub == RequestStatusSubType.signatureRevisionRequired;
    if (shouldFocusDocs || widget.focusDocumentsOnOpen) {
      _focusDocumentsIfPossible();
    } else {
      _documentsFocused = false;
    }
    return BlocBuilder<RequestAttentionCubit, RequestAttentionState>(
      bloc: sl<RequestAttentionCubit>(),
      builder: (context, attentionState) => BlocBuilder<RequestChatUnreadCubit, RequestChatUnreadState>(
        bloc: sl<RequestChatUnreadCubit>(),
        builder: (context, unreadState) {
          final hasUnreadChat = unreadState.has(item.id);
          return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: BrandPrimaryAppBar(title: title),
      floatingActionButton: showChatFab
          ? FloatingActionButton(
              onPressed: () {
                sl<RequestChatUnreadCubit>().clearUnread(item.id);
                context.pushRequestChat(item.id);
              },
              backgroundColor: AppTheme.accentRed,
              foregroundColor: AppTheme.white,
              shape: const CircleBorder(),
              tooltip: s.requestDetailChatA11y,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded),
                  if (hasUnreadChat)
                    const Positioned(
                      right: -1,
                      top: -1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppTheme.white,
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox(width: 8, height: 8),
                      ),
                    ),
                ],
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        children: _buildScrollChildren(
          context: context,
          s: s,
          theme: theme,
          item: item,
          attentionState: attentionState,
        ),
      ),
          );
        },
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

String? _statusDateText(CarListItem item) {
  final subDt = item.statusSubTypeDateTime?.trim();
  if (subDt != null && subDt.isNotEmpty) {
    final parsed = DateTime.tryParse(subDt);
    if (parsed != null) {
      return 'С ${DateFormat('dd.MM.yyyy').format(parsed.toLocal())}';
    }
  }
  final source = item.status == RequestStatus.delivered
      ? item.updatedAt?.trim()
      : item.createdAt?.trim();
  if (source == null || source.isEmpty) return null;
  final prefix = item.status == RequestStatus.delivered ? 'Прибыл' : 'Создано';
  final parsed = DateTime.tryParse(source);
  if (parsed == null) return '$prefix: $source';
  return '$prefix: ${DateFormat('dd.MM.yyyy HH:mm').format(parsed.toLocal())}';
}

final class _CarouselPhotoItem {
  const _CarouselPhotoItem({
    required this.fullUrl,
    required this.thumbUrl,
    required this.title,
    required this.sourceIndex,
  });

  final String fullUrl;
  final String thumbUrl;
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
                      item.fullUrl,
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
                        item.thumbUrl,
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


CarListItem? _findItem(List<CarListItem> items, String id) {
  for (final e in items) {
    if (e.id == id) return e;
  }
  return null;
}

