import 'package:import_service_admin/domain/entities/one_c_settings.dart';

abstract class AdminSettingsRepository {
  Future<OneCSettings> getOneCRequestCreate();

  Future<OneCSettings> updateOneCRequestCreate({
    required String url,
    required String bearerToken,
    String? updateUrl,
  });
}
