import 'package:import_service_admin/domain/entities/svh_manager.dart';

class SvhManagerMutationResult {
  const SvhManagerMutationResult({
    required this.item,
    required this.emailSent,
  });

  final SvhManager item;
  final bool emailSent;
}

abstract class SvhManagersRepository {
  Future<({List<SvhManager> items, int total})> list({
    int limit = 50,
    int offset = 0,
    bool includeDisabled = true,
  });

  Future<SvhManager> getById(int id);

  Future<SvhManagerMutationResult> create({
    required String login,
    required String password,
    String? fullName,
    String? phone,
  });

  Future<SvhManagerMutationResult> update({
    required int id,
    String? login,
    String? password,
    String? fullName,
    String? phone,
    bool? active,
  });

  Future<void> delete(int id);
}
