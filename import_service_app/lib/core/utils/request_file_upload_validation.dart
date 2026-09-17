import 'dart:io';

import 'package:import_service_app/domain/entities/customs_doc_type.dart';
import 'package:path/path.dart' as p;

/// Ключ i18n: фото/PDF/документы — 25 МБ.
const requestFileSizeLimitPhotoKey = 'requestFileTooLargePhoto';

/// Ключ i18n: видео/аудио — 100 МБ.
const requestFileSizeLimitVideoKey = 'requestFileTooLargeVideo';

const int kRequestFileMaxPhotoPdfBytes = 25 * 1024 * 1024;
const int kRequestFileMaxVideoAudioBytes = 100 * 1024 * 1024;

bool isLocalFileVideoOrAudio(String path, {String? docType}) {
  final mime = _mimeFromPath(path);
  if (mime.startsWith('video/') || mime.startsWith('audio/')) return true;
  return RegExp(r'\.(mp4|mov|webm|mkv|avi|m4v|mp3|m4a|wav|aac|ogg)$')
      .hasMatch(path.toLowerCase());
}

/// Файл по расширению — видео (не JPEG/PNG). Для слотов `svh_car_video_*`.
bool looksLikeLocalVideoFile(String path) {
  final ext = p.extension(path).toLowerCase();
  return const {'.mp4', '.mov', '.webm', '.mkv', '.avi', '.m4v'}.contains(ext);
}

/// `null` — размер допустим; иначе ключ для [JsonStringsService.text].
String? requestFileSizeLimitMessageKey(String path, {String? docType}) {
  final file = File(path);
  if (!file.existsSync()) return null;
  final size = file.lengthSync();
  final code = CustomsDocType.normalizeCode(docType ?? '');
  final forceVideoSlot = RegExp(r'^svh_car_video_\d+$').hasMatch(code) ||
      code.endsWith('_video') ||
      code == CustomsDocType.transitArchiveVideo.apiCode;
  final videoAudio = forceVideoSlot
      ? looksLikeLocalVideoFile(path)
      : isLocalFileVideoOrAudio(path, docType: docType);
  final max =
      videoAudio ? kRequestFileMaxVideoAudioBytes : kRequestFileMaxPhotoPdfBytes;
  if (size <= max) return null;
  return videoAudio ? requestFileSizeLimitVideoKey : requestFileSizeLimitPhotoKey;
}

String _mimeFromPath(String path) {
  switch (p.extension(path).toLowerCase()) {
    case '.mp4':
    case '.m4v':
      return 'video/mp4';
    case '.mov':
      return 'video/quicktime';
    case '.webm':
      return 'video/webm';
    case '.mkv':
      return 'video/x-matroska';
    case '.avi':
      return 'video/x-msvideo';
    case '.mp3':
      return 'audio/mpeg';
    case '.m4a':
      return 'audio/mp4';
    case '.wav':
      return 'audio/wav';
    case '.aac':
      return 'audio/aac';
    case '.ogg':
      return 'audio/ogg';
    case '.pdf':
      return 'application/pdf';
    case '.png':
      return 'image/png';
    case '.webp':
      return 'image/webp';
    case '.gif':
      return 'image/gif';
    default:
      return 'image/jpeg';
  }
}
