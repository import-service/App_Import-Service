import 'package:flutter/material.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/presentation/widgets/requests/request_detail_file_upload_chip.dart';

/// Один визуальный блок: один или несколько документов и действие загрузки снизу.
class RequestDetailDocUploadGroup extends StatelessWidget {
  const RequestDetailDocUploadGroup({
    super.key,
    required this.children,
    required this.highlight,
    this.uploadLabel,
    this.onUpload,
    this.uploadBusy = false,
  });

  final List<Widget> children;
  final bool highlight;
  final String? uploadLabel;
  final VoidCallback? onUpload;
  final bool uploadBusy;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    final borderColor = highlight
        ? AppTheme.accentRed.withValues(alpha: 0.55)
        : AppTheme.requestCardBorder;
    final bg = highlight ? AppTheme.accentRed.withValues(alpha: 0.06) : AppTheme.white;
    final showUpload = onUpload != null && (uploadLabel?.isNotEmpty ?? false);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: borderColor.withValues(alpha: 0.65),
              ),
            children[i],
          ],
          if (showUpload) ...[
            Divider(
              height: 1,
              thickness: 1,
              color: borderColor.withValues(alpha: 0.65),
            ),
            RequestDetailFileUploadChip(
              label: uploadLabel!,
              busy: uploadBusy,
              embedded: true,
              onTap: onUpload,
            ),
          ],
        ],
      ),
    );
  }
}
