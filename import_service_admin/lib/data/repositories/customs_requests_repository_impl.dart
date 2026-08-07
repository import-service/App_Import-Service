import 'package:import_service_admin/core/constants/app_config.dart';
import 'package:import_service_admin/data/datasources/mock/customs_requests_mock_data_source.dart';
import 'package:import_service_admin/data/datasources/remote/customs_requests_remote_data_source.dart';
import 'package:import_service_admin/domain/entities/customs_request.dart';
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
  Future<({List<CustomsRequest> items, int total})> listRequests({
    int limit = 100,
    int offset = 0,
    String? status,
    bool? hasRating,
    int? ratingMax,
  }) async {
    if (AppConfig.useMockApi) {
      var items = await _mock.listRequests();
      if (hasRating == true) {
        items = items.where((e) => e.clientRating != null).toList();
      }
      if (ratingMax != null) {
        items = items
            .where(
              (e) => e.clientRating != null && e.clientRating! <= ratingMax,
            )
            .toList();
      }
      if (status != null && status.isNotEmpty) {
        items = items.where((e) => e.status == status).toList();
      }
      final sorted = [...items]
        ..sort((a, b) {
          if (hasRating == true) {
            final at = a.clientRatedAt ?? '';
            final bt = b.clientRatedAt ?? '';
            final cmp = bt.compareTo(at);
            if (cmp != 0) return cmp;
            return b.id.compareTo(a.id);
          }
          if (a.status == 'new' && b.status != 'new') return -1;
          if (a.status != 'new' && b.status == 'new') return 1;
          if (a.oneCUpdatePending && !b.oneCUpdatePending) return -1;
          if (!a.oneCUpdatePending && b.oneCUpdatePending) return 1;
          return b.id.compareTo(a.id);
        });
      return (items: sorted, total: sorted.length);
    }
    return _remote.listRequests(
      limit: limit,
      offset: offset,
      status: status,
      hasRating: hasRating,
      ratingMax: ratingMax,
    );
  }

  @override
  Future<CustomsRequest> getRequest(String id) {
    if (AppConfig.useMockApi) {
      return _mock.getRequest(id);
    }
    return _remote.getRequest(id);
  }

  @override
  Future<CustomsRequest> resendTo1C(String id) {
    if (AppConfig.useMockApi) {
      throw UnsupportedError('resendTo1C недоступен в режиме моков');
    }
    return _remote.resendTo1C(id);
  }

  @override
  Future<CustomsRequest> resendUpdateTo1C(String id) {
    if (AppConfig.useMockApi) {
      throw UnsupportedError('resendUpdateTo1C недоступен в режиме моков');
    }
    return _remote.resendUpdateTo1C(id);
  }
}
