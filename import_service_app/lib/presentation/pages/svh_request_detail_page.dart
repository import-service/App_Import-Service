import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_app/core/constants/customs_catalog.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/core/themes/request_status_list_style.dart';
import 'package:import_service_app/core/ui/app_feedback_kind.dart';
import 'package:import_service_app/core/ui/app_feedback_service.dart';
import 'package:import_service_app/core/util/vin_display.dart';
import 'package:import_service_app/core/utils/request_file_upload_validation.dart';
import 'package:import_service_app/domain/entities/car_list_item.dart';
import 'package:import_service_app/domain/repositories/cars_repository.dart';
import 'package:import_service_app/presentation/helpers/request_attach_failure_message.dart';
import 'package:import_service_app/presentation/helpers/request_file_picker.dart';
import 'package:import_service_app/presentation/helpers/request_status_labels.dart';
import 'package:import_service_app/presentation/widgets/app_bar/brand_primary_app_bar.dart';
import 'package:import_service_app/presentation/widgets/chips/request_status_pill.dart';

/// Устаревшая карточка СВХ (роутер ведёт на [CarRequestDetailPage]).
/// Оставлена для совместимости: галерея + архив, без слотов «спереди/сзади».
class SvhRequestDetailPage extends StatefulWidget {
  const SvhRequestDetailPage({super.key, required this.requestId});

  final String requestId;

  @override
  State<SvhRequestDetailPage> createState() => _SvhRequestDetailPageState();
}

class _SvhRequestDetailPageState extends State<SvhRequestDetailPage> {
  static const _archiveSlots = <({String docType, String labelRu})>[
    (docType: 'transit_archive_photo_1', labelRu: 'Архив фото 1'),
    (docType: 'transit_archive_photo_2', labelRu: 'Архив фото 2'),
    (docType: 'transit_archive_photo_3', labelRu: 'Архив фото 3'),
    (docType: 'add_doc1', labelRu: 'Доп. документ 1'),
    (docType: 'add_doc2', labelRu: 'Доп. документ 2'),
  ];

