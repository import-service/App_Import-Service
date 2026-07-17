import 'dart:io';

import 'package:dio/dio.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/logging/app_log.dart';
import 'package:import_service_app/domain/entities/customs_doc_type.dart';
import 'package:import_service_app/domain/entities/customs_request_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

bool isRequestFileVideo(CustomsRequestFile file) {
  final mime = file.mimeType?.trim().toLowerCase() ?? '';
  if (mime.startsWith('video/')) return true;
  final code = CustomsDocType.normalizeCode(file.docType ?? '');
  if (code == CustomsDocType.transitArchiveVideo.apiCode) return true;
  if (code.endsWith('_video')) return true;
  final probe = '${file.fileName ?? ''} ${file.fileUrl ?? ''}'.toLowerCase();
  return RegExp(r'\.(mp4|mov|webm|mkv|avi|m4v)$').hasMatch(probe);
}

/// Фото по mime / расширению / docType (архив транзита и слоты создания).
bool isRequestFileImage(CustomsRequestFile file) {
  final mime = file.mimeType?.trim().toLowerCase() ?? '';
  if (mime.startsWith('image/')) return true;
  final code = CustomsDocType.normalizeCode(file.docType ?? '');
  if (code.startsWith('transit_archive_photo')) return true;
  if (code.endsWith('_photo') || code.contains('_photo_')) return true;
  const creationPhotos = {
    'passport_front',
    'passport_registration',
    'car_nameplate_photo',
    'car_mileage_photo',
    'car_front_photo',
    'car_back_photo',
    'inn',
    'snils',
  };
  if (creationPhotos.contains(code)) return true;
  final probe = '${file.fileName ?? ''} ${file.fileUrl ?? ''}'.toLowerCase();
  return RegExp(r'\.(jpe?g|png|webp|gif|heic|bmp)$').hasMatch(probe);
}

/// URL для миниатюры: фото — previewUrl ?? fileUrl; видео — только previewUrl.
String? requestFileThumbnailUrl(CustomsRequestFile file) {
  if (isRequestFileVideo(file)) {
    final preview = file.previewUrl?.trim();
    return (preview != null && preview.isNotEmpty) ? preview : null;
  }
  if (isRequestFileImage(file)) {
    final preview = file.previewUrl?.trim();
    if (preview != null && preview.isNotEmpty) return preview;
    return file.fileUrl?.trim();
  }
  return null;
}

/// URL для скачивания / полноразмерного просмотра / плеера.
String? requestFileFullUrl(CustomsRequestFile file) => file.fileUrl?.trim();

/// PDF по mime/расширению. `.bin` + octet-stream **не** считаем PDF без magic bytes.
bool isRequestFilePdf(CustomsRequestFile file) {
  final mime = file.mimeType?.trim().toLowerCase() ?? '';
  if (mime == 'application/pdf') return true;
  if (mime.startsWith('image/') || mime.startsWith('video/')) return false;
  if (isRequestFileImage(file) || isRequestFileVideo(file)) return false;
  final probe = '${file.fileName ?? ''} ${file.fileUrl ?? ''}'.toLowerCase();
  if (probe.contains('.pdf')) return true;
  return false;
}

