import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:import_service_app/core/app_update/app_update_bootstrap.dart';
import 'package:import_service_app/core/auth/auth_session_controller.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/app_locale.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/logging/app_log.dart';
import 'package:import_service_app/core/logging/bootstrap_logger.dart';
import 'package:import_service_app/core/logging/client_error_reporter.dart';
import 'package:import_service_app/core/push/chat_screen_presence.dart';
import 'package:import_service_app/core/push/push_notifications_service.dart';
import 'package:import_service_app/core/push/push_request_handler.dart';
import 'package:import_service_app/core/push/request_remote_update.dart';
import 'package:import_service_app/core/auth/auth_service.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/core/themes/app_theme_mode.dart';
import 'package:import_service_app/core/ui/app_feedback_kind.dart';
import 'package:import_service_app/core/ui/app_feedback_service.dart';
import 'package:import_service_app/core/ui/app_phone_width_scope.dart';
import 'package:import_service_app/core/ui/app_scaffold_messenger_key.dart';
import 'package:import_service_app/presentation/bloc/request_attention/request_attention_cubit.dart';
import 'package:import_service_app/presentation/bloc/chat_list/chat_list_cubit.dart';
import 'package:import_service_app/presentation/bloc/request_chat_unread/request_chat_unread_cubit.dart';
import 'package:import_service_app/presentation/router/app_router.dart';
import 'package:import_service_app/presentation/widgets/bottom_sheets/chat_push_go_bottom_sheet.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    bootstrapLogger();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      final reporter = ClientErrorReporter.instance;
      if (reporter != null) {
        unawaited(
          reporter.report(
            message: details.exceptionAsString(),
            stack: details.stack?.toString(),
            tag: 'FlutterError',
            fatal: true,
          ),
        );
      }
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      final reporter = ClientErrorReporter.instance;
      if (reporter != null) {
        unawaited(
          reporter.report(
            message: error.toString(),
            stack: stack.toString(),
            tag: 'PlatformDispatcher',
            fatal: true,
          ),
        );
      }
      return true;
    };

    await initDependencies();
    AppUpdateBootstrap.ensureWired();
    await initializeDateFormatting('ru');
    await initializeDateFormatting('zh');

    // Firebase до runApp — без getToken (GMS на cold start часто ещё не готов).
    await sl<PushNotificationsService>().bootstrap();

    runApp(const MyApp());

    // Push после первого кадра: меньше гонки с Secure Storage / вторым engine FCM.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_startPushAfterUi());
    });
  }, (error, stack) {
    // AppLog.error → ClientErrorReporter через remoteErrorSink.
    AppLog.error(
      'uncaught zone error',
      tag: 'Zone',
      error: error,
      stackTrace: stack,
    );
  });
}

