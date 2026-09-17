import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Нативная установка APK (FileProvider + ACTION_VIEW). Только Android.
final class ApkInstaller {
  ApkInstaller._();

  static const _channel = MethodChannel('import_service_app/apk_installer');

  static Future<bool> canRequestPackageInstalls() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('canRequestPackageInstalls');
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openUnknownAppSettings() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await _channel.invokeMethod<void>('openUnknownAppSettings');
  }

  /// Открыть системный установщик для локального APK [path].
  static Future<void> installApk(String path) async {
    if (kIsWeb || !Platform.isAndroid) {
      throw StateError('Только Android');
    }
    await _channel.invokeMethod<void>('installApk', {'path': path});
  }
}
