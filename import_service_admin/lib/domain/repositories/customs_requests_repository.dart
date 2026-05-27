import 'package:import_service_admin/domain/entities/customs_request_summary.dart';

abstract class CustomsRequestsRepository {
  Future<({List<CustomsRequestSummary> items, int total})> listRequests({
    int limit,
    int offset,
    String? status,
  });

  Future<CustomsRequestSummary> resendTo1C(String id);

  Future<CustomsRequestSummary> resendUpdateTo1C(String id);
}
