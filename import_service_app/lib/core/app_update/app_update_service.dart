import 'dart:async';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rustore_update/flutter_rustore_update.dart' as rustore_update;
import 'package:in_app_update/in_app_update.dart' as play_update;
import 'package:import_service_app/core/app_update/app_install_source.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/logging/app_log.dart';
import 'package:import_service_app/core/ui/app_feedback_kind.dart';
import 'package:import_service_app/core/ui/app_feedback_service.dart';
import 'package:import_service_app/presentation/router/app_router.dart';
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

/// Проверка обновления и диалог — один раз за жизнь процесса (cold start).
/// Logout / демо флаг не сбрасывают (см. [AppUpdateBootstrap]).
final class AppUpdateService {
  AppUpdateService(this._dio);

  final Dio _dio;
  bool _checkDoneThisSession = false;
  bool _promptInFlight = false;
  StreamSubscription<rustore_update.RequestResponse>? _rustoreStateSub;
  StreamSubscription<play_update.InstallStatus>? _playInstallSub;

  void _dbg(String msg) {
    // print — всегда в logcat; debugPrint может резаться.
    // ignore: avoid_print
    print('[AppUpdate] $msg');
  }

  /// Ручной сброс (тесты / редкие случаи). Bootstrap при logout/демо не вызывает.
  void resetSessionFlag() {
    _checkDoneThisSession = false;
    _promptInFlight = false;
    _dbg('session flag reset');
  }

  Future<void> maybePromptForUpdate(BuildContext? context) async {
    if (_checkDoneThisSession) {
      _dbg('skip: already checked this session');
      return;
    }
    if (_promptInFlight) {
      _dbg('skip: prompt in flight');
      return;
    }
    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;

    _promptInFlight = true;
    _dbg('check start');

    try {
      final check = await _evaluateUpdate();
      _dbg('updateNeeded=${check?.needed}');
      if (check == null || !check.needed) {
        return;
      }

      final ctx = _dialogContext(context);
      if (ctx == null) {
        // _evaluateUpdate уже мог выставить флаг — откатываем, иначе диалог не покажем.
        _checkDoneThisSession = false;
        _dbg('no dialog context — will retry next call');
        return;
      }

      final strings = sl<JsonStringsService>();
      final message = strings
          .text('appUpdateMessage')
          .replaceAll('{storeVersion}', check.storeVersion)
          .replaceAll('{localVersion}', check.localVersion);
      final update = await showDialog<bool>(
        context: ctx,
        useRootNavigator: true,
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          title: Text(strings.text('appUpdateTitle')),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text(strings.text('appUpdateLater')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: Text(strings.text('appUpdateButton')),
            ),
          ],
        ),
      );

