import 'package:import_service_admin/data/datasources/remote/admin_settings_remote_data_source.dart';
import 'package:import_service_admin/domain/entities/one_c_settings.dart';
import 'package:import_service_admin/domain/repositories/admin_settings_repository.dart';

class AdminSettingsRepositoryImpl implements AdminSettingsRepository {
  AdminSettingsRepositoryImpl(this._remote);

  final AdminSettingsRemoteDataSource _remote;

  @override
  Future<OneCSettings> getOneCRequestCreate() => _remote.getOneCRequestCreate();

  @override
  Future<OneCSettings> updateOneCRequestCreate({
    required String url,
    required String bearerToken,
  }) =>
      _remote.updateOneCRequestCreate(url: url, bearerToken: bearerToken);
}
