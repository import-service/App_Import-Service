import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:import_service_app/core/auth/auth_session_controller.dart';
import 'package:import_service_app/core/auth/session_role.dart';
import 'package:import_service_app/core/constants/customs_catalog.dart';
import 'package:import_service_app/core/constants/api_config.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/extensions/navigation_context.dart';
import 'package:import_service_app/core/logging/app_log.dart';
import 'package:import_service_app/core/push/push_request_handler.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/ui/app_feedback_kind.dart';
import 'package:import_service_app/core/ui/app_feedback_service.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:import_service_app/core/themes/request_status_list_style.dart';
import 'package:import_service_app/data/demo/demo_pdf_factory.dart';
import 'package:import_service_app/data/demo/demo_seed_files.dart';
import 'package:import_service_app/data/local/request_detail_section_prefs.dart';
import 'package:import_service_app/data/local/request_draft_attachments_space.dart';
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
import 'package:import_service_app/presentation/pages/request_video_player_page.dart';
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
import 'package:import_service_app/presentation/widgets/requests/request_file_video_thumb.dart';
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
  bool _uploadingSvhCarGallery = false;
  bool _uploadingSvhCarVideos = false;
  bool _uploadingTransitArchiveGallery = false;
  bool _uploadingOtherDocsGallery = false;
  bool _documentsFocused = false;

  bool get _anyUploadBusy =>
      _uploadingDocType != null ||
      _uploadingSvhCarGallery ||
      _uploadingSvhCarVideos ||
      _uploadingTransitArchiveGallery ||
      _uploadingOtherDocsGallery;

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
    if (item.isArchivedOffline) return;
    if (_anyUploadBusy) return;
    final svh = isSvhManagerSession(sl<AuthSessionController>());
    if (svh && !isSvhManagerAllowedDocType(docType)) {
      sl<AppFeedbackService>().show(
        sl<JsonStringsService>().text('svhUploadNotAllowed'),
        kind: AppFeedbackKind.warning,
      );
      return;
    }
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

  Future<void> _attachSvhCarGallery(CarListItem item) async {
    if (item.isArchivedOffline) return;
    if (_anyUploadBusy) return;
    if (!isSvhManagerSession(sl<AuthSessionController>())) return;

    final existing = item.files
        .map((f) => f.docType)
        .where(isSvhCarGalleryDocType)
        .length;
    final remaining = kSvhCarGalleryMaxPhotos - existing;
    if (remaining <= 0) {
      sl<AppFeedbackService>().show(
        sl<JsonStringsService>().text('requestFilesSectionSvhCarGalleryFull'),
        kind: AppFeedbackKind.warning,
      );
      return;
    }

    AppLog.trace(
      'svh photo pick start requestId=${item.id} remaining=$remaining',
      tag: 'SvhUpload',
    );
    final paths = await pickMultipleImagePaths(
      context: context,
      maxCount: remaining,
      allowFile: false,
    );
    if (!mounted || paths.isEmpty) {
      AppLog.trace('svh photo pick cancelled/empty', tag: 'SvhUpload');
      return;
    }
    AppLog.trace('svh photo picked count=${paths.length}', tag: 'SvhUpload');

    final s = sl<JsonStringsService>();
    final indices = nextSvhCarGalleryIndices(
      existingDocTypes: item.files.map((f) => f.docType),
      count: paths.length,
    );
    if (indices.isEmpty) {
      sl<AppFeedbackService>().show(
        s.text('requestFilesSectionSvhCarGalleryFull'),
        kind: AppFeedbackKind.warning,
      );
      return;
    }

    final entries = <({String docType, String localPath})>[];
    for (var i = 0; i < indices.length && i < paths.length; i++) {
      final docType = svhCarGalleryDocType(indices[i]);
      final compressed =
          await RequestDraftAttachmentsSpace.prepareImageForUpload(paths[i]);
      if (!mounted) return;
      final sizeKey =
          requestFileSizeLimitMessageKey(compressed, docType: docType);
      if (sizeKey != null) {
        sl<AppFeedbackService>().show(
          s.text(sizeKey),
          kind: AppFeedbackKind.warning,
        );
        return;
      }
      entries.add((docType: docType, localPath: compressed));
    }
    if (entries.isEmpty) return;

    setState(() => _uploadingSvhCarGallery = true);
    AppLog.trace(
      'svh photo upload start count=${entries.length} '
      'docTypes=${entries.map((e) => e.docType).join(",")}',
      tag: 'SvhUpload',
    );
    final result = await sl<CarsRepository>().attachRequestFiles(
      requestId: item.id,
      items: entries,
    );
    if (!mounted) return;
    setState(() => _uploadingSvhCarGallery = false);

    final feedback = sl<AppFeedbackService>();
    await result.fold(
      (failure) async {
        AppLog.trace(
          'svh photo upload Left: ${failure.message}',
          tag: 'SvhUpload',
        );
        await sl<CarsRepository>().getVehicle(item.id);
        if (!mounted) return;
        setState(() {});
        final updated = _itemFromInventory(item.id);
        final anyUploaded = updated != null &&
            entries.any(
              (e) => updated.files.any(
                (f) => normalizeDocType(f.docType) == normalizeDocType(e.docType),
              ),
            );
        if (anyUploaded) {
          AppLog.trace(
            'svh photo: server has files despite client error → success',
            tag: 'SvhUpload',
          );
          await _onAttachSucceeded(
            docType: entries.first.docType,
            itemId: item.id,
          );
          return;
        }
        final sizeMsg = resolveRequestFileSizeLimitMessage(failure.message, s);
        feedback.show(
          sizeMsg ?? requestAttachFailureMessage(failure.message, s),
          kind: sizeMsg != null ? AppFeedbackKind.warning : AppFeedbackKind.error,
        );
      },
      (_) async {
        AppLog.trace('svh photo upload Right ok', tag: 'SvhUpload');
        await _onAttachSucceeded(
          docType: entries.first.docType,
          itemId: item.id,
        );
      },
    );
  }

  Future<void> _attachSvhCarVideos(CarListItem item) async {
    if (item.isArchivedOffline) return;
    if (_anyUploadBusy) return;
    if (!isSvhManagerSession(sl<AuthSessionController>())) return;

    final existing = item.files
        .map((f) => f.docType)
        .where(isSvhCarVideoDocType)
        .length;
    final remaining = kSvhCarGalleryMaxVideos - existing;
    if (remaining <= 0) {
      sl<AppFeedbackService>().show(
        sl<JsonStringsService>().text('requestFilesSectionSvhCarVideoFull'),
        kind: AppFeedbackKind.warning,
      );
      return;
    }

    AppLog.trace(
      'svh video pick start requestId=${item.id} remaining=$remaining',
      tag: 'SvhUpload',
    );
    final paths = await pickMultipleVideoPaths(maxCount: remaining);
    if (!mounted || paths.isEmpty) {
      AppLog.trace('svh video pick cancelled/empty', tag: 'SvhUpload');
      return;
    }
    AppLog.trace(
      'svh video picked count=${paths.length}',
      tag: 'SvhUpload',
    );

    final s = sl<JsonStringsService>();
    final videoPaths = paths.where(looksLikeLocalVideoFile).toList();
    if (videoPaths.isEmpty) {
      sl<AppFeedbackService>().show(
        s.text('requestFilesSectionSvhCarVideoNotVideo'),
        kind: AppFeedbackKind.warning,
      );
      return;
    }
    if (videoPaths.length < paths.length) {
      sl<AppFeedbackService>().show(
        s.text('requestFilesSectionSvhCarVideoNotVideo'),
        kind: AppFeedbackKind.warning,
      );
    }

    final indices = nextSvhCarVideoIndices(
      existingDocTypes: item.files.map((f) => f.docType),
      count: videoPaths.length,
    );
    if (indices.isEmpty) {
      sl<AppFeedbackService>().show(
        s.text('requestFilesSectionSvhCarVideoFull'),
        kind: AppFeedbackKind.warning,
      );
      return;
    }

    final entries = <({String docType, String localPath})>[];
    for (var i = 0; i < indices.length && i < videoPaths.length; i++) {
      final docType = svhCarVideoDocType(indices[i]);
      final path = videoPaths[i];
      final sizeKey = requestFileSizeLimitMessageKey(path, docType: docType);
      if (sizeKey != null) {
        AppLog.trace(
          'svh video rejected by size docType=$docType path=$path',
          tag: 'SvhUpload',
        );
        sl<AppFeedbackService>().show(
          s.text(sizeKey),
          kind: AppFeedbackKind.warning,
        );
        return;
      }
      entries.add((docType: docType, localPath: path));
    }
    if (entries.isEmpty) return;

    setState(() => _uploadingSvhCarVideos = true);
    AppLog.trace(
      'svh video upload start count=${entries.length} '
      'docTypes=${entries.map((e) => e.docType).join(",")}',
      tag: 'SvhUpload',
    );
    final result = await sl<CarsRepository>().attachRequestFiles(
      requestId: item.id,
      items: entries,
    );
    if (!mounted) return;
    setState(() => _uploadingSvhCarVideos = false);

    final feedback = sl<AppFeedbackService>();
    await result.fold(
      (failure) async {
        AppLog.trace(
          'svh video upload Left: ${failure.message}',
          tag: 'SvhUpload',
        );
        await sl<CarsRepository>().getVehicle(item.id);
        if (!mounted) return;
        setState(() {});
        final updated = _itemFromInventory(item.id);
        final anyUploaded = updated != null &&
            entries.any(
              (e) => updated.files.any(
                (f) => normalizeDocType(f.docType) == normalizeDocType(e.docType),
              ),
            );
        if (anyUploaded) {
          AppLog.trace(
            'svh video: server has files despite client error → success',
            tag: 'SvhUpload',
          );
          await _onAttachSucceeded(
            docType: entries.first.docType,
            itemId: item.id,
          );
          return;
        }
        final sizeMsg = resolveRequestFileSizeLimitMessage(failure.message, s);
        feedback.show(
          sizeMsg ?? requestAttachFailureMessage(failure.message, s),
          kind: sizeMsg != null ? AppFeedbackKind.warning : AppFeedbackKind.error,
        );
      },
      (_) async {
        AppLog.trace('svh video upload Right ok', tag: 'SvhUpload');
        await _onAttachSucceeded(
          docType: entries.first.docType,
          itemId: item.id,
        );
      },
    );
  }

  Future<void> _attachTransitArchiveGallery(CarListItem item) async {
    if (item.isArchivedOffline) return;
    if (_anyUploadBusy) return;

    final remaining = kTransitArchiveMaxPhotos -
        occupiedUploadSlotCount(
          slots: kSvhTransitUploadDocTypes,
          existingDocTypes: item.files.map((f) => f.docType),
        );
    if (remaining <= 0) {
      sl<AppFeedbackService>().show(
        sl<JsonStringsService>().text('requestFilesSectionTransitGalleryFull'),
        kind: AppFeedbackKind.warning,
      );
      return;
    }

    final paths = await pickMultipleImagePaths(
      context: context,
      maxCount: remaining,
    );
    if (!mounted || paths.isEmpty) return;

    final s = sl<JsonStringsService>();
    final slots = nextFreeUploadDocTypes(
      slots: kSvhTransitUploadDocTypes,
      existingDocTypes: item.files.map((f) => f.docType),
      count: paths.length,
    );
    if (slots.isEmpty) {
      sl<AppFeedbackService>().show(
        s.text('requestFilesSectionTransitGalleryFull'),
        kind: AppFeedbackKind.warning,
      );
      return;
    }

    final entries = <({String docType, String localPath})>[];
    for (var i = 0; i < slots.length && i < paths.length; i++) {
      final docType = slots[i];
      final path = paths[i];
      final sizeKey = requestFileSizeLimitMessageKey(path, docType: docType);
      if (sizeKey != null) {
        sl<AppFeedbackService>().show(
          s.text(sizeKey),
          kind: AppFeedbackKind.warning,
        );
        return;
      }
      entries.add((docType: docType, localPath: path));
    }
    if (entries.isEmpty) return;

    setState(() => _uploadingTransitArchiveGallery = true);
    final result = await sl<CarsRepository>().attachRequestFiles(
      requestId: item.id,
      items: entries,
    );
    if (!mounted) return;
    setState(() => _uploadingTransitArchiveGallery = false);

    final feedback = sl<AppFeedbackService>();
    await result.fold(
      (failure) async {
        await sl<CarsRepository>().getVehicle(item.id);
        if (!mounted) return;
        setState(() {});
        final sizeMsg = resolveRequestFileSizeLimitMessage(failure.message, s);
        feedback.show(
          sizeMsg ?? requestAttachFailureMessage(failure.message, s),
          kind: sizeMsg != null ? AppFeedbackKind.warning : AppFeedbackKind.error,
        );
      },
      (_) async {
        await _onAttachSucceeded(
          docType: entries.first.docType,
          itemId: item.id,
        );
      },
    );
  }

  Future<void> _deleteSvhMediaFile(CarListItem item, CustomsRequestFile file) async {
    if (!isSvhManagerSession(sl<AuthSessionController>())) return;
    if (!isSvhCarMediaDocType(file.docType)) return;
    final fileId = file.id?.trim() ?? '';
    if (fileId.isEmpty) {
      _onDocumentOpenFailed();
      return;
    }
    final s = sl<JsonStringsService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.text('requestFileDeleteTitle')),
        content: Text(s.text('requestFileDeleteConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.text('actionCancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.text('requestFileDeleteAction')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await sl<CarsRepository>().deleteRequestFile(
      requestId: item.id,
      fileId: fileId,
    );
    if (!mounted) return;
    await result.fold(
      (failure) async {
        sl<AppFeedbackService>().show(
          s.text('requestFileDeleteFailed'),
          kind: AppFeedbackKind.error,
        );
      },
      (_) async {
        await sl<CarsRepository>().getVehicle(item.id);
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _attachOtherDocsGallery(CarListItem item) async {
    if (item.isArchivedOffline) return;
    if (_anyUploadBusy) return;

    final free = nextFreeUploadDocTypes(
      slots: kSvhOtherUploadDocTypes,
      existingDocTypes: item.files.map((f) => f.docType),
      count: 1,
    );
    if (free.isEmpty) {
      sl<AppFeedbackService>().show(
        sl<JsonStringsService>().text('requestFilesSectionOtherGalleryFull'),
        kind: AppFeedbackKind.warning,
      );
      return;
    }

    final docType = free.first;
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

    setState(() => _uploadingOtherDocsGallery = true);
    final result = await sl<CarsRepository>().attachRequestFile(
      requestId: item.id,
      docType: docType,
      localFilePath: path,
    );
    if (!mounted) return;
    setState(() => _uploadingOtherDocsGallery = false);

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

    // СВХ / архив / доп. доки: менеджер добавляет несколько файлов подряд —
    // не выходим в список заявок.
    if (_stayOnDetailAfterAttach(docType)) {
      AppLog.trace(
        'attach ok stayOnDetail docType=$docType requestId=$itemId',
        tag: 'SvhUpload',
      );
      return;
    }

    final updated = _itemFromInventory(itemId);
    if (updated != null && !hasPendingClientUploadActions(updated)) {
      AppLog.trace(
        'attach ok pop detail (no pending client actions) docType=$docType',
        tag: 'SvhUpload',
      );
      context.pop();
    }
  }

  /// Галерея авто / видео / транзит / add_doc — остаёмся на карточке.
  bool _stayOnDetailAfterAttach(String docType) {
    final code = normalizeDocType(docType);
    if (code.isEmpty) return false;
    if (isSvhCarGalleryDocType(code) || isSvhCarVideoDocType(code)) {
      return true;
    }
    if (code.startsWith('transit_archive')) return true;
    if (code == 'add_doc1' || code == 'add_doc2') return true;
    return false;
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
    VoidCallback? onDelete,
    bool highlight = false,
    String? badge,
    bool embedded = false,
  }) {
    final title = docTypeLabel(f, sl<JsonStringsService>());
    final showUploadedCheck = shouldShowUploadedCheck(f);
    final isVideo = isRequestFileVideo(f);
    final showPdfIcon = isRequestFilePdf(f);
    final rawPath = requestFileFullUrl(f);
    final localFile = !isVideo &&
            rawPath != null &&
            rawPath.isNotEmpty &&
            !rawPath.startsWith('http') &&
            File(rawPath).existsSync()
        ? File(rawPath)
        : null;
    final thumbUrl = localFile == null
        ? _resolveFileUrl(requestFileThumbnailUrl(f))
        : null;
    final hasOpenTarget = (rawPath != null && rawPath.isNotEmpty) ||
        (isVideo &&
            ((_resolveFileUrl(requestFileFullUrl(f)) ?? '').isNotEmpty));
    final showThumbImage =
        localFile != null || (thumbUrl != null && thumbUrl.isNotEmpty);
    final tappable = onTap != null && hasOpenTarget;
    final token = sl<AuthSessionController>().accessToken?.trim();
    final headers = (token != null && token.isNotEmpty)
        ? <String, String>{'Authorization': 'Bearer $token'}
        : null;

    final borderColor = highlight
        ? AppTheme.accentRed.withValues(alpha: 0.55)
        : AppTheme.requestCardBorder;
    final bg = highlight ? AppTheme.accentRed.withValues(alpha: 0.06) : AppTheme.cardBackground;

    const outerRadius = 12.0;
    const thumbRadius = 8.0;

    final Widget thumbChild;
    if (isVideo) {
      thumbChild = RequestFileVideoThumb(
        file: f,
        resolvedFullUrl: _resolveFileUrl(requestFileFullUrl(f)),
        resolvedPreviewUrl: thumbUrl,
        authHeaders: headers,
        size: 64,
      );
    } else if (showThumbImage) {
      thumbChild = localFile != null
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
                Icons.insert_drive_file_outlined,
                size: 24,
                color: AppTheme.textSecondary.withValues(alpha: 0.85),
              ),
            );
    } else {
      thumbChild = Icon(
        showPdfIcon
            ? Icons.picture_as_pdf_outlined
            : Icons.insert_drive_file_outlined,
        size: 24,
        color: AppTheme.textSecondary.withValues(alpha: 0.85),
      );
    }

    final thumb = Container(
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
      child: thumbChild,
    );

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        thumb,
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
          const Gap(4),
          const Icon(
            Icons.check_circle_rounded,
            size: 24,
            color: Color(0xFF2E7D32),
          ),
        ],
        if (onDelete != null) ...[
          const Gap(2),
          IconButton(
            onPressed: onDelete,
            tooltip: sl<JsonStringsService>().text('requestFileDeleteAction'),
            icon: const Icon(Icons.close, size: 22),
            color: AppTheme.accentRed,
            style: IconButton.styleFrom(
              foregroundColor: AppTheme.accentRed,
              minimumSize: const Size(48, 48),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
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

    if (item.isArchivedOffline) {
      out.add(
        RequestDetailActionHintBanner(
          message: s.requestArchivedOffline(item.archivedByName),
          urgent: true,
        ),
      );
      out.add(const Gap(20));
    }

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

    final svh = isSvhManagerSession(sl<AuthSessionController>());

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
            onUploadReceipt: svh
                ? null
                : (docType) => _attachDocType(docType, item),
          ),
        )
        ..add(const Gap(16));
    }

    if (svh || requestDetailShouldShowDocumentsBlock(item, s)) {
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
            uploadingSvhCarGallery: _uploadingSvhCarGallery,
            uploadingSvhCarVideos: _uploadingSvhCarVideos,
            uploadingTransitArchiveGallery: _uploadingTransitArchiveGallery,
            uploadingOtherDocsGallery: _uploadingOtherDocsGallery,
            svhUploadMode: svh,
            onUploadDocType: (docType) => _attachDocType(docType, item),
            onUploadSvhCarGallery:
                svh ? () => _attachSvhCarGallery(item) : null,
            onUploadSvhCarVideos:
                svh ? () => _attachSvhCarVideos(item) : null,
            onUploadTransitArchiveGallery: item.isArchivedOffline
                ? null
                : () => _attachTransitArchiveGallery(item),
            onUploadOtherDocsGallery: item.isArchivedOffline
                ? null
                : () => _attachOtherDocsGallery(item),
            onDeleteSvhMediaFile:
                svh ? (f) => _deleteSvhMediaFile(item, f) : null,
            onTransitPhotoTap: (url) => _openExternalUrl(url),
            buildDeliverableRow: (d) => RequestDetailDeliverableDocRow(
              title: d.title,
              downloadUrl: d.downloadUrl,
              onOpenFailed: () async {
                if (sl<AuthSessionController>().isDemo ||
                    isDemoRequestFileUrl(d.downloadUrl)) {
                  await _openDemoGeneratedPdf(
                    CustomsRequestFile(
                      docType: 'epts',
                      fileName: '${d.title}.pdf',
                      mimeType: 'application/pdf',
                      fileUrl: d.downloadUrl,
                    ),
                  );
                  return;
                }
                _onDocumentOpenFailed();
              },
            ),
            buildFileRow: (f, {required highlight, badge, embedded = false, onDelete}) {
              return _buildServerFileRow(
                theme: theme,
                f: f,
                highlight: highlight,
                badge: badge,
                embedded: embedded,
                onDelete: onDelete,
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
    final demoMode = sl<AuthSessionController>().isDemo ||
        isDemoRequestFileUrl(file.fileUrl);
    if (demoMode) {
      await _openDemoGeneratedPdf(file);
      return;
    }

    final resolved = _resolveFileUrl(requestFileFullUrl(file));
    if (resolved == null || resolved.isEmpty) {
      _onDocumentOpenFailed();
      return;
    }
    if (isRequestFileVideo(file)) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      final localPath = await downloadAuthenticatedRequestFile(resolved, file);
      if (localPath != null) {
        await ensureRequestVideoThumbnail(
          file: file,
          resolvedUrl: resolved,
          localVideoPath: localPath,
        );
      }
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;
      if (localPath == null) {
        _onDocumentOpenFailed();
        return;
      }
      final title = docTypeLabel(file, sl<JsonStringsService>());
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => RequestVideoPlayerPage(
            filePath: localPath,
            title: title,
          ),
        ),
      );
      return;
    }
    if (isRequestFileImage(file)) {
      final item = _itemFromInventory(widget.requestId);
      if (item == null) {
        _onDocumentOpenFailed();
        return;
      }
      final images = imageCarouselPeers(file, item.files);
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

  Future<void> _openDemoGeneratedPdf(CustomsRequestFile file) async {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final title = docTypeLabel(file, sl<JsonStringsService>());
      final path = await buildDemoPlaceholderPdf(
        docType: file.docType ?? 'document',
        title: title,
      );
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => RequestPdfViewerPage(
            filePath: path,
            title: title,
          ),
        ),
      );
    } catch (_) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) _onDocumentOpenFailed();
    }
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
    if (prepared.isEmpty) {
      _onDocumentOpenFailed();
      return;
    }
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
      isArchivedOffline: item.isArchivedOffline,
      forSvhManager: isSvhManagerSession(sl<AuthSessionController>()),
    );
    final isSvhViewer = isSvhManagerSession(sl<AuthSessionController>());
    final chatUnreadKey = isSvhViewer
        ? 'svh:${item.id}:${sl<AuthSessionController>().userId ?? ''}'
        : item.id;
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
          final hasUnreadChat = unreadState.has(chatUnreadKey);
          return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: BrandPrimaryAppBar(title: title),
      floatingActionButton: showChatFab
          ? FloatingActionButton(
              onPressed: () {
                sl<RequestChatUnreadCubit>().clearUnread(chatUnreadKey);
                if (isSvhViewer) {
                  context.pushSvhRequestChat(item.id);
                } else {
                  context.pushRequestChat(item.id);
                }
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
  bool _busy = false;
  final Map<int, String> _localPathByIndex = {};

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

  String _saveFileName(_CarouselPhotoItem item) {
    final urlPath = Uri.tryParse(item.fullUrl)?.path ?? '';
    final segments = urlPath.split('/').where((e) => e.isNotEmpty).toList();
    final last = segments.isEmpty ? '' : segments.last;
    final urlExt = last.contains('.') ? '.${last.split('.').last}' : '';
    final ext = RegExp(r'\.(jpe?g|png|webp|gif|heic|bmp)$', caseSensitive: false)
            .hasMatch(urlExt)
        ? urlExt.toLowerCase()
        : '.jpg';
    final base = item.title
        .trim()
        .replaceAll(RegExp(r'[^\w.\- ()\u0400-\u04FF]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final safe = base.isEmpty ? 'photo' : base;
    if (safe.toLowerCase().endsWith(ext.toLowerCase())) return safe;
    return '$safe$ext';
  }

  Future<String?> _ensureLocalFile() async {
    final cached = _localPathByIndex[_index];
    if (cached != null && await File(cached).exists()) return cached;
    final item = widget.items[_index];
    final path = await downloadAuthenticatedUrl(
      url: item.fullUrl,
      saveFileName: _saveFileName(item),
    );
    if (path != null) _localPathByIndex[_index] = path;
    return path;
  }

  Future<void> _shareOrSave({required bool asDownload}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final s = sl<JsonStringsService>();
    final path = await _ensureLocalFile();
    if (!mounted) return;
    if (path == null) {
      setState(() => _busy = false);
      sl<AppFeedbackService>().show(
        s.requestMediaActionFailed,
        kind: AppFeedbackKind.error,
      );
      return;
    }
    final ok = await shareLocalRequestFile(
      filePath: path,
      displayName: widget.items[_index].title,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      sl<AppFeedbackService>().show(
        s.requestMediaActionFailed,
        kind: AppFeedbackKind.error,
      );
      return;
    }
    if (asDownload) {
      sl<AppFeedbackService>().show(
        s.requestMediaSaveHint,
        kind: AppFeedbackKind.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = sl<JsonStringsService>();
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
        actions: [
          IconButton(
            onPressed: _busy ? null : () => _shareOrSave(asDownload: true),
            tooltip: s.requestMediaDownloadButton,
            icon: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download_rounded),
          ),
          IconButton(
            onPressed: _busy ? null : () => _shareOrSave(asDownload: false),
            tooltip: s.requestMediaShareButton,
            icon: const Icon(Icons.ios_share_rounded),
          ),
        ],
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
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white70),
                        );
                      },
                      errorBuilder: (_, _, _) => const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white70,
                            size: 56,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Не удалось загрузить изображение',
                            style: TextStyle(color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                        ],
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
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
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
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _busy ? null : () => _shareOrSave(asDownload: true),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: Text(s.requestMediaDownloadButton),
                    ),
                  ),
                  const Gap(10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed:
                          _busy ? null : () => _shareOrSave(asDownload: false),
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: Text(s.requestMediaShareButton),
                    ),
                  ),
                ],
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
      body: Center(
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

