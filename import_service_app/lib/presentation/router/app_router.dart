import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:import_service_app/core/auth/auth_session_controller.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/app_locale.dart';
import 'package:import_service_app/presentation/pages/car_request_detail_page.dart';
import 'package:import_service_app/presentation/pages/request_chat_page.dart';
import 'package:import_service_app/presentation/pages/home_page.dart';
import 'package:import_service_app/presentation/pages/login_page.dart';

/// Корневой роутер. Новые маршруты добавляй в [routes].
final GoRouter appRouter = GoRouter(
  refreshListenable: Listenable.merge([appLocale, sl<AuthSessionController>()]),
  initialLocation: '/login',
  redirect: (context, state) {
    final loggedIn = sl<AuthSessionController>().hasActiveSession;
    final isLogin = state.uri.path == '/login';

    if (!loggedIn && !isLogin) return '/login';
    if (loggedIn && isLogin) return '/home';
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (BuildContext context, GoRouterState state) {
        return const LoginPage();
      },
    ),
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (BuildContext context, GoRouterState state) {
        return const HomePage();
      },
    ),
    GoRoute(
      path: '/request/:id/chat',
      name: 'requestChat',
      builder: (BuildContext context, GoRouterState state) {
        final id = state.pathParameters['id'] ?? '';
        return RequestChatPage(requestId: id);
      },
    ),
    GoRoute(
      path: '/request/:id',
      name: 'requestDetail',
      builder: (BuildContext context, GoRouterState state) {
        final id = state.pathParameters['id'] ?? '';
        final focusDocs = state.uri.queryParameters['focus'] == 'docs';
        return CarRequestDetailPage(
          requestId: id,
          focusDocumentsOnOpen: focusDocs,
        );
      },
    ),
  ],
);
