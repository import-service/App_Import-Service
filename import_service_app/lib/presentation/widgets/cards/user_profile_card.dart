import 'package:flutter/material.dart';
import 'package:import_service_app/core/themes/app_theme.dart';

class UserProfileCard extends StatelessWidget {
  const UserProfileCard({
    super.key,
    required this.titleLogin,
    required this.titleRole,
    required this.login,
    required this.role,
  });

  final String titleLogin;
  final String titleRole;
  final String login;
  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$titleLogin: $login'),
          const SizedBox(height: 6),
          Text('$titleRole: $role'),
        ],
      ),
    );
  }
}
