import 'dart:io';
import 'dart:math';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:import_service_app/core/logging/app_log.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final class RequestDraftAttachmentsSpace {
  RequestDraftAttachmentsSpace._();

  static const _attachmentsDirName = 'request_draft_attachments';
  static const int _maxImageBytes = 1024 * 1024; // 1MB

  static Future<Directory> _attachmentsRoot() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, _attachmentsDirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<String> _attachmentsRootPath() async {
    final d = await _attachmentsRoot();
    return d.path;
  }

  static Future<Directory> ensureDraftDirectory(String draftId) async {
    if (draftId.isEmpty) {
      throw ArgumentError.value(draftId, 'draftId', 'must be non-empty');
    }
    final root = await _attachmentsRoot();
    final dir = Directory(p.join(root.path, draftId));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<void> deleteDraftDirectory(String draftId) async {
    if (draftId.isEmpty) return;
    try {
      final root = await _attachmentsRoot();
      final dir = Directory(p.join(root.path, draftId));
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e, st) {
      AppLog.error(
        'Не удалось удалить папку вложений черновика заявки',
        tag: 'RequestDraftAttachmentsSpace',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Удаляет все вложения черновиков (при смене профиля / входе в демо).
  static Future<void> deleteAll() async {
    try {
      final base = await getApplicationSupportDirectory();
      final dir = Directory(p.join(base.path, _attachmentsDirName));
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e, st) {
      AppLog.error(
        'Не удалось удалить все вложения черновиков заявки',
        tag: 'RequestDraftAttachmentsSpace',
        error: e,
        stackTrace: st,
      );
    }
  }

  static Future<String> ingestPickedFile({
    required String draftId,
    required String sourcePath,
  }) async {
    final src = sourcePath.trim();
    if (src.isEmpty) return '';
    if (!_isCopyableFilesystemPath(src)) return src;
    try {
      final srcFile = File(src);
      if (!await srcFile.exists()) return src;
      final draftDir = await ensureDraftDirectory(draftId);
      final ext = p.extension(src).isNotEmpty ? p.extension(src).toLowerCase() : '.jpg';
      final name =
          'photo_${DateTime.now().microsecondsSinceEpoch}_${_rand.nextInt(1 << 20)}$ext';
      final destPath = p.join(draftDir.path, name);
      if (_isCompressibleImageExt(ext)) {
        final bytes = await _compressImageTo1Mb(srcFile.path);
        if (bytes != null) {
          await File(destPath).writeAsBytes(bytes, flush: true);
          return destPath;
        }
      }
      await srcFile.copy(destPath);
      return destPath;
    } catch (e, st) {
      AppLog.error(
        'Копирование снимка в папку черновика заявки',
        tag: 'RequestDraftAttachmentsSpace',
        error: e,
        stackTrace: st,
      );
      return src;
    }
  }

  static Future<void> tryDeleteFileUnderAttachmentsRoot(String filePath) async {
    final path = filePath.trim();
    if (path.isEmpty || !_isCopyableFilesystemPath(path)) return;
    try {
      final rootPath = await _attachmentsRootPath();
      if (!_isPathWithinParent(rootPath, path)) return;
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (e, st) {
      AppLog.error(
        'Не удалось удалить файл вложения заявки',
        tag: 'RequestDraftAttachmentsSpace',
        error: e,
        stackTrace: st,
      );
    }
  }

  static bool _isPathWithinParent(String parent, String child) {
    final a = p.normalize(parent).replaceAll('\\', '/').toLowerCase();
    var b = p.normalize(child).replaceAll('\\', '/').toLowerCase();
    if (b.endsWith('/')) b = b.substring(0, b.length - 1);
    return b.startsWith(a.endsWith('/') ? a : '$a/');
  }

  static bool _isCopyableFilesystemPath(String pth) {
    if (pth.startsWith('http://') || pth.startsWith('https://')) return false;
    if (pth.startsWith('content://') || pth.startsWith('ph://')) return false;
    return pth.startsWith('/') || RegExp(r'^[A-Za-z]:[/\\]').hasMatch(pth);
  }

  static bool _isCompressibleImageExt(String ext) {
    return ext == '.jpg' ||
        ext == '.jpeg' ||
        ext == '.png' ||
        ext == '.webp' ||
        ext == '.heic' ||
        ext == '.heif';
  }

  static Future<List<int>?> _compressImageTo1Mb(String sourcePath) async {
    try {
      final original = await File(sourcePath).readAsBytes();
      if (original.lengthInBytes <= _maxImageBytes) {
        return original;
      }

      const attempts = <({int quality, int minWidth, int minHeight})>[
        (quality: 90, minWidth: 1920, minHeight: 1920),
        (quality: 82, minWidth: 1600, minHeight: 1600),
        (quality: 74, minWidth: 1400, minHeight: 1400),
        (quality: 66, minWidth: 1280, minHeight: 1280),
        (quality: 58, minWidth: 1080, minHeight: 1080),
        (quality: 50, minWidth: 900, minHeight: 900),
        (quality: 42, minWidth: 800, minHeight: 800),
      ];

      List<int>? best = original;
      for (final a in attempts) {
        final out = await FlutterImageCompress.compressWithFile(
          sourcePath,
          format: CompressFormat.jpeg,
          quality: a.quality,
          minWidth: a.minWidth,
          minHeight: a.minHeight,
          keepExif: true,
        );
        if (out == null || out.isEmpty) continue;
        if (best == null || out.length < best.length) {
          best = out;
        }
        if (out.lengthInBytes <= _maxImageBytes) {
          return out;
        }
      }
      return best;
    } catch (e, st) {
      AppLog.error(
        'Сжатие фото перед сохранением',
        tag: 'RequestDraftAttachmentsSpace',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  static final _rand = Random();
}
