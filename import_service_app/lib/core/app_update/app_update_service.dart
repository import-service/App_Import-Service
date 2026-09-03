import 'dart:async';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rustore_update/flutter_rustore_update.dart' as rustore_update;
import 'package:in_app_update/in_app_update.dart' as play_update;
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/logging/app_log.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const String kAndroidPackageName = 'com.importservice.app';
const String kIosAppStoreId = '6785875687';

const String kPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=$kAndroidPackageName';
const String kRuStoreUrl =
    'https://www.rustore.ru/catalog/app/$kAndroidPackageName';
const String kAppStoreUrl =
    'https://apps.apple.com/ru/app/id$kIosAppStoreId';

/// Проверка обновления и диалог — один раз за сессию после входа.
final class AppUpdateService {
  AppUpdateService(this._dio);

  final Dio _dio;
  bool _checkDoneThisSession = false;
  StreamSubscription<rustore_update.RequestResponse>? _rustoreStateSub;
  StreamSubscription<play_update.InstallStatus>? _playInstallSub;

  Future<void> maybePromptForUpdate(BuildContext context) async {
    if (_checkDoneThisSession) return;
    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;

    _checkDoneThisSession = true;

    try {
      final needed = await _isUpdateNeeded();
      if (!needed) return;
      if (!context.mounted) return;

      final strings = sl<JsonStringsService>();
      final update = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(strings.text('appUpdateTitle')),
          content: Text(strings.text('appUpdateMessage')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(strings.text('appUpdateLater')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(strings.text('appUpdateButton')),
            ),
          ],
        ),
      );

      if (update != true || !context.mounted) return;
      await _performUpdate(context);
    } catch (e, st) {
      AppLog.error(
        'app update check failed',
        tag: 'AppUpdate',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<bool> _isUpdateNeeded() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final stores = await _fetchStoreVersions();
    if (stores.isEmpty) return false;

    if (Platform.isIOS) {
      final appStore = stores.firstWhere(
        (s) => s.store == 'app_store',
        orElse: () => const _StoreVersionInfo(store: 'app_store'),
      );
      if (appStore.versionName == null) return false;
      return _isVersionOlder(packageInfo.version, appStore.versionName!);
    }

    if (Platform.isAndroid) {
      final localBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
      int maxStoreBuild = 0;
      for (final store in stores) {
        if (store.store == 'google_play' || store.store == 'rustore') {
          final code = store.versionCode;
          if (code != null && code > maxStoreBuild) {
            maxStoreBuild = code;
          }
        }
      }
      if (maxStoreBuild <= 0) return false;
      return localBuild < maxStoreBuild;
    }

    return false;
  }

  Future<List<_StoreVersionInfo>> _fetchStoreVersions() async {
    try {
      final response = await _dio.get<dynamic>('app/store-versions');
      final data = response.data;
      if (data is! Map<String, dynamic>) return const [];
      final raw = data['stores'];
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(_StoreVersionInfo.fromJson)
          .toList(growable: false);
    } on DioException catch (e) {
      AppLog.trace(
        'store-versions fetch failed: ${e.message}',
        tag: 'AppUpdate',
      );
      return const [];
    }
  }

  Future<void> _performUpdate(BuildContext context) async {
    if (Platform.isIOS) {
      await _openExternalUrl(kAppStoreUrl);
      return;
    }

    if (!Platform.isAndroid) return;

    final playOk = await _tryPlayFlexibleUpdate(context);
    if (playOk) return;

    final rustoreOk = await _tryRuStoreFlexibleUpdate(context);
    if (rustoreOk) return;

    await _openExternalUrl(kPlayStoreUrl);
    await _openExternalUrl(kRuStoreUrl);
  }

  Future<bool> _tryPlayFlexibleUpdate(BuildContext context) async {
    try {
      final info = await play_update.InAppUpdate.checkForUpdate();
      if (info.updateAvailability !=
          play_update.UpdateAvailability.updateAvailable) {
        return false;
      }
      if (info.flexibleUpdateAllowed != true) {
        return false;
      }

      _playInstallSub?.cancel();
      _playInstallSub = play_update.InAppUpdate.installUpdateListener.listen(
        (status) {
          if (status == play_update.InstallStatus.downloaded) {
            unawaited(_completePlayFlexible(context));
          }
        },
      );

      final result = await play_update.InAppUpdate.startFlexibleUpdate();
      return result == play_update.AppUpdateResult.success;
    } catch (e) {
      AppLog.trace('Play in-app update failed: $e', tag: 'AppUpdate');
      return false;
    }
  }

  Future<void> _completePlayFlexible(BuildContext context) async {
    if (!context.mounted) return;
    final strings = sl<JsonStringsService>();
    final install = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.text('appUpdateReadyTitle')),
        content: Text(strings.text('appUpdateReadyMessage')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(strings.text('appUpdateLater')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(strings.text('appUpdateInstallButton')),
          ),
        ],
      ),
    );
    if (install == true) {
      await play_update.InAppUpdate.completeFlexibleUpdate();
    }
  }

  Future<bool> _tryRuStoreFlexibleUpdate(BuildContext context) async {
    try {
      final info = await rustore_update.RustoreUpdateClient.info();
      if (info.updateAvailabilityValue !=
          rustore_update.UpdateAvailability.available) {
        return false;
      }

      _rustoreStateSub?.cancel();
      _rustoreStateSub =
          rustore_update.RustoreUpdateClient.stateStream.listen((state) {
        if (state.installStatusValue ==
            rustore_update.InstallStatus.downloaded) {
          unawaited(_completeRuStoreFlexible(context));
        }
      });

      await rustore_update.RustoreUpdateClient.download();
      return true;
    } catch (e) {
      AppLog.trace('RuStore in-app update failed: $e', tag: 'AppUpdate');
      return false;
    }
  }

  Future<void> _completeRuStoreFlexible(BuildContext context) async {
    if (!context.mounted) return;
    final strings = sl<JsonStringsService>();
    final install = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.text('appUpdateReadyTitle')),
        content: Text(strings.text('appUpdateReadyMessage')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(strings.text('appUpdateLater')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(strings.text('appUpdateInstallButton')),
          ),
        ],
      ),
    );
    if (install == true) {
      await rustore_update.RustoreUpdateClient.completeUpdateFlexible();
    }
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  bool _isVersionOlder(String local, String store) {
    final lp = _parseVersionParts(local);
    final sp = _parseVersionParts(store);
    final maxLen = lp.length > sp.length ? lp.length : sp.length;
    for (var i = 0; i < maxLen; i++) {
      final l = i < lp.length ? lp[i] : 0;
      final s = i < sp.length ? sp[i] : 0;
      if (l < s) return true;
      if (l > s) return false;
    }
    return false;
  }

  List<int> _parseVersionParts(String raw) {
    return raw
        .split('.')
        .map((p) => int.tryParse(p.trim()) ?? 0)
        .toList(growable: false);
  }

  void dispose() {
    _rustoreStateSub?.cancel();
    _playInstallSub?.cancel();
  }
}

final class _StoreVersionInfo {
  const _StoreVersionInfo({
    required this.store,
    this.versionName,
    this.versionCode,
  });

  final String store;
  final String? versionName;
  final int? versionCode;

  factory _StoreVersionInfo.fromJson(Map<String, dynamic> json) {
    final codeRaw = json['versionCode'];
    return _StoreVersionInfo(
      store: json['store']?.toString() ?? '',
      versionName: json['versionName']?.toString(),
      versionCode: codeRaw is num ? codeRaw.toInt() : int.tryParse('$codeRaw'),
    );
  }
}
