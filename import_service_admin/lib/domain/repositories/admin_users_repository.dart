import 'package:import_service_admin/domain/entities/admin_user.dart';

abstract class AdminUsersRepository {
  Future<({List<AdminUser> items, int total})> list({
    int limit = 50,
    int offset = 0,
  });

  Future<AdminUser> create({
    required String login,
    required String password,
  });

  Future<void> delete(int id);
}
