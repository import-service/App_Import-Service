import 'dart:io';

import 'package:flutter/material.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/core/ui/app_feedback_kind.dart';
import 'package:import_service_app/core/ui/app_feedback_service.dart';
import 'package:import_service_app/domain/entities/chat_message.dart';
import 'package:import_service_app/presentation/helpers/request_file_preview_helper.dart';
import 'package:import_service_app/presentation/pages/request_pdf_viewer_page.dart';

/// Открыть вложение чата: скачать с Bearer, затем PDF / фото / share.
Future<void> openChatAttachment(
  BuildContext context,
  ChatAttachment attachment,
) async {
  final resolved = resolveApiAbsoluteUrl(attachment.fileUrl);
  if (resolved == null || resolved.isEmpty) {
    sl<AppFeedbackService>().show(
      sl<JsonStringsService>().requestDocumentOpenFailed,
      kind: AppFeedbackKind.error,
    );
    return;
  }

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  final saveName = chatAttachmentSaveName(
    fileUrl: attachment.fileUrl,
    fileName: attachment.fileName,
    mimeType: attachment.mimeType,
  );
  final localPath = await downloadAuthenticatedUrl(
    url: resolved,
    saveFileName: saveName,
  );

  if (context.mounted) {
    Navigator.of(context, rootNavigator: true).pop();
  }
  if (!context.mounted) return;

  if (localPath == null) {
    sl<AppFeedbackService>().show(
      sl<JsonStringsService>().requestDocumentOpenFailed,
      kind: AppFeedbackKind.error,
    );
    return;
  }

  final title = (attachment.fileName?.trim().isNotEmpty ?? false)
      ? attachment.fileName!.trim()
      : 'Файл';

  final isPdf = await fileHasPdfMagic(localPath) ||
      looksLikeChatPdf(
        localPath: localPath,
        fileName: attachment.fileName,
        mimeType: attachment.mimeType,
        fileUrl: attachment.fileUrl,
      );
  if (isPdf &&
      !(await fileHasJpegMagic(localPath)) &&
      !(await fileHasPngMagic(localPath))) {
    if (!context.mounted) return;
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

  final isImage = await fileHasJpegMagic(localPath) ||
      await fileHasPngMagic(localPath) ||
      looksLikeChatImage(
        localPath: localPath,
        fileName: attachment.fileName,
        mimeType: attachment.mimeType,
        fileUrl: attachment.fileUrl,
      );
  if (isImage) {
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _ChatAttachmentImagePage(
          filePath: localPath,
          title: title,
        ),
      ),
    );
    return;
  }

  final shared = await shareLocalRequestFile(
    filePath: localPath,
    displayName: title,
  );
  if (!shared && context.mounted) {
    sl<AppFeedbackService>().show(
      sl<JsonStringsService>().requestDocumentOpenFailed,
      kind: AppFeedbackKind.error,
    );
  }
}

class _ChatAttachmentImagePage extends StatelessWidget {
  const _ChatAttachmentImagePage({
    required this.filePath,
    required this.title,
  });

  final String filePath;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            onPressed: () {
              shareLocalRequestFile(filePath: filePath, displayName: title);
            },
            icon: const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(
            File(filePath),
            fit: BoxFit.contain,
            errorBuilder: (_, error, stackTrace) => Icon(
              Icons.broken_image_outlined,
              size: 48,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
