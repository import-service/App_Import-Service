import 'dart:io';

import 'package:flutter/material.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/domain/entities/customs_request_file.dart';
import 'package:import_service_app/presentation/helpers/request_file_preview_helper.dart';

/// Миниатюра видео: server previewUrl или локальный кадр после download+auth.
class RequestFileVideoThumb extends StatefulWidget {
  const RequestFileVideoThumb({
    super.key,
    required this.file,
    this.resolvedFullUrl,
    this.resolvedPreviewUrl,
    this.authHeaders,
    this.size = 64,
  });

  final CustomsRequestFile file;
  final String? resolvedFullUrl;
  final String? resolvedPreviewUrl;
  final Map<String, String>? authHeaders;
  final double size;

  @override
  State<RequestFileVideoThumb> createState() => _RequestFileVideoThumbState();
}

class _RequestFileVideoThumbState extends State<RequestFileVideoThumb> {
  String? _localThumbPath;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant RequestFileVideoThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resolvedFullUrl != widget.resolvedFullUrl ||
        oldWidget.resolvedPreviewUrl != widget.resolvedPreviewUrl ||
        oldWidget.file.fileUrl != widget.file.fileUrl) {
      _localThumbPath = null;
      _bootstrap();
    }
  }

  Future<void> _bootstrap() async {
    final preview = widget.resolvedPreviewUrl?.trim();
    if (preview != null && preview.isNotEmpty) return;

    final full = widget.resolvedFullUrl?.trim() ?? '';
    final raw = requestFileFullUrl(widget.file) ?? '';
    String? localVideo;
    if (full.isNotEmpty && !full.startsWith('http') && File(full).existsSync()) {
      localVideo = full;
    } else if (raw.isNotEmpty &&
        !raw.startsWith('http') &&
        File(raw).existsSync()) {
      localVideo = raw;
    }

    final seed = full.isNotEmpty ? full : (localVideo ?? raw);
    if (seed.isEmpty) return;

    final cached = await cachedRequestVideoThumbnailPath(cacheSeed: seed);
    if (!mounted) return;
    if (cached != null) {
      setState(() => _localThumbPath = cached);
      return;
    }

    setState(() => _loading = true);
    final path = await ensureRequestVideoThumbnail(
      file: widget.file,
      resolvedUrl: full.startsWith('http') ? full : null,
      localVideoPath: localVideo,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _localThumbPath = path;
    });
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.resolvedPreviewUrl?.trim();
    final size = widget.size;

    Widget? image;
    if (preview != null && preview.isNotEmpty) {
      image = Image.network(
        preview,
        headers: widget.authHeaders,
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    } else if (_localThumbPath != null && File(_localThumbPath!).existsSync()) {
      image = Image.file(
        File(_localThumbPath!),
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: AppTheme.pageBackground),
          ?image,
          if (_loading && image == null)
            const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          Center(
            child: Icon(
              Icons.play_circle_fill,
              size: size * 0.45,
              color: Colors.white.withValues(alpha: image == null ? 0.55 : 0.92),
              shadows: const [
                Shadow(blurRadius: 6, color: Colors.black54),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