      _dbg('dialogResult=$update');
      _checkDoneThisSession = true;
      if (update != true) return;
      final afterCtx = _dialogContext(context);
      if (afterCtx == null) return;
      await _performUpdate(afterCtx);
    } catch (e, st) {
      AppLog.error(
        'app update check failed',
        tag: 'AppUpdate',
        error: e,
        stackTrace: st,
      );
      _dbg('error: $e');
    } finally {
      _promptInFlight = false;
    }
  }

  BuildContext? _dialogContext(BuildContext? preferred) {
    if (preferred != null && preferred.mounted) return preferred;
    return appRouter.routerDelegate.navigatorKey.currentContext;
  }

  /// `null` = нет данных (можно повторить). Иначе результат сравнения.
  Future<_UpdateCheckResult?> _evaluateUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final stores = await _fetchStoreVersions();
    if (stores.isEmpty) {
      _dbg('no store versions from API (will retry later)');
      return null;
    }

    // Успешно получили каталог сторов — повтор в этой сессии не нужен,
    // даже если обновление не требуется.
    _checkDoneThisSession = true;

    final localLabel = packageInfo.version;

    if (Platform.isIOS) {
      final appStore = stores.firstWhere(
        (s) => s.store == 'app_store',
        orElse: () => const _StoreVersionInfo(store: 'app_store'),
      );
      if (appStore.versionName == null) {
        return _UpdateCheckResult(
          needed: false,
          localVersion: localLabel,
          storeVersion: localLabel,
        );
      }
      final older = _isVersionOlder(packageInfo.version, appStore.versionName!);
      _dbg(
        'ios local=${packageInfo.version} store=${appStore.versionName} older=$older',
      );
      return _UpdateCheckResult(
        needed: older,
        localVersion: localLabel,
        storeVersion: appStore.versionName!,
      );
    }

    if (Platform.isAndroid) {
      final localBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
      int maxStoreBuild = 0;
      String? bestStoreName;
      for (final store in stores) {
        if (store.store != 'google_play' && store.store != 'rustore') continue;
        final code = store.versionCode;
        if (code != null && code > maxStoreBuild) {
          maxStoreBuild = code;
          bestStoreName = store.versionName;
        } else if (code == null &&
            store.versionName != null &&
            (bestStoreName == null ||
                _isVersionOlder(bestStoreName, store.versionName!))) {
          bestStoreName = store.versionName;
        }
      }

      var needed = maxStoreBuild > 0 && localBuild < maxStoreBuild;
      if (!needed &&
          maxStoreBuild <= 0 &&
          bestStoreName != null &&
          bestStoreName.isNotEmpty) {
        needed = _isVersionOlder(packageInfo.version, bestStoreName);
      }

      final storeLabel = (bestStoreName != null && bestStoreName.isNotEmpty)
          ? bestStoreName
          : (maxStoreBuild > 0 ? maxStoreBuild.toString() : localLabel);

      _dbg(
        'android local=${packageInfo.version}+${packageInfo.buildNumber} '
        'maxStoreBuild=$maxStoreBuild storeName=$bestStoreName needed=$needed '
        'stores=${stores.map((s) => '${s.store}:${s.versionCode}/${s.versionName}').join(',')}',
      );
      return _UpdateCheckResult(
        needed: needed,
        localVersion: localLabel,
        storeVersion: storeLabel,
      );
    }

    return _UpdateCheckResult(
      needed: false,
      localVersion: localLabel,
      storeVersion: localLabel,
    );
  }

  Future<List<_StoreVersionInfo>> _fetchStoreVersions() async {
    try {
      final response = await _dio.get<dynamic>('app/store-versions');
      final data = response.data;
      final map = _asStringKeyedMap(data);
      if (map == null) {
        _dbg('store-versions bad payload type=${data.runtimeType}');
        return const [];
      }
      final raw = map['stores'];
      if (raw is! List) {
        _dbg('store-versions missing stores[]');
        return const [];
      }
      final list = <_StoreVersionInfo>[];
      for (final item in raw) {
        final row = _asStringKeyedMap(item);
        if (row == null) continue;
        list.add(_StoreVersionInfo.fromJson(row));
      }
      _dbg('store-versions ok count=${list.length}');
      return list;
    } on DioException catch (e) {
      _dbg(
        'store-versions fetch failed: ${e.message} '
        'status=${e.response?.statusCode} data=${e.response?.data}',
      );
      return const [];
    } catch (e) {
      _dbg('store-versions unexpected: $e');
      return const [];
    }
  }

  Map<String, dynamic>? _asStringKeyedMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  Future<void> _performUpdate(BuildContext context) async {
    _dbg('performUpdate start platform=${Platform.operatingSystem}');
    if (Platform.isIOS) {
      _dbg('ios → open App Store only');
      _feedback(strings: sl<JsonStringsService>().text('appUpdateOpeningStore'));
      await _openExternalUrl(kAppStoreUrl);
      return;
    }

    if (!Platform.isAndroid) return;

    final strings = sl<JsonStringsService>();
    final target = await _resolveAndroidTargetStore();
    _dbg('performUpdate targetStore=$target (single store only)');

    _feedback(
      strings: strings.text('appUpdateTryingInApp'),
      kind: AppFeedbackKind.warning,
    );

    switch (target) {
      case _AndroidTargetStore.googlePlay:
        final playOk = await _tryPlayFlexibleUpdate(context);
        _dbg('playFlexibleOk=$playOk');
        if (playOk) {
          _dbg('performUpdate done via Play in-app');
          return;
        }
        _dbg('Play in-app failed → open Play Store URL only');
        _feedback(strings: strings.text('appUpdateOpeningStore'));
        await _openExternalUrl(kPlayStoreUrl);
        _dbg('performUpdate done via Play URL');
        return;

      case _AndroidTargetStore.rustore:
        final rustoreOk = await _tryRuStoreFlexibleUpdate(context);
        _dbg('rustoreFlexibleOk=$rustoreOk');
        if (rustoreOk) {
          _dbg('performUpdate done via RuStore in-app');
          return;
        }
        _dbg('RuStore in-app failed → open RuStore URL only');
        _feedback(strings: strings.text('appUpdateOpeningStore'));
        await _openExternalUrl(kRuStoreUrl);
        _dbg('performUpdate done via RuStore URL');
        return;
    }
  }

  /// Один стор: источник установки (если у него есть апдейт) → иначе где выше versionCode → иначе RuStore.
  Future<_AndroidTargetStore> _resolveAndroidTargetStore() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final localBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
    final stores = await _fetchStoreVersions();
    final playCode = _versionCodeOf(stores, 'google_play');
    final rustoreCode = _versionCodeOf(stores, 'rustore');
    final playHas = playCode != null && playCode > localBuild;
    final rustoreHas = rustoreCode != null && rustoreCode > localBuild;

    final source = await AppInstallSource.resolve();
    _dbg(
      'installSource kind=${source.kind.name} '
      'installer=${source.installerPackage} '
      'localBuild=$localBuild playCode=$playCode rustoreCode=$rustoreCode '
      'playHasUpdate=$playHas rustoreHasUpdate=$rustoreHas',
    );

    if (source.kind == AppInstallSourceKind.googlePlay && playHas) {
      _dbg('target=Play (install source + has update)');
      return _AndroidTargetStore.googlePlay;
    }
    if (source.kind == AppInstallSourceKind.rustore && rustoreHas) {
      _dbg('target=RuStore (install source + has update)');
      return _AndroidTargetStore.rustore;
    }

    if (playHas && rustoreHas) {
      if (playCode > rustoreCode) {
        _dbg('target=Play (higher versionCode than RuStore)');
        return _AndroidTargetStore.googlePlay;
      }
      if (rustoreCode > playCode) {
        _dbg('target=RuStore (higher versionCode than Play)');
        return _AndroidTargetStore.rustore;
      }
      _dbg('target=RuStore (same versionCode, default)');
      return _AndroidTargetStore.rustore;
    }
    if (playHas) {
      _dbg('target=Play (only Play has update)');
      return _AndroidTargetStore.googlePlay;
    }
    if (rustoreHas) {
      _dbg('target=RuStore (only RuStore has update)');
      return _AndroidTargetStore.rustore;
    }

    if (source.kind == AppInstallSourceKind.googlePlay) {
      _dbg('target=Play (no API delta, keep install source)');
      return _AndroidTargetStore.googlePlay;
    }
    _dbg('target=RuStore (default / unknown source)');
    return _AndroidTargetStore.rustore;
  }

  int? _versionCodeOf(List<_StoreVersionInfo> stores, String storeId) {
    for (final s in stores) {
      if (s.store == storeId && s.versionCode != null) return s.versionCode;
    }
    return null;
  }

  void _feedback({
    required String strings,
    AppFeedbackKind kind = AppFeedbackKind.warning,
  }) {
    try {
      sl<AppFeedbackService>().show(strings, kind: kind);
    } catch (e) {
      _dbg('feedback show failed: $e');
    }
  }

  Future<bool> _tryPlayFlexibleUpdate(BuildContext context) async {
    try {
      _dbg('Play checkForUpdate…');
      final info = await play_update.InAppUpdate.checkForUpdate();
      _dbg(
        'Play info availability=${info.updateAvailability} '
        'flexible=${info.flexibleUpdateAllowed} '
        'immediate=${info.immediateUpdateAllowed} '
        'updatePriority=${info.updatePriority}',
      );
      if (info.updateAvailability !=
          play_update.UpdateAvailability.updateAvailable) {
        _dbg('Play: update not available');
        return false;
      }
      if (info.flexibleUpdateAllowed != true) {
        _dbg('Play: flexible not allowed');
        return false;
      }

      _playInstallSub?.cancel();
      _playInstallSub = play_update.InAppUpdate.installUpdateListener.listen(
        (status) {
          _dbg('Play installStatus=$status');
          if (status == play_update.InstallStatus.downloaded) {
            unawaited(_completePlayFlexible(context));
          }
        },
        onError: (Object e) => _dbg('Play install listener error: $e'),
      );

      _dbg('Play startFlexibleUpdate…');
      final result = await play_update.InAppUpdate.startFlexibleUpdate();
      _dbg('Play startFlexibleUpdate result=$result');
      return result == play_update.AppUpdateResult.success;
    } catch (e) {
      _dbg('Play in-app update failed: $e');
      return false;
    }
  }

  Future<void> _completePlayFlexible(BuildContext context) async {
    _dbg('Play downloaded → ask install');
    final ctx = _dialogContext(context);
    if (ctx == null) {
      _dbg('Play complete: no dialog context');
      return;
    }
    final strings = sl<JsonStringsService>();
    final install = await showDialog<bool>(
      context: ctx,
      useRootNavigator: true,
      builder: (dialogCtx) => AlertDialog(
        title: Text(strings.text('appUpdateReadyTitle')),
        content: Text(strings.text('appUpdateReadyMessage')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(strings.text('appUpdateLater')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(strings.text('appUpdateInstallButton')),
          ),
        ],
      ),
    );
    _dbg('Play install dialog result=$install');
    if (install == true) {
      await play_update.InAppUpdate.completeFlexibleUpdate();
      _dbg('Play completeFlexibleUpdate called');
    }
  }

  /// `true` = in-app поток реально пошёл (скачивание/установка) или юзер отменил шит.
  /// `false` = нельзя / тишина / ошибка → нужен fallback в стор.
  Future<bool> _tryRuStoreFlexibleUpdate(BuildContext context) async {
    try {
      _dbg('RuStore info()…');
      final info = await rustore_update.RustoreUpdateClient.info();
      _dbg(
        'RuStore info avail=${info.updateAvailability}'
        '(${info.updateAvailabilityValue.name}) '
        'installStatus=${info.installStatus}'
        '(${info.installStatusValue.name}) '
        'availableVersionCode=${info.availableVersionCode} '
        'package=${info.packageName}',
      );

      // Пакет уже скачан — сразу установка, без download()/шита.
      if (info.installStatusValue == rustore_update.InstallStatus.downloaded) {
        _dbg('RuStore: already downloaded → complete flexible now');
        await _completeRuStoreFlexible(context);
        return true;
      }

      if (info.updateAvailabilityValue !=
              rustore_update.UpdateAvailability.available &&
          info.updateAvailabilityValue !=
              rustore_update.UpdateAvailability.inProgress) {
        _dbg('RuStore: update not available');
        return false;
      }

      final outcome = Completer<_RuStoreFlowOutcome>();
      var sawProgress = false;

      _rustoreStateSub?.cancel();
      _rustoreStateSub =
          rustore_update.RustoreUpdateClient.stateStream.listen(
        (state) {
          final status = state.installStatusValue;
          final err = state.installError;
          final progress = state.downloadProgress;
          _dbg(
            'RuStore state status=${state.installStatus}(${status.name}) '
            'errCode=${state.installErrorCode}(${err.name}) '
            'bytes=${state.bytesDownloaded}/${state.totalBytesToDownload} '
            'progress=$progress package=${state.packageName}',
          );

          if (status == rustore_update.InstallStatus.downloading ||
              status == rustore_update.InstallStatus.pending ||
              status == rustore_update.InstallStatus.installing) {
            sawProgress = true;
          }

          if (status == rustore_update.InstallStatus.downloaded) {
            sawProgress = true;
            if (!outcome.isCompleted) {
              outcome.complete(_RuStoreFlowOutcome.downloaded);
            }
            unawaited(_completeRuStoreFlexible(context));
          } else if (status == rustore_update.InstallStatus.failed) {
            if (!outcome.isCompleted) {
              outcome.complete(_RuStoreFlowOutcome.failed);
            }
          }
        },
        onError: (Object e, StackTrace st) {
          _dbg('RuStore stateStream error: $e');
          if (!outcome.isCompleted) {
            outcome.complete(_RuStoreFlowOutcome.failed);
          }
        },
      );

      _dbg('RuStore download() — ждём шит/подтверждение…');
      final download = await rustore_update.RustoreUpdateClient.download();
      _dbg(
        'RuStore download() returned code=${download.code} '
        '(OK=${rustore_update.ACTIVITY_RESULT_OK} '
        'CANCELED=${rustore_update.ACTIVITY_RESULT_CANCELED} '
        'NOT_FOUND=${rustore_update.ACTIVITY_RESULT_NOT_FOUND})',
      );

      if (download.code == rustore_update.ACTIVITY_RESULT_CANCELED) {
        _dbg('RuStore: user canceled sheet');
        _feedback(
          strings: sl<JsonStringsService>().text('appUpdateCanceled'),
          kind: AppFeedbackKind.warning,
        );
        return true;
      }
      if (download.code == rustore_update.ACTIVITY_RESULT_NOT_FOUND) {
        _dbg('RuStore: activity not found');
        return false;
      }

      _feedback(
        strings: sl<JsonStringsService>().text('appUpdateDownloading'),
        kind: AppFeedbackKind.success,
      );

      _dbg('RuStore: waiting stateStream (timeout 25s)…');
      final result = await Future.any<_RuStoreFlowOutcome>([
        outcome.future,
        Future<_RuStoreFlowOutcome>.delayed(
          const Duration(seconds: 25),
          () => _RuStoreFlowOutcome.timeout,
        ),
      ]);
      _dbg('RuStore wait result=$result sawProgress=$sawProgress');

      switch (result) {
        case _RuStoreFlowOutcome.downloaded:
          return true;
        case _RuStoreFlowOutcome.failed:
          return false;
        case _RuStoreFlowOutcome.timeout:
          if (sawProgress) {
            _dbg('RuStore: timeout but saw progress — считаем in-app живым');
            return true;
          }
          _dbg('RuStore: timeout without progress → fallback');
          return false;
      }
    } catch (e, st) {
      _dbg('RuStore in-app update failed: $e');
      AppLog.error(
        'RuStore in-app update failed',
        tag: 'AppUpdate',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  Future<void> _completeRuStoreFlexible(BuildContext context) async {
    _dbg('RuStore downloaded → ask install');
    final ctx = _dialogContext(context);
    if (ctx == null) {
      _dbg('RuStore complete: no dialog context');
      return;
    }
    final strings = sl<JsonStringsService>();
    final install = await showDialog<bool>(
      context: ctx,
      useRootNavigator: true,
      builder: (dialogCtx) => AlertDialog(
        title: Text(strings.text('appUpdateReadyTitle')),
        content: Text(strings.text('appUpdateReadyMessage')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(strings.text('appUpdateLater')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(strings.text('appUpdateInstallButton')),
          ),
        ],
      ),
    );
    _dbg('RuStore install dialog result=$install');
    if (install == true) {
      try {
        await rustore_update.RustoreUpdateClient.completeUpdateFlexible();
        _dbg('RuStore completeUpdateFlexible called');
      } catch (e) {
        _dbg('RuStore completeUpdateFlexible failed: $e');
      }
    }
  }

  Future<void> _openExternalUrl(String url) async {
    _dbg('openExternalUrl $url');
    final uri = Uri.parse(url);
    final ok = await canLaunchUrl(uri);
    _dbg('canLaunchUrl=$ok');
    if (ok) {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      _dbg('launchUrl result=$launched');
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

enum _AndroidTargetStore { googlePlay, rustore }

enum _RuStoreFlowOutcome { downloaded, failed, timeout }

final class _UpdateCheckResult {
  const _UpdateCheckResult({
    required this.needed,
    required this.localVersion,
    required this.storeVersion,
  });

  final bool needed;
  final String localVersion;
  final String storeVersion;
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
