import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:google_api_availability/google_api_availability.dart';
import 'package:import_service_app/core/logging/app_log.dart';
import 'package:import_service_app/core/push/request_remote_update.dart';
import 'package:import_service_app/firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    AppLog.trace(
      'push bg: message=${message.messageId ?? '-'}',
      tag: 'Push',
    );
  } catch (e, st) {
    AppLog.error(
      'push bg init failed',
      tag: 'Push',
      error: e,
      stackTrace: st,
    );
  }
}

enum PushOpenKind { requestDetail, requestChat }

final class PushOpenTarget {
  const PushOpenTarget({
    required this.requestId,
    required this.kind,
  });

  final String requestId;
  final PushOpenKind kind;
}

/// FCM: auto-init выключен в манифесте; getToken — после GMS + повторы.
final class PushNotificationsService {
  PushNotificationsService();

  static const _tokenRetryDelays = <Duration>[
    Duration(seconds: 3),
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 15),
    Duration(seconds: 30),
  ];

  bool _bootstrapped = false;
  bool _listenersStarted = false;
  bool _tokenFetchScheduled = false;
  bool _autoInitEnabled = false;
  final StreamController<PushOpenTarget> _requestOpenController =
      StreamController<PushOpenTarget>.broadcast();
  final StreamController<RequestRemoteUpdate> _requestUpdateController =
      StreamController<RequestRemoteUpdate>.broadcast();
  final StreamController<PushOpenTarget> _foregroundTargetController =
      StreamController<PushOpenTarget>.broadcast();
  final StreamController<String> _tokenRefreshController =
      StreamController<String>.broadcast();
  String? _currentToken;

  Stream<PushOpenTarget> get requestOpenStream => _requestOpenController.stream;
  Stream<RequestRemoteUpdate> get requestUpdateStream => _requestUpdateController.stream;
  Stream<PushOpenTarget> get foregroundTargetStream =>
      _foregroundTargetController.stream;
  Stream<String> get tokenRefreshStream => _tokenRefreshController.stream;
  String? get currentToken => _currentToken;
  String get platformName => Platform.isIOS ? 'ios' : 'android';

  /// Firebase + background handler. Без getToken и без auto-init.
  Future<bool> bootstrap() async {
    if (_bootstrapped) return true;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await FirebaseMessaging.instance.setAutoInitEnabled(false);
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      _bootstrapped = true;
      AppLog.trace('firebase bootstrap ok (auto-init off)', tag: 'Push');
      return true;
    } catch (e, st) {
      AppLog.error(
        'firebase bootstrap failed',
        tag: 'Push',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Слушатели + permission; getToken — отложенно с повторами.
  Future<void> initialize() async {
    if (!_bootstrapped) {
      final ok = await bootstrap();
      if (!ok) return;
    }
    if (_listenersStarted) {
      return;
    }

    final messaging = FirebaseMessaging.instance;

    try {
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      AppLog.trace(
        'permission=${settings.authorizationStatus.name}',
        tag: 'Push',
      );
    } catch (e, st) {
      AppLog.error(
        'push permission request failed',
        tag: 'Push',
        error: e,
        stackTrace: st,
      );
    }

    messaging.onTokenRefresh.listen((token) {
      _setToken(token, source: 'onTokenRefresh');
    });

    FirebaseMessaging.onMessage.listen((message) {
      AppLog.trace(
        'push fg: message=${message.messageId ?? '-'}'
        ' title=${message.notification?.title ?? ''}',
        tag: 'Push',
      );
      final update = _extractRemoteUpdate(message);
      if (update != null) {
        _requestUpdateController.add(update);
      }
      final target = _extractOpenTarget(message);
      if (target != null) {
        _foregroundTargetController.add(target);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      AppLog.trace(
        'push opened: message=${message.messageId ?? '-'}',
        tag: 'Push',
      );
      final update = _extractRemoteUpdate(message);
      if (update != null) {
        _requestUpdateController.add(update);
      }
      final target = _extractOpenTarget(message);
      if (target != null) {
        _requestOpenController.add(target);
      }
    });

    if (!kIsWeb) {
      try {
        final initialMessage = await messaging.getInitialMessage();
        if (initialMessage != null) {
          AppLog.trace(
            'push initial: message=${initialMessage.messageId ?? '-'}',
            tag: 'Push',
          );
          final update = _extractRemoteUpdate(initialMessage);
          if (update != null) {
            _requestUpdateController.add(update);
          }
          final target = _extractOpenTarget(initialMessage);
          if (target != null) {
            _requestOpenController.add(target);
          }
        }
      } catch (e, st) {
        AppLog.error(
          'getInitialMessage failed',
          tag: 'Push',
          error: e,
          stackTrace: st,
        );
      }
    }

    _listenersStarted = true;
  }

  void scheduleTokenFetch({required String reason}) {
    if (!_bootstrapped) return;
    if (_tokenFetchScheduled) return;
    _tokenFetchScheduled = true;
    AppLog.trace('token fetch scheduled: $reason', tag: 'Push');
    unawaited(_runTokenFetchLoop(reason));
  }

  Future<void> _runTokenFetchLoop(String reason) async {
    try {
      final token = await ensureFcmToken();
      if (token == null) {
        AppLog.error(
          'fcm getToken failed after ${_tokenRetryDelays.length} attempts ($reason). '
          'Проверьте: SHA-1 в Firebase Console, Google Play Services, доступ к googleapis.com.',
          tag: 'Push',
        );
      }
    } finally {
      _tokenFetchScheduled = false;
    }
  }

  Future<bool> _waitForGooglePlayServices() async {
    if (kIsWeb || !Platform.isAndroid) return true;

    const maxChecks = 20;
    final api = GoogleApiAvailability.instance;

    for (var i = 0; i < maxChecks; i++) {
      final status = await api.checkGooglePlayServicesAvailability();
      AppLog.trace(
        'GMS check ${i + 1}/$maxChecks: ${_gmsStatusLabel(status)}',
        tag: 'Push',
      );
      if (status == GooglePlayServicesAvailability.success) {
        return true;
      }
      if (status == GooglePlayServicesAvailability.serviceMissing ||
          status == GooglePlayServicesAvailability.serviceDisabled ||
          status == GooglePlayServicesAvailability.serviceInvalid) {
        AppLog.error(
          'Google Play Services недоступны: ${_gmsStatusLabel(status)}',
          tag: 'Push',
        );
        return false;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    AppLog.error(
      'Google Play Services не стали ready за ${maxChecks * 2}s',
      tag: 'Push',
    );
    return false;
  }

  static String _gmsStatusLabel(GooglePlayServicesAvailability status) {
    return status.toString();
  }

  Future<void> _enableFcmAutoInitOnce() async {
    if (_autoInitEnabled) return;
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    _autoInitEnabled = true;
    AppLog.trace('FCM auto-init enabled manually', tag: 'Push');
    // Дать GMS/FIS время подняться после auto-init.
    await Future<void>.delayed(const Duration(seconds: 2));
  }

  Future<String?> ensureFcmToken() async {
    if (!_bootstrapped) {
      final ok = await bootstrap();
      if (!ok) return null;
    }

    if (_currentToken != null && _currentToken!.isNotEmpty) {
      return _currentToken;
    }

    if (!await _waitForGooglePlayServices()) {
      return null;
    }

    await _enableFcmAutoInitOnce();

    final messaging = FirebaseMessaging.instance;
    Object? lastError;
    StackTrace? lastStack;

    for (var i = 0; i < _tokenRetryDelays.length; i++) {
      final delay = _tokenRetryDelays[i];
      if (delay > Duration.zero) {
        AppLog.trace(
          'getToken retry ${i + 1}/${_tokenRetryDelays.length} after ${delay.inSeconds}s',
          tag: 'Push',
        );
        await Future<void>.delayed(delay);
      }
      try {
        if (i > 0) {
          try {
            await messaging.deleteToken();
            AppLog.trace('deleteToken ok before retry ${i + 1}', tag: 'Push');
          } catch (e) {
            AppLog.trace('deleteToken skipped: $e', tag: 'Push');
          }
        }
        final token = await messaging.getToken();
        if (token != null && token.isNotEmpty) {
          _setToken(token, source: 'getToken attempt ${i + 1}');
          return token;
        }
        AppLog.trace('getToken returned empty on attempt ${i + 1}', tag: 'Push');
      } catch (e, st) {
        lastError = e;
        lastStack = st;
        AppLog.trace(
          'getToken attempt ${i + 1} failed: $e',
          tag: 'Push',
        );
      }
    }

    if (lastError != null) {
      AppLog.error(
        'ensureFcmToken exhausted retries',
        tag: 'Push',
        error: lastError,
        stackTrace: lastStack,
      );
    }
    return null;
  }

  void _setToken(String token, {required String source}) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return;
    final changed = _currentToken != trimmed;
    _currentToken = trimmed;
    AppLog.trace('fcm token ($source): ${trimmed.substring(0, 8)}…', tag: 'Push');
    // tokenRefreshStream — только нативный refresh; getToken иначе дублирует POST push/tokens.
    if (changed && source == 'onTokenRefresh') {
      _tokenRefreshController.add(trimmed);
    }
  }

  RequestRemoteUpdate? _extractRemoteUpdate(RemoteMessage message) {
    final data = message.data;
    final requestId = _readRequestId(data);
    if (requestId == null) return null;
    final type = (data['type']?.trim().toLowerCase() ?? '');
    final event = (data['event']?.trim().toLowerCase() ?? '');
    final isFiles = type == 'request_files_update' || event == 'request_files_update';
    final rawChanged = data['changedDocTypes'] ?? data['changed_doc_types'];
    final changed = _parseChangedDocTypes(rawChanged);
    return RequestRemoteUpdate(
      requestId: requestId,
      isFilesUpdate: isFiles,
      changedDocTypes: changed,
      status: data['status']?.toString().trim(),
      statusSubType: data['statusSubType']?.toString().trim() ??
          data['status_sub_type']?.toString().trim(),
      previousStatus: data['previousStatus']?.toString().trim() ??
          data['previous_status']?.toString().trim(),
      changeSummary: data['changeSummary']?.toString().trim() ??
          data['change_summary']?.toString().trim(),
    );
  }

  static List<String> _parseChangedDocTypes(Object? raw) {
    if (raw is String && raw.trim().isNotEmpty) {
      return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    if (raw is List) {
      return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  static String? _readRequestId(Map<String, dynamic> data) {
    final candidates = <String?>[
      data['requestId'],
      data['request_id'],
      data['id'],
    ];
    for (final candidate in candidates) {
      final value = candidate?.trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  PushOpenTarget? _extractOpenTarget(RemoteMessage message) {
    final data = message.data;
    final requestId = _readRequestId(data);
    if (requestId == null) return null;
    final type = (data['type']?.trim().toLowerCase() ?? '');
    final event = (data['event']?.trim().toLowerCase() ?? '');
    final action = (data['action']?.trim().toLowerCase() ?? '');
    final openChat = type == 'new_message' ||
        type == 'chat_message' ||
        event == 'new_message' ||
        event == 'chat_message' ||
        action == 'open_chat';
    return PushOpenTarget(
      requestId: requestId,
      kind: openChat ? PushOpenKind.requestChat : PushOpenKind.requestDetail,
    );
  }

  Future<void> dispose() async {
    await _requestOpenController.close();
    await _requestUpdateController.close();
    await _foregroundTargetController.close();
    await _tokenRefreshController.close();
  }
}
