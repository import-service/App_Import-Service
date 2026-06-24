import 'package:go_router/go_router.dart';
import 'package:import_service_admin/core/auth/auth_session_controller.dart';
import 'package:import_service_admin/core/di/injection_container.dart';
import 'package:import_service_admin/core/navigation/router_keys.dart';
import 'package:import_service_admin/presentation/pages/dashboard_page.dart';
import 'package:import_service_admin/presentation/pages/login_page.dart';
import 'package:import_service_admin/presentation/pages/organizations_page.dart';
import 'package:import_service_admin/presentation/pages/request_detail_page.dart';
import 'package:import_service_admin/presentation/pages/requests_page.dart';
import 'package:import_service_admin/presentation/pages/settings_one_c_page.dart';
import 'package:import_service_admin/presentation/pages/storage_page.dart';
import 'package:import_service_admin/presentation/shell/admin_shell_page.dart';

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  refreshListenable: sl<AuthSessionController>(),
  initialLocation: '/login',
  redirect: (context, state) {
    final path = state.uri.path;
    if (path == '/home') return '/dashboard';

    final loggedIn = sl<AuthSessionController>().isAuthenticated;
    final isLogin = path == '/login';

    if (!loggedIn && !isLogin) return '/login';
    if (loggedIn && isLogin) return '/dashboard';
    return null;
  },
  routes: [
    GoRoute(
      path: '/home',
      redirect: (context, state) => '/dashboard',
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AdminShellPage(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/requests',
              builder: (context, state) => const RequestsPage(),
              routes: [
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) => RequestDetailPage(
                    requestId: state.pathParameters['id']!,
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/organizations',
              builder: (context, state) => const OrganizationsPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/storage',
              builder: (context, state) => const StoragePage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsOneCPage(),
            ),
          ],
        ),
      ],
    ),
  ],
);
