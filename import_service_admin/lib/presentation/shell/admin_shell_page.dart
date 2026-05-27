import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:import_service_admin/core/auth/auth_service.dart';
import 'package:import_service_admin/core/auth/auth_session_controller.dart';
import 'package:import_service_admin/core/di/injection_container.dart';
import 'package:import_service_admin/core/theme/app_theme.dart';

class AdminShellPage extends StatelessWidget {
  const AdminShellPage({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = <({IconData icon, String label})>[
    (icon: Icons.dashboard_outlined, label: 'Дашборд'),
    (icon: Icons.assignment_outlined, label: 'Заявки'),
    (icon: Icons.business_outlined, label: 'Организации'),
    (icon: Icons.settings_outlined, label: '1С'),
  ];

  Future<void> _logout(BuildContext context) async {
    await sl<AuthService>().logout();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final session = sl<AuthSessionController>();
    final width = MediaQuery.sizeOf(context).width;
    final useRail = width >= 800;

    return Scaffold(
      appBar: AppBar(
        title: Text(_destinations[navigationShell.currentIndex].label),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Text(
                session.login ?? '',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Выйти',
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Row(
        children: [
          if (useRail)
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: navigationShell.goBranch,
              labelType: NavigationRailLabelType.all,
              backgroundColor: Colors.white,
              selectedIconTheme: const IconThemeData(color: AppTheme.primaryBlue),
              selectedLabelTextStyle: const TextStyle(
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.icon),
                    label: Text(d.label),
                  ),
              ],
            ),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: useRail
          ? null
          : NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: navigationShell.goBranch,
              destinations: [
                for (final d in _destinations)
                  NavigationDestination(icon: Icon(d.icon), label: d.label),
              ],
            ),
    );
  }
}
