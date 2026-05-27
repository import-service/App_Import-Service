import 'package:import_service_admin/core/constants/app_config.dart';
import 'package:import_service_admin/data/datasources/mock/customs_requests_mock_data_source.dart';
import 'package:import_service_admin/data/datasources/remote/customs_requests_remote_data_source.dart';
import 'package:import_service_admin/domain/entities/customs_request_summary.dart';
import 'package:import_service_admin/domain/repositories/customs_requests_repository.dart';

class CustomsRequestsRepositoryImpl implements CustomsRequestsRepository {
  CustomsRequestsRepositoryImpl({
    required CustomsRequestsRemoteDataSource remote,
    required CustomsRequestsMockDataSource mock,
  })  : _remote = remote,
        _mock = mock;

  final CustomsRequestsRemoteDataSource _remote;
  final CustomsRequestsMockDataSource _mock;

  @override
  Future<({List<CustomsRequestSummary> items, int total})> listRequests({
    int limit = 100,
    int offset = 0,
    String? status,
  }) async {
    if (AppConfig.useMockApi) {
      final items = await _mock.listRequests();
      final sorted = [...items]
        ..sort((a, b) {
          if (a.status == 'new' && b.status != 'new') return -1;
          if (a.status != 'new' && b.status == 'new') return 1;
          if (a.oneCUpdatePending && !b.oneCUpdatePending) return -1;
          if (!a.oneCUpdatePending && b.oneCUpdatePending) return 1;
          return b.id.compareTo(a.id);
        });
      return (items: sorted, total: sorted.length);
    }
    return _remote.listRequests(limit: limit, offset: offset, status: status);
  }

  @override
  Future<CustomsRequestSummary> resendTo1C(String id) {
    if (AppConfig.useMockApi) {
      throw UnsupportedError('resendTo1C недоступен в режиме моков');
    }
    return _remote.resendTo1C(id);
  }

  @override
  Future<CustomsRequestSummary> resendUpdateTo1C(String id) {
    if (AppConfig.useMockApi) {
      throw UnsupportedError('resendUpdateTo1C недоступен в режиме моков');
    }
    return _remote.resendUpdateTo1C(id);
  }
}
