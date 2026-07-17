import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_admin/core/theme/app_theme.dart';
import 'package:import_service_admin/domain/entities/customs_request_delivered_document.dart';
import 'package:import_service_admin/domain/entities/customs_request_file.dart';
import 'package:import_service_admin/domain/services/request_files_grouper.dart';
import 'package:import_service_admin/presentation/widgets/auth_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

class RequestDetailFilesSections extends StatelessWidget {
  const RequestDetailFilesSections({
    super.key,
    required this.files,
    required this.deliveredDocuments,
    required this.vehiclePhotoUrls,
    required this.authToken,
    required this.buildFileRow,
  });

  final List<CustomsRequestFile> files;
  final List<CustomsRequestDeliveredDocument> deliveredDocuments;
  final List<String> vehiclePhotoUrls;
  final String? authToken;
  final Widget Function(CustomsRequestFile file) buildFileRow;

  @override
  Widget build(BuildContext context) {
    final grouped = groupRequestFiles(files);
    final theme = Theme.of(context);
    final children = <Widget>[];

    void addSection(String title, List<Widget> rows) {
      if (rows.isEmpty) return;
      if (children.isNotEmpty) children.add(const Gap(16));
      children.add(
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
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Gap(10),
              ...rows,
            ],
          ),
        ),
      );
    }

    addSection(
      'Документы при подаче',
      grouped.creation.map(buildFileRow).toList(),
    );

    final signingRows = <Widget>[];
    for (final pair in grouped.signingPairs) {
      if (pair.original != null) signingRows.add(buildFileRow(pair.original!));
      if (pair.signed != null) signingRows.add(buildFileRow(pair.signed!));
    }
    addSection('На подпись', signingRows);

    addSection(
      'Оплата',
      grouped.payment.map(buildFileRow).toList(),
    );

    addSection(
      'Архив перед транзитом',
      grouped.transitArchive.map(buildFileRow).toList(),
    );

    final finalRows = <Widget>[
      ...grouped.finalDocs.map(buildFileRow),
      ...deliveredDocuments.map(
        (d) => _DeliveredRow(
          title: d.title.trim().isNotEmpty ? d.title : 'Документ',
          url: d.downloadUrl,
        ),
      ),
    ];
    addSection('Итоговые документы', finalRows);

    if (vehiclePhotoUrls.isNotEmpty) {
      addSection(
        'Фото автомобиля',
        vehiclePhotoUrls
            .map(
              (url) => _PhotoUrlRow(
                url: url,
                authToken: authToken,
              ),
            )
            .toList(),
      );
    }

    addSection('Прочее', grouped.other.map(buildFileRow).toList());

    if (children.isEmpty) {
      return Text(
        'Нет прикреплённых файлов',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: AppTheme.textSecondary,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _DeliveredRow extends StatelessWidget {
  const _DeliveredRow({required this.title, required this.url});

  final String title;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _open(url),
        child: Row(
          children: [
            const Icon(Icons.description_outlined, color: AppTheme.primaryBlue),
            const Gap(8),
            Expanded(child: Text(title)),
          ],
        ),
      ),
    );
  }
}

class _PhotoUrlRow extends StatelessWidget {
  const _PhotoUrlRow({required this.url, this.authToken});

  final String url;
  final String? authToken;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _open(url),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 120,
            width: double.infinity,
            child: AuthNetworkImage(
              url: url,
              authToken: authToken,
              fit: BoxFit.cover,
              errorWidget: Container(
                height: 80,
                color: AppTheme.pageBackground,
                child: const Center(child: Icon(Icons.broken_image_outlined)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _open(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
