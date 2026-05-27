import 'package:import_service_admin/domain/entities/organization.dart';

abstract class OrganizationsRepository {
  Future<({List<Organization> items, int total})> list({
    int limit,
    int offset,
    String? query,
    bool includeDeleted,
  });

  Future<Organization> getById(int id);
}
