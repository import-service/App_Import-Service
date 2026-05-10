import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// СБКТС, ЭПТС и т.д.: [title] и [downloadUrl] с бэка/1С.
class RequestDetailDeliverableDocRow extends StatelessWidget {
  const RequestDetailDeliverableDocRow({
    super.key,
    required this.title,
    required this.downloadUrl,
    this.onOpenFailed,
  });

  final String title;
  final String downloadUrl;
  final Future<void> Function()? onOpenFailed;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Material(
      color: AppTheme.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _open(),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.pageBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.requestCardBorder),
                ),
                child: Icon(
                  Icons.description_outlined,
                  size: 22,
                  color: AppTheme.textSecondary.withValues(alpha: 0.85),
                ),
              ),
              const Gap(12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.textTheme.bodyLarge?.copyWith(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ),
              const Gap(8),
              const Icon(
                Icons.download_for_offline_outlined,
                size: 26,
                color: AppTheme.accentRed,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open() async {
    final uri = Uri.tryParse(downloadUrl);
    if (uri == null) {
      if (onOpenFailed != null) {
        await onOpenFailed!();
      }
      return;
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (onOpenFailed != null) {
      await onOpenFailed!();
    }
  }
}