Future<void> _startPushAfterUi() async {
  try {
    await sl<PushNotificationsService>().initialize();
    if (sl<AuthSessionController>().isAuthenticated) {
      await sl<AuthService>().registerPushTokenIfNeeded();
    }
  } catch (e, st) {
    AppLog.error(
      'push start after UI failed',
      tag: 'Push',
      error: e,
      stackTrace: st,
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<PushOpenTarget>? _pushTapSub;
  StreamSubscription<RequestRemoteUpdate>? _pushUpdateSub;
  StreamSubscription<PushOpenTarget>? _pushForegroundSub;

  @override
  void initState() {
    super.initState();
    _pushTapSub = sl<PushNotificationsService>().requestOpenStream.listen((
      target,
    ) {
      final encodedId = Uri.encodeComponent(target.requestId);
      if (target.kind == PushOpenKind.orgChat) {
        sl<RequestChatUnreadCubit>().clearUnread(target.requestId);
        appRouter.push('/org/chat');
      } else if (target.kind == PushOpenKind.svhChat) {
        final mid = target.svhManagerId?.trim();
        final key = 'svh:${target.requestId}:${mid ?? ''}';
        sl<RequestChatUnreadCubit>().clearUnread(key);
        final q = (mid != null && mid.isNotEmpty) ? '?svhManagerId=$mid' : '';
        appRouter.push('/request/$encodedId/svh-chat$q');
      } else if (target.kind == PushOpenKind.requestChat) {
        sl<RequestChatUnreadCubit>().clearUnread(target.requestId);
        appRouter.push('/request/$encodedId/chat');
      } else {
        unawaited(prepareCarsTabBeforeDetailOpen(target.requestId));
        appRouter.push('/request/$encodedId');
      }
    });
    _pushUpdateSub = sl<PushNotificationsService>().requestUpdateStream.listen((
      update,
    ) {
      unawaited(handleRequestRemoteUpdate(update));
    });
    _pushForegroundSub = sl<PushNotificationsService>().foregroundTargetStream
        .listen((target) {
          if (target.kind == PushOpenKind.orgChat ||
              target.kind == PushOpenKind.requestChat ||
              target.kind == PushOpenKind.svhChat) {
            if (target.kind == PushOpenKind.orgChat) {
              unawaited(handleOrgChatRemoteUpdate());
            } else {
              unawaited(sl<ChatListCubit>().load());
            }
            final presenceKey = target.kind == PushOpenKind.svhChat
                ? 'svh:${target.requestId}:${target.svhManagerId ?? ''}'
                : target.requestId;
            if (sl<ChatScreenPresence>().isOpen(presenceKey)) {
              sl<ChatScreenPresence>().notifyLiveUpdate(presenceKey);
              return;
            }
            sl<RequestChatUnreadCubit>().markUnread(presenceKey);
            unawaited(_showChatPushGo(target));
          } else {
            sl<RequestAttentionCubit>().markStatusUpdated(target.requestId);
            sl<AppFeedbackService>().show(
              sl<JsonStringsService>().pushToastRequestUpdated,
              kind: AppFeedbackKind.warning,
            );
          }
        });
  }

  Future<void> _showChatPushGo(PushOpenTarget target) async {
    final ctx = appRouter.routerDelegate.navigatorKey.currentContext ??
        appScaffoldMessengerKey.currentContext;
    if (ctx == null || !ctx.mounted) {
      sl<AppFeedbackService>().show(
        sl<JsonStringsService>().pushToastNewMessage,
        kind: AppFeedbackKind.success,
      );
      return;
    }
    final go = await ChatPushGoBottomSheet.show(ctx);
    if (go == true) {
      final unreadKey = target.kind == PushOpenKind.svhChat
          ? 'svh:${target.requestId}:${target.svhManagerId ?? ''}'
          : target.requestId;
      sl<RequestChatUnreadCubit>().clearUnread(unreadKey);
      if (target.kind == PushOpenKind.orgChat) {
        appRouter.push('/org/chat');
      } else if (target.kind == PushOpenKind.svhChat) {
        final encodedId = Uri.encodeComponent(target.requestId);
        final mid = target.svhManagerId?.trim();
        final q = (mid != null && mid.isNotEmpty) ? '?svhManagerId=$mid' : '';
        appRouter.push('/request/$encodedId/svh-chat$q');
      } else {
        final encodedId = Uri.encodeComponent(target.requestId);
        appRouter.push('/request/$encodedId/chat');
      }
    }
  }

  @override
  void dispose() {
    _pushTapSub?.cancel();
    _pushUpdateSub?.cancel();
    _pushForegroundSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: appLocale,
      builder: (context, locale, _) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: appThemeMode,
          builder: (context, themeMode, _) {
            return MaterialApp.router(
              scaffoldMessengerKey: appScaffoldMessengerKey,
              builder: (context, child) {
                AppTheme.bindBrightness(Theme.of(context).brightness);
                return AppPhoneWidthScope(
                  child: child ?? const SizedBox.shrink(),
                );
              },
              onGenerateTitle: (_) => sl<JsonStringsService>().appTitle,
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: themeMode,
              locale: locale,
              localeResolutionCallback: (locale, supportedLocales) {
                if (locale == null) {
                  return const Locale('ru');
                }
                for (final supported in supportedLocales) {
                  if (supported.languageCode == locale.languageCode) {
                    return supported;
                  }
                }
                return const Locale('ru');
              },
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('ru'), Locale('zh')],
              routerConfig: appRouter,
            );
          },
        );
      },
    );
  }
}
