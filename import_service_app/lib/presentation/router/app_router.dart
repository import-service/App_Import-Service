import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:import_service_app/core/auth/auth_session_controller.dart';
import 'package:import_service_app/core/auth/session_role.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/app_locale.dart';
import 'package:import_service_app/domain/entities/chat_list_item.dart';
import 'package:import_service_app/presentation/pages/car_request_detail_page.dart';
import 'package:import_service_app/presentation/pages/declarant_home_page.dart';
import 'package:import_service_app/presentation/pages/request_chat_page.dart';
import 'package:import_service_app/presentation/pages/home_page.dart';
import 'package:import_service_app/presentation/pages/login_page.dart';
import 'package:import_service_app/presentation/pages/svh_home_page.dart';

/// Корневой роутер. Новые маршруты добавляй в [routes].
final GoRouter appRouter = GoRouter(
  refreshListenable: Listenable.merge([appLocale, sl<AuthSessionController>()]),
  initialLocation: '/login',
  redirect: (context, state) {
    final session = sl<AuthSessionController>();
    final loggedIn = session.hasActiveSession;
    final path = state.uri.path;
    final isLogin = path == '/login';

    if (!loggedIn && !isLogin) return '/login';
    if (loggedIn && isLogin) return homeLocationForSession(session);

    final home = homeLocationForSession(session);
    final isSvh = isSvhManagerSession(session);
    final isDeclarant = isDeclarantManagerSession(session);
    final isStaff = isCatalogStaffSession(session);

    // Неверный shell → домой по роли.
    if (loggedIn && path == '/home' && isStaff) return home;
    if (loggedIn && path == '/svh-home' && !isSvh) return home;
    if (loggedIn && path == '/declarant-home' && !isDeclarant) return home;

    if (loggedIn && !isSvh && path.startsWith('/svh-request/')) {
      return home;
    }
    // СВХ не открывает клиентскую карточку (кроме чатов).
    if (loggedIn &&
        isSvh &&
        path.startsWith('/request/') &&
        !path.endsWith('/chat') &&
        !path.contains('/chat') &&
        !path.contains('/svh-chat')) {
      return '/svh-home';
    }
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
      path: '/svh-home',
      name: 'svhHome',
      builder: (BuildContext context, GoRouterState state) {
        return const SvhHomePage();
      },
    ),
    GoRoute(
      path: '/declarant-home',
      name: 'declarantHome',
      builder: (BuildContext context, GoRouterState state) {
        return const DeclarantHomePage();
      },
    ),
    GoRoute(
      path: '/svh-request/:id',
      name: 'svhRequestDetail',
      builder: (BuildContext context, GoRouterState state) {
        final id = state.pathParameters['id'] ?? '';
        return CarRequestDetailPage(requestId: id);
      },
    ),
    GoRoute(
      path: '/org/chat',
      name: 'orgChat',
      builder: (BuildContext context, GoRouterState state) {
        return const RequestChatPage(
          requestId: ChatListItem.orgChatId,
          isOrgChat: true,
        );
      },
    ),
    GoRoute(
      path: '/request/:id/svh-chat',
      name: 'svhRequestChat',
      builder: (BuildContext context, GoRouterState state) {
        final id = state.pathParameters['id'] ?? '';
        final mid = state.uri.queryParameters['svhManagerId'];
        return RequestChatPage(
          requestId: id,
          isSvhChat: true,
          svhManagerId: mid,
        );
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
