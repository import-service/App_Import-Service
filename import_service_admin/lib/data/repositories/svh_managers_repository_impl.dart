import 'package:import_service_admin/data/datasources/remote/svh_managers_remote_data_source.dart';
import 'package:import_service_admin/domain/entities/svh_manager.dart';
import 'package:import_service_admin/domain/repositories/svh_managers_repository.dart';

class SvhManagersRepositoryImpl implements SvhManagersRepository {
  SvhManagersRepositoryImpl(this._remote);

  final SvhManagersRemoteDataSource _remote;

  @override
  Future<({List<SvhManager> items, int total})> list({
    int limit = 50,
    int offset = 0,
    bool includeDisabled = true,
  }) =>
      _remote.list(
        limit: limit,
        offset: offset,
        includeDisabled: includeDisabled,
      );

  @override
  Future<SvhManager> create({
    required String login,
    required String password,
    String? fullName,
    String? phone,
  }) =>
      _remote.create(
        login: login,
        password: password,
        fullName: fullName,
        phone: phone,
      );

  @override
  Future<SvhManager> update({
    required int id,
    String? password,
    String? fullName,
    String? phone,
    bool? active,
  }) =>
      _remote.update(
        id: id,
        password: password,
        fullName: fullName,
        phone: phone,
        active: active,
      );

  @override
  Future<void> delete(int id) => _remote.delete(id);
}
