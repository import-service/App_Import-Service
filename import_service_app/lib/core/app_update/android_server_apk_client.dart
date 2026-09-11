import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

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

  /// Скачать APK, проверить sha256, открыть системный установщик.
  Future<void> downloadAndInstall({
    void Function(double? progress)? onProgress,
  }) async {
    if (kIsWeb || !Platform.isAndroid) {
      throw StateError('Только Android');
    }
    final info = await fetchManifest();
    if (info == null || !info.available) {
      throw StateError('APK на сервере недоступен');
    }
    final url = (info.apkUrl ?? '').trim();
    if (url.isEmpty) {
      throw StateError('Нет apkUrl');
    }

    final dir = await getTemporaryDirectory();
    final target = File('${dir.path}/import-service-latest.apk');
    if (await target.exists()) {
      await target.delete();
    }

    final absoluteOrRelative = url.startsWith('http')
        ? url
        : 'app/android-apk/download';

    await _dio.download(
      absoluteOrRelative,
      target.path,
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: true,
        receiveTimeout: const Duration(minutes: 15),
        sendTimeout: const Duration(minutes: 2),
        headers: const {'Accept': '*/*'},
      ),
      onReceiveProgress: (received, total) {
        if (total > 0) {
          onProgress?.call(received / total);
        } else {
          onProgress?.call(null);
        }
      },
    );

    final expected = (info.sha256 ?? '').trim().toLowerCase();
    if (expected.isNotEmpty) {
      final digest = await sha256.bind(target.openRead()).first;
      final actual = digest.toString();
      if (actual != expected) {
        await target.delete();
        throw StateError('sha256 APK не совпадает');
      }
    }

    final result = await OpenFilex.open(target.path);
    if (result.type != ResultType.done) {
      throw StateError(result.message);
    }
  }
}
