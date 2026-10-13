import 'dart:convert';

import 'package:import_service_app/core/auth/auth_storage_keys.dart';
import 'package:import_service_app/core/auth/qa_known_accounts.dart';
import 'package:import_service_app/core/auth/recent_account.dart';
import 'package:import_service_app/core/storage/secure_storage_service.dart';

/// История входов на устройстве (secure storage). Без лимита, новые сверху.
class RecentAccountsService {
  RecentAccountsService(this._secureStorage);

  final SecureStorageService _secureStorage;

  Future<List<RecentAccount>> list() async {
    final stored = await _readStored();
    final merged = _mergeQaSeeds(stored);
    if (!_sameAccounts(stored, merged)) {
      await _writeAll(merged);
    }
    return merged;
  }

  Future<List<RecentAccount>> _readStored() async {
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
      return items;
    } catch (_) {
      return const <RecentAccount>[];
    }
  }

  /// QA-сиды всегда в списке; пароль/роль сида обновляем, дату входа сохраняем.
  List<RecentAccount> _mergeQaSeeds(List<RecentAccount> stored) {
    final byEmail = <String, RecentAccount>{
      for (final a in stored) a.email: a,
    };
    for (final seed in QaKnownAccounts.seeds) {
      final existing = byEmail[seed.email];
      if (existing == null) {
        byEmail[seed.email] = seed;
        continue;
      }
      if (existing.password != seed.password || existing.role != seed.role) {
        byEmail[seed.email] = RecentAccount(
          email: seed.email,
          password: seed.password,
          role: seed.role,
          lastLoginAt: existing.lastLoginAt,
        );
      }
    }
    final items = byEmail.values.toList()
      ..sort((a, b) => b.lastLoginAt.compareTo(a.lastLoginAt));
    return items;
  }

  bool _sameAccounts(List<RecentAccount> a, List<RecentAccount> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].email != b[i].email ||
          a[i].password != b[i].password ||
          a[i].role != b[i].role ||
          a[i].lastLoginAt != b[i].lastLoginAt) {
        return false;
      }
    }
    return true;
  }

  Future<void> _writeAll(List<RecentAccount> items) async {
    await _secureStorage.write(
      AuthStorageKeys.recentAccounts,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
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
    await _writeAll(next);
  }
}
