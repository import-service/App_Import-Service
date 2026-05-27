import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_admin/core/catalog/customs_request_labels.dart';
import 'package:import_service_admin/core/theme/app_theme.dart';
import 'package:import_service_admin/core/util/file_url_resolver.dart';
import 'package:import_service_admin/domain/entities/customs_request_file.dart';

class RequestDetailFileRow extends StatelessWidget {
  const RequestDetailFileRow({
    super.key,
    required this.file,
    this.authToken,
    this.onOpen,
  });

  final CustomsRequestFile file;
  final String? authToken;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = resolveFileUrl(file.fileUrl);
    final title = docTypeLabel(file.docType, fileName: file.fileName);
    final token = authToken?.trim();
    final headers = (token != null && token.isNotEmpty)
        ? <String, String>{'Authorization': 'Bearer $token'}
        : null;
    final isImage = _looksLikeImage(file.mimeType, file.fileName, url);
    final tappable = onOpen != null || url != null;

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
                    child: url != null && isImage
                        ? Image.network(
                            url,
                            headers: headers,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _fileIcon(),
                          )
                        : _fileIcon(),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
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
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
    if (m.startsWith('image/')) return true;
    final n = name.toLowerCase();
    if (n.endsWith('.jpg') ||
        n.endsWith('.jpeg') ||
        n.endsWith('.png') ||
        n.endsWith('.webp') ||
        n.endsWith('.gif')) {
      return true;
    }
    final u = (url ?? '').toLowerCase();
    return u.contains('.jpg') ||
        u.contains('.jpeg') ||
        u.contains('.png') ||
        u.contains('.webp');
  }
}
