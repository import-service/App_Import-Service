import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:import_service_admin/core/di/injection_container.dart';

/// Загрузка картинки с Bearer через Dio (Image.network на web с auth часто даёт 401).
/// [fallbackUrls] — запасные URL (полный файл, если preview 404).
class AuthNetworkImage extends StatefulWidget {
  const AuthNetworkImage({
    super.key,
    required this.url,
    this.fallbackUrls = const [],
    this.authToken,
    this.fit = BoxFit.cover,
    this.errorWidget,
  });

  final String url;
  final List<String> fallbackUrls;
  final String? authToken;
  final BoxFit fit;
  final Widget? errorWidget;

  @override
  State<AuthNetworkImage> createState() => _AuthNetworkImageState();
}

class _AuthNetworkImageState extends State<AuthNetworkImage> {
  late Future<Uint8List?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant AuthNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.authToken != widget.authToken ||
        !_sameList(oldWidget.fallbackUrls, widget.fallbackUrls)) {
      setState(() => _future = _load());
    }
  }

  bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<Uint8List?> _load() async {
    final token = widget.authToken?.trim();
    final headers = <String, String>{
      'Accept': '*/*',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
    final urls = <String>{
      widget.url,
      ...widget.fallbackUrls.where((e) => e.trim().isNotEmpty),
    };
    for (final url in urls) {
      try {
        final resp = await sl<Dio>().get<List<int>>(
          url,
          options: Options(
            responseType: ResponseType.bytes,
            headers: headers,
            contentType: null,
            receiveTimeout: const Duration(seconds: 60),
            extra: const {'skipSessionExpired': true},
          ),
        );
        final data = resp.data;
        if (data == null || data.isEmpty) continue;
        final bytes = Uint8List.fromList(data);
        if (!_looksLikeImageBytes(bytes)) continue;
        return bytes;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  bool _looksLikeImageBytes(Uint8List bytes) {
    if (bytes.length < 3) return false;
    // JPEG
    if (bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff) return true;
    // PNG
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47) {
      return true;
    }
    // GIF
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return true;
    // WEBP
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final bytes = snapshot.data;
        if (bytes == null) {
          return widget.errorWidget ??
              const Icon(Icons.broken_image_outlined, size: 24);
        }
        return Image.memory(bytes, fit: widget.fit, gaplessPlayback: true);
      },
    );
  }
}
