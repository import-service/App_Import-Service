import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:import_service_app/core/constants/api_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