/// Не показывать в подзаголовке технические имена (GUID с диска сервера).
bool isTechnicalRequestFileName(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return true;
  if (RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-').hasMatch(value)) return true;
  // Внутреннее имя на диске сервера: `{key}__{docType}.ext`
  if (RegExp(r'^.+__[\w.-]+\.\w+$').hasMatch(value)) return true;
  if (value.contains('__') && value.length > 24) return true;
  return false;
}

String requestFileDownloadName(CustomsRequestFile file) {
  final doc = (file.docType ?? 'file').replaceAll(RegExp(r'[^\w.\-]+'), '_');
  if (isRequestFilePdf(file)) return '$doc.pdf';
  if (isRequestFileImage(file)) {
    final fromUrl = p.extension(file.fileUrl ?? '').toLowerCase();
    if (fromUrl.isNotEmpty &&
        fromUrl.length <= 5 &&
        fromUrl != '.bin' &&
        RegExp(r'\.(jpe?g|png|webp|gif|heic|bmp)$').hasMatch(fromUrl)) {
      return '$doc$fromUrl';
    }
    final fromName = p.extension(file.fileName ?? '').toLowerCase();
    if (fromName.isNotEmpty &&
        fromName != '.bin' &&
        RegExp(r'\.(jpe?g|png|webp|gif|heic|bmp)$').hasMatch(fromName)) {
      return '$doc$fromName';
    }
    return '$doc.jpg';
  }
  final ext = p.extension(file.fileName ?? file.fileUrl ?? '').toLowerCase();
  if (ext.isNotEmpty && ext != '.bin') return '$doc$ext';
  return doc;
}

Future<bool> fileHasPdfMagic(String path) async {
  try {
    final raf = await File(path).open();
    final bytes = await raf.read(4);
    await raf.close();
    return bytes.length >= 4 && String.fromCharCodes(bytes) == '%PDF';
  } catch (_) {
    return false;
  }
}

Future<bool> fileHasJpegMagic(String path) async {
  try {
    final raf = await File(path).open();
    final bytes = await raf.read(3);
    await raf.close();
    return bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff;
  } catch (_) {
    return false;
  }
}

Future<bool> fileHasPngMagic(String path) async {
  try {
    final raf = await File(path).open();
    final bytes = await raf.read(4);
    await raf.close();
    return bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47;
  } catch (_) {
    return false;
  }
}

/// Путь к локальному PDF (с расширением `.pdf`), если содержимое — PDF.
Future<String> normalizePdfPathIfNeeded(String path) async {
  if (!await fileHasPdfMagic(path)) return path;
  if (path.toLowerCase().endsWith('.pdf')) return path;
  final pdfPath = '$path.pdf';
  await File(path).copy(pdfPath);
  return pdfPath;
}

/// Если скачали `.bin`, а внутри JPEG/PNG — переименовать для системных viewer.
Future<String> normalizeImagePathIfNeeded(String path) async {
  final lower = path.toLowerCase();
  if (await fileHasJpegMagic(path) && !RegExp(r'\.jpe?g$').hasMatch(lower)) {
    final jpgPath = '$path.jpg';
    await File(path).copy(jpgPath);
    return jpgPath;
  }
  if (await fileHasPngMagic(path) && !lower.endsWith('.png')) {
    final pngPath = '$path.png';
    await File(path).copy(pngPath);
    return pngPath;
  }
  return path;
}

/// Скачать файл с Bearer (Dio). Возвращает локальный путь или `null`.
Future<String?> downloadAuthenticatedRequestFile(
  String url,
  CustomsRequestFile file,
) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;
  try {
    final dir = await getTemporaryDirectory();
    final savePath = p.join(dir.path, requestFileDownloadName(file));
    await sl<Dio>().download(
      trimmed,
      savePath,
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: true,
      ),
    );
    if (!await File(savePath).exists()) return null;
    if (await fileHasPdfMagic(savePath) || isRequestFilePdf(file)) {
      return normalizePdfPathIfNeeded(savePath);
    }
    if (await fileHasJpegMagic(savePath) ||
        await fileHasPngMagic(savePath) ||
        isRequestFileImage(file)) {
      return normalizeImagePathIfNeeded(savePath);
    }
    return savePath;
  } catch (e, st) {
    AppLog.error(
      'downloadAuthenticatedRequestFile docType=${file.docType}',
      tag: 'RequestFile',
      error: e,
      stackTrace: st,
    );
    return null;
  }
}

Future<bool> shouldOpenAsInAppPdf(String localPath, CustomsRequestFile file) async {
  if (await fileHasJpegMagic(localPath) || await fileHasPngMagic(localPath)) {
    return false;
  }
  if (isRequestFileImage(file)) return false;
  if (await fileHasPdfMagic(localPath)) return true;
  return isRequestFilePdf(file);
}

String shareableFileName(String title, String filePath) {
  final base = title.trim().isNotEmpty
      ? title.replaceAll(RegExp(r'[^\w.\- ()\u0400-\u04FF]'), '_')
      : 'document';
  final ext = p.extension(filePath);
  if (ext.isNotEmpty && !base.toLowerCase().endsWith(ext.toLowerCase())) {
    return '$base$ext';
  }
  if (ext.isEmpty) return '$base.pdf';
  return base;
}

/// Системная шторка «Поделиться» / «Сохранить в Файлы» (iOS и Android).
Future<bool> shareLocalRequestFile({
  required String filePath,
  required String displayName,
}) async {
  if (!await File(filePath).exists()) return false;
  try {
    final name = shareableFileName(displayName, filePath);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath, name: name)],
        subject: displayName,
      ),
    );
    return true;
  } catch (e, st) {
    AppLog.error(
      'shareLocalRequestFile',
      tag: 'RequestFile',
      error: e,
      stackTrace: st,
    );
    return false;
  }
}
