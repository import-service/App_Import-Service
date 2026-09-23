import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:google_api_availability/google_api_availability.dart';
import 'package:import_service_app/core/logging/app_log.dart';
import 'package:import_service_app/core/push/push_ios_diagnostics.dart';
import 'package:import_service_app/core/push/request_remote_update.dart';
import 'package:import_service_app/domain/entities/chat_list_item.dart';
import 'package:import_service_app/firebase_options.dart';

void _pushDiag(String message) {
  if (!kIsWeb && Platform.isIOS) {
    PushIosDiagnostics.log(message);
  } else {
    AppLog.trace(message, tag: 'Push');
  }
}

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

enum PushOpenKind { requestDetail, requestChat, orgChat, svhChat }

final class PushOpenTarget {
  const PushOpenTarget({
    required this.requestId,
    required this.kind,
    this.svhManagerId,
  });

  final String requestId;
  final PushOpenKind kind;
  final String? svhManagerId;
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
      _pushDiag('firebase bootstrap ok (auto-init off) platform=$platformName');
      return true;
    } catch (e, st) {
      _pushDiag('firebase bootstrap FAILED: $e');
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
      _pushDiag(
        'permission=${settings.authorizationStatus.name} '
        'alert=${settings.alert.name} badge=${settings.badge.name} '
        'sound=${settings.sound.name}',
      );
    } catch (e, st) {
      _pushDiag('permission request FAILED: $e');
      AppLog.error(
        'push permission request failed',
        tag: 'Push',
        error: e,
        stackTrace: st,
      );
    }

    if (!kIsWeb && Platform.isIOS) {
      try {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
        _pushDiag('foreground presentation options set (alert/badge/sound)');
      } catch (e, st) {
        _pushDiag('foreground presentation FAILED: $e');
        AppLog.error(
          'iOS foreground presentation failed',
          tag: 'Push',
          error: e,
          stackTrace: st,
        );
      }
    }

    messaging.onTokenRefresh.listen((token) {
      _pushDiag('onTokenRefresh len=${token.length}');
      _setToken(token, source: 'onTokenRefresh');
    });

    FirebaseMessaging.onMessage.listen((message) {
      _pushDiag(
        'FG message id=${message.messageId ?? '-'} '
        'title=${message.notification?.title ?? '-'} '
        'dataType=${message.data['type'] ?? '-'}',
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
      _pushDiag(
        'OPENED from notification id=${message.messageId ?? '-'} '
        'dataType=${message.data['type'] ?? '-'}',
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

  Future<bool> _waitForApnsToken(FirebaseMessaging messaging) async {
    const attempts = 8;
    for (var i = 0; i < attempts; i++) {
      try {
        final apns = await messaging.getAPNSToken();
        if (apns != null && apns.isNotEmpty) {
          _pushDiag('APNs token OK len=${apns.length} attempt ${i + 1}');
          return true;
        }
        _pushDiag('APNs token empty attempt ${i + 1}/$attempts');
      } catch (e) {
        _pushDiag('APNs getAPNSToken failed attempt ${i + 1}: $e');
      }
      await Future<void>.delayed(Duration(seconds: i == 0 ? 1 : 2));
    }
    return false;
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

    if (!kIsWeb && Platform.isIOS) {
      final apnsOk = await _waitForApnsToken(messaging);
      if (!apnsOk) {
        _pushDiag('APNs MISSING — FCM getToken likely to fail');
        AppLog.error(
          'APNs token not available — FCM getToken likely to fail on iOS',
          tag: 'Push',
        );
      }
    }

    Object? lastError;
    StackTrace? lastStack;

    for (var i = 0; i < _tokenRetryDelays.length; i++) {
      final delay = _tokenRetryDelays[i];
      if (delay > Duration.zero) {
        _pushDiag(
          'getToken retry ${i + 1}/${_tokenRetryDelays.length} after ${delay.inSeconds}s',
        );
        await Future<void>.delayed(delay);
      }
      try {
        if (i > 0) {
          try {
            await messaging.deleteToken();
            _pushDiag('deleteToken ok before retry ${i + 1}');
          } catch (e) {
            _pushDiag('deleteToken skipped: $e');
          }
        }
        final token = await messaging.getToken();
        if (token != null && token.isNotEmpty) {
          _pushDiag(
            'FCM token OK len=${token.length} attempt ${i + 1} '
            'prefix=${token.substring(0, token.length < 12 ? token.length : 12)}…',
          );
          _setToken(token, source: 'getToken attempt ${i + 1}');
          return token;
        }
        _pushDiag('getToken returned empty on attempt ${i + 1}');
      } catch (e, st) {
        lastError = e;
        lastStack = st;
        _pushDiag('getToken attempt ${i + 1} FAILED: $e');
      }
    }

    if (lastError != null) {
      _pushDiag('ensureFcmToken EXHAUSTED: $lastError');
      AppLog.error(
        'ensureFcmToken exhausted retries',
        tag: 'Push',
        error: lastError,
        stackTrace: lastStack,
      );
    } else {
      _pushDiag('ensureFcmToken EXHAUSTED: empty token, no exception');
    }
    return null;
  }

  void _setToken(String token, {required String source}) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return;
    final changed = _currentToken != trimmed;
    _currentToken = trimmed;
    _pushDiag('fcm token ($source): ${trimmed.substring(0, 8)}…');
    // tokenRefreshStream — только нативный refresh; getToken иначе дублирует POST push/tokens.
    if (changed && source == 'onTokenRefresh') {
      _tokenRefreshController.add(trimmed);
    }
  }

  RequestRemoteUpdate? _extractRemoteUpdate(RemoteMessage message) {
    final data = message.data;
    if (_isOrgChatPushData(data)) return null;
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

  bool _isOrgChatPushData(Map<String, dynamic> data) {
    final type = (data['type']?.trim().toLowerCase() ?? '');
    final event = (data['event']?.trim().toLowerCase() ?? '');
    final chatKind = (data['chatKind']?.trim().toLowerCase() ??
        data['chat_kind']?.trim().toLowerCase() ??
        '');
    if (type == 'new_org_message' ||
        event == 'new_org_message' ||
        chatKind == 'org') {
      return true;
    }
    return _readRequestId(data) == ChatListItem.orgChatId;
  }

  PushOpenTarget? _extractOpenTarget(RemoteMessage message) {
    final data = message.data;
    final type = (data['type']?.trim().toLowerCase() ?? '');
    final event = (data['event']?.trim().toLowerCase() ?? '');
    final action = (data['action']?.trim().toLowerCase() ?? '');
    final chatKind = (data['chatKind']?.trim().toLowerCase() ??
        data['chat_kind']?.trim().toLowerCase() ??
        '');
    if (_isOrgChatPushData(data)) {
      return const PushOpenTarget(
        requestId: ChatListItem.orgChatId,
        kind: PushOpenKind.orgChat,
      );
    }
    final requestId = _readRequestId(data);
    if (requestId == null) return null;
    final svhManagerId = (data['svhManagerId'] ?? data['svh_manager_id'])
        ?.toString()
        .trim();
    if (type == 'new_svh_message' ||
        event == 'new_svh_message' ||
        chatKind == 'svh') {
      return PushOpenTarget(
        requestId: requestId,
        kind: PushOpenKind.svhChat,
        svhManagerId: (svhManagerId != null && svhManagerId.isNotEmpty)
            ? svhManagerId
            : null,
      );
    }
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
