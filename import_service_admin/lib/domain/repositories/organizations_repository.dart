import 'package:import_service_admin/domain/entities/organization.dart';

abstract class OrganizationsRepository {
  Future<({List<Organization> items, int total})> list({
    int limit,
    int offset,
    String? query,
    bool includeDeleted,
    bool onlyDeleted,
  });

  Future<Organization> getById(int id);

  Future<Organization> updateRoles(int id, List<String> roles);

  Future<void> delete(int id);

  Future<void> restore(int id);
}
