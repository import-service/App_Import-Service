import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:import_service_app/core/constants/api_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Манифест APK с нашего сервера (`GET /api/app/android-apk`).
final class AndroidServerApkInfo {
  const AndroidServerApkInfo({
    required this.available,
    this.versionCode,
    this.versionName,
    this.sha256,
    this.apkUrl,
    this.sizeBytes,
  });

  final bool available;
  final int? versionCode;
  final String? versionName;
  final String? sha256;
  final String? apkUrl;
  final int? sizeBytes;

  factory AndroidServerApkInfo.fromJson(Map<String, dynamic> json) {
    final available = json['available'] == true;
    final codeRaw = json['versionCode'];
    return AndroidServerApkInfo(
      available: available,
      versionCode: codeRaw is num ? codeRaw.toInt() : int.tryParse('$codeRaw'),
      versionName: json['versionName']?.toString(),
      sha256: json['sha256']?.toString(),
      apkUrl: json['apkUrl']?.toString(),
      sizeBytes: json['sizeBytes'] is num
          ? (json['sizeBytes'] as num).toInt()
          : int.tryParse('${json['sizeBytes']}'),
    );
  }
}

/// Публичный клиент раздачи APK с сервера Import Service.
final class AndroidServerApkClient {
  AndroidServerApkClient(this._dio);

  final Dio _dio;

  Future<AndroidServerApkInfo?> fetchManifest() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final response = await _dio.get<dynamic>('app/android-apk');
      final data = response.data;
      if (data is! Map) return null;
      final map = data.map((k, v) => MapEntry(k.toString(), v));
      return AndroidServerApkInfo.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// `true`, если на сервере есть опубликованный APK (для раздачи / скачивания).
  Future<bool> isServerApkPublished() async {
    final info = await fetchManifest();
    return info != null && info.available;
  }

  /// `true`, если на сервере APK с большим `versionCode`, чем у установленного.
  Future<bool> isServerNewerThanInstalled() async {
    final info = await fetchManifest();
    if (info == null || !info.available || info.versionCode == null) {
      return false;
    }
    final packageInfo = await PackageInfo.fromPlatform();
    final local = int.tryParse(packageInfo.buildNumber) ?? 0;
    return info.versionCode! > local;
  }

  /// Публичный URL скачивания (если APK есть).
  Future<String?> publicDownloadUrl() async {
    final info = await fetchManifest();
    if (info == null || !info.available) return null;
    return _resolveDownloadUrl(info.apkUrl);
  }

  /// Скачать APK во временный файл с прогрессом; проверить размер и sha256.
  Future<File> downloadApkToTemp({
    required void Function(int received, int? total) onProgress,
    void Function()? onVerifying,
    CancelToken? cancelToken,
  }) async {
    if (kIsWeb || !Platform.isAndroid) {
      throw StateError('Только Android');
    }
    final info = await fetchManifest();
    if (info == null || !info.available) {
      throw StateError('APK на сервере недоступен');
    }
    final url = _resolveDownloadUrl(info.apkUrl);
    final dir = await getTemporaryDirectory();
    final code = info.versionCode ?? 0;
    final path = '${dir.path}/import-service-$code.apk';
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }

    await _dio.download(
      url,
      path,
      cancelToken: cancelToken,
      onReceiveProgress: onProgress,
      options: Options(
        receiveTimeout: const Duration(minutes: 45),
        sendTimeout: const Duration(minutes: 2),
        headers: const {HttpHeaders.acceptEncodingHeader: 'identity'},
        followRedirects: true,
        validateStatus: (s) => s != null && s >= 200 && s < 400,
      ),
    );

    if (!await file.exists()) {
      throw StateError('Файл APK не сохранён');
    }
    onVerifying?.call();
    final len = await file.length();
    final expected = info.sizeBytes;
    if (expected != null && expected > 0 && len != expected) {
      await file.delete();
      throw StateError('SIZE_MISMATCH:$len:$expected');
    }
    final expectedSha = (info.sha256 ?? '').trim().toLowerCase();
    if (expectedSha.isNotEmpty) {
      final digest = await sha256.bind(file.openRead()).first;
      final actual = digest.toString();
      if (actual != expectedSha) {
        await file.delete();
        throw StateError('SHA_MISMATCH');
      }
    }
    return file;
  }

  /// Открыть публичную ссылку на APK во внешнем браузере (установка вручную).
  Future<void> openDownloadInBrowser() async {
    if (kIsWeb || !Platform.isAndroid) {
      throw StateError('Только Android');
    }
    final info = await fetchManifest();
    if (info == null || !info.available) {
      throw StateError('APK на сервере недоступен');
    }
    final url = _resolveDownloadUrl(info.apkUrl);
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      throw StateError('Не удалось открыть ссылку');
    }
  }

  String _resolveDownloadUrl(String? apkUrl) {
    final raw = (apkUrl ?? '').trim();
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    final base = ApiConfig.baseUrl.trim();
    final u = Uri.parse(base.endsWith('/') ? base : '$base/');
    // base уже …/api/ → относительный download path
    return u.resolve('app/android-apk/download').toString();
  }
}