  CarListItem? _item;
  bool _loading = true;
  String? _error;
  String? _uploadingDocType;
  bool _uploadingGallery = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await sl<CarsRepository>().getVehicle(widget.requestId);
    if (!mounted) return;
    result.fold(
      (f) => setState(() {
        _loading = false;
        _error = f.message;
        _item = null;
      }),
      (item) => setState(() {
        _loading = false;
        _item = item;
      }),
    );
  }

  int get _galleryCount =>
      _item?.files.where((f) => isSvhCarGalleryDocType(f.docType)).length ?? 0;

  Future<void> _attachGallery() async {
    final item = _item;
    if (item == null || _uploadingDocType != null || _uploadingGallery) return;
    final remaining = kSvhCarGalleryMaxPhotos - _galleryCount;
    if (remaining <= 0) {
      sl<AppFeedbackService>().show(
        sl<JsonStringsService>().text('requestFilesSectionSvhCarGalleryFull'),
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
      final path = paths[i];
      final sizeKey = requestFileSizeLimitMessageKey(path, docType: docType);
      if (sizeKey != null) {
        sl<AppFeedbackService>().show(s.text(sizeKey), kind: AppFeedbackKind.warning);
        return;
      }
      entries.add((docType: docType, localPath: path));
    }
    if (entries.isEmpty) return;
    setState(() => _uploadingGallery = true);
    final result = await sl<CarsRepository>().attachRequestFiles(
      requestId: item.id,
      items: entries,
    );
    if (!mounted) return;
    setState(() => _uploadingGallery = false);
    await result.fold(
      (failure) async {
        final sizeMsg = resolveRequestFileSizeLimitMessage(failure.message, s);
        sl<AppFeedbackService>().show(
          sizeMsg ?? requestAttachFailureMessage(failure.message, s),
          kind: sizeMsg != null ? AppFeedbackKind.warning : AppFeedbackKind.error,
        );
        await _load();
      },
      (_) async {
        sl<AppFeedbackService>().show(
          s.requestFileAttachSuccess,
          kind: AppFeedbackKind.success,
        );
        await _load();
      },
    );
  }

  Future<void> _attach(String docType) async {
    final item = _item;
    if (item == null || _uploadingDocType != null || _uploadingGallery) return;
    final path = await pickRequestDocumentPath(context);
    if (!mounted || path == null || path.isEmpty) return;
    final s = sl<JsonStringsService>();
    final sizeKey = requestFileSizeLimitMessageKey(path, docType: docType);
    if (sizeKey != null) {
      sl<AppFeedbackService>().show(s.text(sizeKey), kind: AppFeedbackKind.warning);
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
    await result.fold(
      (failure) async {
        final sizeMsg = resolveRequestFileSizeLimitMessage(failure.message, s);
        sl<AppFeedbackService>().show(
          sizeMsg ?? requestAttachFailureMessage(failure.message, s),
          kind: sizeMsg != null ? AppFeedbackKind.warning : AppFeedbackKind.error,
        );
        await _load();
      },
      (_) async {
        sl<AppFeedbackService>().show(
          s.requestFileAttachSuccess,
          kind: AppFeedbackKind.success,
        );
        await _load();
      },
    );
  }

  bool _hasFile(String docType) {
    final code = normalizeDocType(docType);
    return _item?.files.any((f) => normalizeDocType(f.docType) == code) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final s = sl<JsonStringsService>();
    return Scaffold(
      appBar: BrandPrimaryAppBar(title: s.text('svhRequestDetailTitle')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const Gap(12),
                        FilledButton(onPressed: _load, child: Text(s.text('svhCarsRetry'))),
                      ],
                    ),
                  ),
                )
              : _buildContent(s),
    );
  }

  Widget _buildContent(JsonStringsService s) {
    final item = _item!;
    final theme = Theme.of(context);
    final galleryCount = _galleryCount;
    final galleryFull = galleryCount >= kSvhCarGalleryMaxPhotos;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            item.ownerFullName,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Gap(8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${item.carMake} ${item.carModel}'.trim(),
                  style: theme.textTheme.titleMedium,
                ),
              ),
              RequestStatusPill(
                label: requestStatusLabel(item.status, s),
                backgroundColor: item.status.listChipBackground,
                foregroundColor: item.status.listChipForeground,
              ),
            ],
          ),
          const Gap(6),
          Text(
            'VIN: ${formatVinForDetail(item.vin)}',
            style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
          if ((item.commentText ?? '').trim().isNotEmpty) ...[
            const Gap(12),
            Text(s.text('svhRequestCommentLabel'), style: theme.textTheme.labelLarge),
            Text(item.commentText!.trim()),
          ],
          const Gap(24),
          Text(
            s.requestFilesSectionSvhCarGallery,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Gap(4),
          Text(
            s
                .text('requestFilesSectionSvhCarGalleryCount')
                .replaceAll('{count}', '$galleryCount')
                .replaceAll('{max}', '$kSvhCarGalleryMaxPhotos'),
            style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
          const Gap(8),
          OutlinedButton.icon(
            onPressed: galleryFull || _uploadingGallery || _uploadingDocType != null
                ? null
                : _attachGallery,
            icon: _uploadingGallery
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_a_photo_outlined),
            label: Text(s.text('requestFilesSectionSvhCarGalleryAdd')),
          ),
          const Gap(24),
          Text(
            s.text('svhRequestUploadSection'),
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Gap(4),
          Text(
            s.text('svhRequestUploadHint'),
            style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
          const Gap(12),
          for (final slot in _archiveSlots) ...[
            _UploadSlotTile(
              label: slot.labelRu,
              hasFile: _hasFile(slot.docType),
              uploading: _uploadingDocType == slot.docType,
              enabled: _uploadingDocType == null && !_uploadingGallery,
              onAdd: () => _attach(slot.docType),
            ),
            const Gap(8),
          ],
          if (item.files.isNotEmpty) ...[
            const Gap(16),
            Text(
              s.text('svhRequestFilesSection'),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Gap(8),
            for (final f in item.files)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.attach_file),
                title: Text(f.docType ?? '—'),
                subtitle: Text(f.fileName ?? ''),
              ),
          ],
        ],
      ),
    );
  }
}

class _UploadSlotTile extends StatelessWidget {
  const _UploadSlotTile({
    required this.label,
    required this.hasFile,
    required this.uploading,
    required this.enabled,
    required this.onAdd,
  });

  final String label;
  final bool hasFile;
  final bool uploading;
  final bool enabled;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.cardBackground,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled && !uploading ? onAdd : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.requestCardBorder),
          ),
          child: Row(
            children: [
              Icon(
                hasFile ? Icons.check_circle : Icons.add_a_photo_outlined,
                color: hasFile ? const Color(0xFF2E7D32) : AppTheme.primaryBlue,
              ),
              const Gap(12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              if (uploading)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  hasFile ? 'Заменить' : 'Добавить',
                  style: TextStyle(
                    color: enabled ? AppTheme.primaryBlue : Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
