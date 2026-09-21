import 'dart:io';

import 'package:flutter/material.dart';
import 'package:import_service_app/presentation/helpers/request_file_preview_helper.dart';
import 'package:path/path.dart' as p;

/// Фото с Bearer в дисковом кэше. Повторный показ и «Поделиться» не качают файл заново.
class CachedAuthImage extends StatefulWidget {
  const CachedAuthImage({
    super.key,
    required this.url,
    required this.cacheStamp,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.error,
  });

  final String url;
  final String cacheStamp;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? error;

  @override
  State<CachedAuthImage> createState() => _CachedAuthImageState();
}

class _CachedAuthImageState extends State<CachedAuthImage> {
  String? _path;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CachedAuthImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.cacheStamp != widget.cacheStamp) {
      _path = null;
      _failed = false;
      _load();
    }
  }

  String _saveName() {
    final ext = p.extension(Uri.tryParse(widget.url)?.path ?? widget.url);
    final safe = RegExp(r'\.(jpe?g|png|webp|gif|heic|bmp)$', caseSensitive: false)
            .hasMatch(ext)
        ? ext
        : '.jpg';
    return 'media$safe';
  }

  Future<void> _load() async {
    final path = await downloadAuthenticatedUrl(
      url: widget.url,
      saveFileName: _saveName(),
      cacheStamp: widget.cacheStamp,
    );
    if (!mounted) return;
    setState(() {
      _path = path;
      _failed = path == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return widget.error ??
          const Icon(Icons.broken_image_outlined, color: Colors.white70);
    }
    final path = _path;
    if (path == null) {
      return widget.placeholder ??
          const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
    }
    return Image.file(
      File(path),
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
    );
  }
}
