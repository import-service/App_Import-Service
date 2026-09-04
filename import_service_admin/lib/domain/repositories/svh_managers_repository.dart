import 'package:import_service_admin/domain/entities/svh_manager.dart';

abstract class SvhManagersRepository {
  Future<({List<SvhManager> items, int total})> list({
    int limit = 50,
    int offset = 0,
    bool includeDisabled = true,
  });

  Future<SvhManager> create({
    required String login,
    required String password,
    String? fullName,
    String? phone,
  });

  Future<SvhManager> update({
    required int id,
    String? password,
    String? fullName,
    String? phone,
    bool? active,
  });

  Future<void> delete(int id);
}
