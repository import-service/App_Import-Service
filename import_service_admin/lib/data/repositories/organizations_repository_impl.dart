import 'package:import_service_admin/data/datasources/remote/organizations_remote_data_source.dart';
import 'package:import_service_admin/domain/entities/organization.dart';
import 'package:import_service_admin/domain/repositories/organizations_repository.dart';

class OrganizationsRepositoryImpl implements OrganizationsRepository {
  OrganizationsRepositoryImpl(this._remote);

  final OrganizationsRemoteDataSource _remote;

  @override
  Future<({List<Organization> items, int total})> list({
    int limit = 50,
    int offset = 0,
    String? query,
    bool includeDeleted = false,
  }) =>
      _remote.list(
        limit: limit,
        offset: offset,
        query: query,
        includeDeleted: includeDeleted,
      );

  @override
  Future<Organization> getById(int id) => _remote.getById(id);
}
