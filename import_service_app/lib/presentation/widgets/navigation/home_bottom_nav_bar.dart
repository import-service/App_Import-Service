import 'package:flutter/material.dart';
import 'package:import_service_app/core/themes/app_theme.dart';

class HomeBottomNavBar extends StatelessWidget {
  const HomeBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.carsLabel,
    required this.chatsLabel,
    required this.profileLabel,
    required this.hasChatsUnread,
    required this.onTap,
  });

  final int currentIndex;
  final String carsLabel;
  final String chatsLabel;
  final String profileLabel;
  final bool hasChatsUnread;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Theme(
      data: Theme.of(context).copyWith(
        navigationBarTheme: NavigationBarThemeData(
          indicatorColor: AppTheme.primaryBlue,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final base = Theme.of(context).textTheme.labelMedium;
            if (states.contains(WidgetState.selected)) {
              return base?.copyWith(
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.w600,
              );
            }
            return base;
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: AppTheme.white, size: 24);
            }
            return IconThemeData(color: scheme.onSurfaceVariant, size: 24);
          }),
        ),
      ),
      child: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onTap,
        indicatorColor: AppTheme.primaryBlue,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.directions_car_outlined),
            selectedIcon: const Icon(Icons.directions_car),
            label: carsLabel,
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: hasChatsUnread,
              smallSize: 8,
              backgroundColor: AppTheme.accentRed,
              child: const Icon(Icons.chat_bubble_outline),
            ),
            selectedIcon: Badge(
              isLabelVisible: hasChatsUnread,
              smallSize: 8,
              backgroundColor: AppTheme.accentRed,
              child: const Icon(Icons.chat_bubble),
            ),
            label: chatsLabel,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: profileLabel,
          ),
        ],
      ),
    );
  }
}
