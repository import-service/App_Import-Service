import 'dart:convert';

import 'package:import_service_app/core/auth/auth_storage_keys.dart';
import 'package:import_service_app/core/auth/recent_account.dart';
import 'package:import_service_app/core/storage/secure_storage_service.dart';

/// История входов на устройстве (secure storage). Без лимита, новые сверху.
class RecentAccountsService {
  RecentAccountsService(this._secureStorage);

  final SecureStorageService _secureStorage;

  Future<List<RecentAccount>> list() async {
    final raw = await _secureStorage.read(AuthStorageKeys.recentAccounts);
    if (raw == null || raw.trim().isEmpty) return const <RecentAccount>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <RecentAccount>[];
      final items = <RecentAccount>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final account = RecentAccount.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (account.email.isEmpty || account.password.isEmpty) continue;
        items.add(account);
      }
      items.sort((a, b) => b.lastLoginAt.compareTo(a.lastLoginAt));
      return items;
    } catch (_) {
      return const <RecentAccount>[];
    }
  }

  /// Upsert по email (lowercase): обновляет пароль/роль и дату входа.
  Future<void> upsert({
    required String email,
    required String password,
    required String role,
  }) async {
    final normalized = email.trim().toLowerCase();
    final pwd = password;
    if (normalized.isEmpty || pwd.isEmpty) return;

    final now = DateTime.now().toUtc();
    final current = await list();
    final next = <RecentAccount>[
      RecentAccount(
        email: normalized,
        password: pwd,
        role: role.trim().isEmpty ? 'user' : role.trim(),
        lastLoginAt: now,
      ),
      ...current.where((a) => a.email != normalized),
    ];
    await _secureStorage.write(
      AuthStorageKeys.recentAccounts,
      jsonEncode(next.map((e) => e.toJson()).toList()),
    );
  }
}
