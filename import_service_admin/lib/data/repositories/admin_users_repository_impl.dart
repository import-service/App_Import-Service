import 'package:import_service_admin/data/datasources/remote/admin_users_remote_data_source.dart';
import 'package:import_service_admin/domain/entities/admin_user.dart';
import 'package:import_service_admin/domain/repositories/admin_users_repository.dart';

class AdminUsersRepositoryImpl implements AdminUsersRepository {
  AdminUsersRepositoryImpl(this._remote);

  final AdminUsersRemoteDataSource _remote;

  @override
  Future<({List<AdminUser> items, int total})> list({
    int limit = 50,
    int offset = 0,
  }) =>
      _remote.list(limit: limit, offset: offset);

  @override
  Future<AdminUser> create({
    required String login,
    required String password,
  }) =>
      _remote.create(login: login, password: password);

  @override
  Future<void> delete(int id) => _remote.delete(id);
}
