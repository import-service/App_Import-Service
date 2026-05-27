import 'package:go_router/go_router.dart';
import 'package:import_service_admin/core/auth/auth_session_controller.dart';
import 'package:import_service_admin/core/di/injection_container.dart';
import 'package:import_service_admin/presentation/pages/dashboard_page.dart';
import 'package:import_service_admin/presentation/pages/login_page.dart';
import 'package:import_service_admin/presentation/pages/organizations_page.dart';
import 'package:import_service_admin/presentation/pages/requests_page.dart';
import 'package:import_service_admin/presentation/pages/settings_one_c_page.dart';
import 'package:import_service_admin/presentation/shell/admin_shell_page.dart';

final GoRouter appRouter = GoRouter(
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
              path: '/settings',
              builder: (context, state) => const SettingsOneCPage(),
            ),
          ],
        ),
      ],
    ),
  ],
);
