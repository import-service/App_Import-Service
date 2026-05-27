import 'package:import_service_admin/domain/entities/customs_request.dart';

abstract class CustomsRequestsRepository {
  Future<({List<CustomsRequest> items, int total})> listRequests({
    int limit,
    int offset,
    String? status,
  });

  Future<CustomsRequest> getRequest(String id);

  Future<CustomsRequest> resendTo1C(String id);

  Future<CustomsRequest> resendUpdateTo1C(String id);
}
