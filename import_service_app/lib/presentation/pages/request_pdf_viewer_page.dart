import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/core/ui/app_feedback_kind.dart';
import 'package:import_service_app/core/ui/app_feedback_service.dart';
import 'package:import_service_app/presentation/helpers/request_file_preview_helper.dart';
import 'package:pdfx/pdfx.dart';

/// Просмотр PDF из локального файла (после скачивания с Bearer).
class RequestPdfViewerPage extends StatefulWidget {
  const RequestPdfViewerPage({
    super.key,
    required this.filePath,
    required this.title,
  });

  final String filePath;
  final String title;

  @override
  State<RequestPdfViewerPage> createState() => _RequestPdfViewerPageState();
}

class _RequestPdfViewerPageState extends State<RequestPdfViewerPage> {
  PdfControllerPinch? _controller;
  Object? _error;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final controller = PdfControllerPinch(
        document: PdfDocument.openFile(widget.filePath),
      );
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final s = sl<JsonStringsService>();
    final ok = await shareLocalRequestFile(
      filePath: widget.filePath,
      displayName: widget.title,
    );
    if (!mounted) return;
    setState(() => _sharing = false);
    if (!ok) {
      sl<AppFeedbackService>().show(
        s.requestPdfShareFailed,
        kind: AppFeedbackKind.error,
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = sl<JsonStringsService>();
    final controller = _controller;
    final pdfReady = _error == null && controller != null;

    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: AppBar(
        title: Text(
          widget.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (pdfReady)
            IconButton(
              onPressed: _sharing ? null : _share,
              tooltip: s.requestPdfShareButton,
              icon: _sharing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share_rounded),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: switch ((_error, controller)) {
              (final Object err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      err.toString(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              (_, null) => const Center(child: CircularProgressIndicator()),
              (_, final PdfControllerPinch c) => PdfViewPinch(
                  controller: c,
                  padding: 10,
                  builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
                    options: const DefaultBuilderOptions(),
                    documentLoaderBuilder: (_) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    pageLoaderBuilder: (_) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    errorBuilder: (_, error) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(error.toString(), textAlign: TextAlign.center),
                      ),
                    ),
                  ),
                ),
            },
          ),
          if (pdfReady)
            Material(
              color: AppTheme.white,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: AppTheme.textSecondary.withValues(alpha: 0.9),
                      ),
                      const Gap(10),
                      Expanded(
                        child: Text(
                          s.requestPdfShareHint,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
                                height: 1.35,
                              ),
                        ),
                      ),
                      const Gap(8),
                      FilledButton.icon(
                        onPressed: _sharing ? null : _share,
                        icon: const Icon(Icons.ios_share_rounded, size: 18),
                        label: Text(s.requestPdfShareButton),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
