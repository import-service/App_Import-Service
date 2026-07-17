import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_admin/core/catalog/customs_request_labels.dart';
import 'package:import_service_admin/core/theme/app_theme.dart';
import 'package:import_service_admin/core/util/file_url_resolver.dart';
import 'package:import_service_admin/domain/entities/customs_request_file.dart';
import 'package:import_service_admin/presentation/widgets/auth_network_image.dart';

class RequestDetailFileRow extends StatelessWidget {
  const RequestDetailFileRow({
    super.key,
    required this.file,
    this.authToken,
    this.onOpen,
    this.groupCount,
  });

  final CustomsRequestFile file;
  final String? authToken;
  final VoidCallback? onOpen;

  /// Если задано (>1) — строка представляет архив из N файлов (карусель по тапу).
  final int? groupCount;

  bool get _isArchiveGroup => (groupCount ?? 0) > 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = resolveFileUrl(file.fileUrl);
    final title = _isArchiveGroup
        ? 'Архив: ${docTypeLabel(file.docType, fileName: file.fileName)}'
        : docTypeLabel(file.docType, fileName: file.fileName);
    final token = authToken?.trim();
    final previewUrl = resolveFileUrl(file.displayUrl) ?? url;
    final isImage = _looksLikeImage(file.mimeType, file.fileName, url);
    final tappable = onOpen != null || url != null;
    final metaLines = _metaLines(file);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: tappable ? onOpen : null,
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
                    child: previewUrl != null && isImage
                        ? AuthNetworkImage(
                            url: previewUrl,
                            fallbackUrls: [
                              if (url != null && url != previewUrl) url,
                            ],
                            authToken: token,
                            fit: BoxFit.cover,
                            errorWidget: _fileIcon(),
                          )
                        : _fileIcon(),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                height: 1.25,
                              ),
                            ),
                          ),
                          if (_isArchiveGroup) ...[
                            const Gap(6),
                            _SourceChip(label: '$groupCount фото'),
                          ],
                          if (file.fromOneC) ...[
                            const Gap(6),
                            _SourceChip(label: '1С'),
                          ] else if (file.uploadSource == 'user') ...[
                            const Gap(6),
                            _SourceChip(label: 'МП'),
                          ] else if (file.uploadSource == 'demo') ...[
                            const Gap(6),
                            _SourceChip(label: 'demo'),
                          ],
                        ],
                      ),
                      if (file.fileName.trim().isNotEmpty) ...[
                        const Gap(4),
                        Text(
                          file.fileName.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                      for (final line in metaLines) ...[
                        const Gap(2),
                        Text(
                          line,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.textSecondary,
                            fontFamily: 'monospace',
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (tappable)
                  Icon(
                    _isArchiveGroup
                        ? Icons.collections_outlined
                        : Icons.open_in_new_rounded,
                    size: 18,
                    color: AppTheme.textSecondary.withValues(alpha: 0.8),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<String> _metaLines(CustomsRequestFile file) {
    final lines = <String>[];
    lines.add('источник: ${_sourceLabel(file)}');
    final mime = (file.mimeType ?? '').trim();
    if (mime.isNotEmpty) {
      lines.add('mime: $mime');
    }
    final size = file.fileSizeBytes;
    if (size != null && size > 0) {
      lines.add('size: ${_formatBytes(size)}');
    }
    final srcName = (file.sourceFileName ?? '').trim();
    final srcMime = (file.sourceMimeType ?? '').trim();
    if (srcName.isNotEmpty || srcMime.isNotEmpty) {
      final parts = <String>[];
      if (srcName.isNotEmpty) parts.add(srcName);
      if (srcMime.isNotEmpty) parts.add(srcMime);
      lines.add('имя при upload: ${parts.join(' · ')}');
    }
    final stored = (file.storedName ?? '').trim();
    if (stored.isNotEmpty) {
      lines.add('disk: $stored');
    }
    return lines;
  }

  String _sourceLabel(CustomsRequestFile file) {
    switch (file.uploadSource) {
      case 'integration':
        return '1С';
      case 'user':
        return 'МП';
      case 'demo':
        return 'demo';
      default:
        return 'не указан';
    }
  }

  String _formatBytes(int n) {
    if (n < 1024) return '$n B';
    if (n < 1024 * 1024) return '${(n / 1024).toStringAsFixed(1)} KB';
    return '${(n / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _fileIcon() {
    return Icon(
      Icons.insert_drive_file_outlined,
      size: 24,
      color: AppTheme.textSecondary.withValues(alpha: 0.85),
    );
  }

  bool _looksLikeImage(String? mime, String name, String? url) {
    final m = (mime ?? '').toLowerCase();
    if (m.contains('octet-stream') ||
        m.contains('rar') ||
        m.contains('zip') ||
        m.contains('pdf')) {
      return false;
    }
    if (m.startsWith('image/')) return true;
    final stored = (file.storedName ?? '').toLowerCase();
    if (stored.endsWith('.bin') ||
        stored.endsWith('.rar') ||
        stored.endsWith('.zip') ||
        stored.endsWith('.pdf')) {
      return false;
    }
    final doc = file.docType.toLowerCase();
    if (doc.startsWith('transit_archive_photo') || doc.contains('_photo')) {
      return true;
    }
    if (doc.endsWith('_sign')) return true;
    final n = name.toLowerCase();
    if (n.endsWith('.jpg') ||
        n.endsWith('.jpeg') ||
        n.endsWith('.png') ||
        n.endsWith('.webp') ||
        n.endsWith('.gif')) {
      return true;
    }
    if (stored.endsWith('.jpg') ||
        stored.endsWith('.jpeg') ||
        stored.endsWith('.png') ||
        stored.endsWith('.webp')) {
      return true;
    }
    final u = (url ?? '').toLowerCase();
    return u.contains('.jpg') ||
        u.contains('.jpeg') ||
        u.contains('.png') ||
        u.contains('.webp');
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.pageBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.requestCardBorder),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
      ),
    );
  }
}
