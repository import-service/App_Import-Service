import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Источник установки Android-приложения (по installer package).
enum AppInstallSourceKind {
  googlePlay,
  rustore,
  unknown,
}

/// Чтение installer package через нативный channel.
final class AppInstallSource {
  AppInstallSource._();

  static const _channel = MethodChannel('import_service_app/install_source');

  /// Play / RuStore / unknown. На iOS/web — always unknown.
  static Future<({AppInstallSourceKind kind, String? installerPackage})>
      resolve() async {
    if (kIsWeb || !Platform.isAndroid) {
      return (kind: AppInstallSourceKind.unknown, installerPackage: null);
    }
    try {
      final raw = await _channel.invokeMethod<String?>('getInstallerPackageName');
      final pkg = (raw == null || raw.isEmpty) ? null : raw;
      return (kind: _mapInstaller(pkg), installerPackage: pkg);
    } catch (_) {
      return (kind: AppInstallSourceKind.unknown, installerPackage: null);
    }
  }

  static AppInstallSourceKind _mapInstaller(String? pkg) {
    if (pkg == null) return AppInstallSourceKind.unknown;
    final p = pkg.toLowerCase();
    if (p == 'com.android.vending' || p == 'com.google.android.feedback') {
      return AppInstallSourceKind.googlePlay;
    }
    // RuStore / VK Store
    if (p == 'ru.vk.store' ||
        p == 'ru.rustore.lite' ||
        p.contains('rustore') ||
        p == 'com.vk.store') {
      return AppInstallSourceKind.rustore;
    }
    return AppInstallSourceKind.unknown;
  }
}
