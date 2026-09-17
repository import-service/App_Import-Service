import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/core/ui/app_feedback_kind.dart';
import 'package:import_service_app/core/ui/app_feedback_service.dart';
import 'package:import_service_app/presentation/helpers/request_file_preview_helper.dart';
import 'package:video_player/video_player.dart';

/// In-app просмотр видео из локального файла (после скачивания с Bearer).
class RequestVideoPlayerPage extends StatefulWidget {
  const RequestVideoPlayerPage({
    super.key,
    required this.filePath,
    required this.title,
  });

  final String filePath;
  final String title;

  @override
  State<RequestVideoPlayerPage> createState() => _RequestVideoPlayerPageState();
}

class _RequestVideoPlayerPageState extends State<RequestVideoPlayerPage> {
  VideoPlayerController? _controller;
  String? _error;
  bool _showControls = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _friendlyError(Object e) {
    final s = sl<JsonStringsService>();
    if (e is PlatformException) {
      final msg = '${e.code} ${e.message} ${e.details}'.toLowerCase();
      if (msg.contains('mediacodec') ||
          msg.contains('videoerror') ||
          msg.contains('renderer')) {
        return s.text('requestVideoPlayFailedCodec');
      }
    }
    final raw = e.toString().toLowerCase();
    if (raw.contains('mediacodec') ||
        raw.contains('videoerror') ||
        raw.contains('renderer')) {
      return s.text('requestVideoPlayFailedCodec');
    }
    return s.text('requestVideoPlayFailed');
  }

  Future<void> _load() async {
    final path = widget.filePath.trim();
    if (path.isEmpty || !File(path).existsSync()) {
      if (mounted) {
        setState(() => _error = sl<JsonStringsService>().requestDocumentOpenFailed);
      }
      return;
    }
    final controller = VideoPlayerController.file(File(path));
    try {
      await controller.initialize();
      await controller.setLooping(true);
      controller.addListener(() {
        if (!mounted) return;
        final err = controller.value.errorDescription;
        if (err != null && err.isNotEmpty) {
          setState(() => _error = _friendlyError(StateError(err)));
          return;
        }
        setState(() {});
      });
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (e) {
      await controller.dispose();
      if (mounted) setState(() => _error = _friendlyError(e));
    }
  }

  Future<void> _shareOrSave({required bool asDownload}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final s = sl<JsonStringsService>();
    final ok = await shareLocalRequestFile(
      filePath: widget.filePath,
      displayName: widget.title,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      sl<AppFeedbackService>().show(
        s.requestMediaActionFailed,
        kind: AppFeedbackKind.error,
      );
      return;
    }
    if (asDownload) {
      sl<AppFeedbackService>().show(
        s.requestMediaSaveHint,
        kind: AppFeedbackKind.success,
      );
    }
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  List<Widget> _actionButtons(JsonStringsService s) {
    return [
      IconButton(
        onPressed: _busy ? null : () => _shareOrSave(asDownload: true),
        tooltip: s.requestMediaDownloadButton,
        icon: _busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.download_rounded),
      ),
      IconButton(
        onPressed: _busy ? null : () => _shareOrSave(asDownload: false),
        tooltip: s.requestMediaShareButton,
        icon: const Icon(Icons.ios_share_rounded),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final s = sl<JsonStringsService>();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        actions: _actionButtons(s),
      ),
      body: () {
        final err = _error;
        if (err != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    err,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _shareOrSave(asDownload: false),
                    icon: const Icon(Icons.ios_share_rounded),
                    label: Text(s.text('requestVideoOpenExternal')),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : () => _shareOrSave(asDownload: true),
                    icon: const Icon(Icons.download_rounded),
                    label: Text(s.requestMediaDownloadButton),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _error = null;
                        _controller = null;
                      });
                      _load();
                    },
                    child: Text(s.text('requestVideoRetry')),
                  ),
                ],
              ),
            ),
          );
        }
        final c = _controller;
        if (c == null || !c.value.isInitialized) {
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _showControls = !_showControls),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(
                      child: AspectRatio(
                        aspectRatio: c.value.aspectRatio == 0
                            ? 16 / 9
                            : c.value.aspectRatio,
                        child: VideoPlayer(c),
                      ),
                    ),
                    if (_showControls)
                      Center(
                        child: Material(
                          color: Colors.black45,
                          shape: const CircleBorder(),
                          child: IconButton(
                            iconSize: 56,
                            color: Colors.white,
                            onPressed: _togglePlay,
                            icon: Icon(
                              c.value.isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_filled,
                            ),
                          ),
                        ),
                      ),
                    if (_showControls)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: SafeArea(
                          top: false,
                          bottom: false,
                          child: Material(
                            color: Colors.black54,
                            child: VideoProgressIndicator(
                              c,
                              allowScrubbing: true,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                              colors: const VideoProgressColors(
                                playedColor: AppTheme.accentRed,
                                bufferedColor: Colors.white38,
                                backgroundColor: Colors.white24,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            _busy ? null : () => _shareOrSave(asDownload: true),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                        ),
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: Text(s.requestMediaDownloadButton),
                      ),
                    ),
                    const Gap(10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed:
                            _busy ? null : () => _shareOrSave(asDownload: false),
                        icon: const Icon(Icons.ios_share_rounded, size: 18),
                        label: Text(s.requestMediaShareButton),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }(),
    );
  }
}
