import 'package:import_service_admin/data/datasources/mock/mock_json_loader.dart';
import 'package:import_service_admin/domain/entities/customs_request_summary.dart';

class CustomsRequestsMockDataSource {
  CustomsRequestsMockDataSource(this._loader);

  final MockJsonLoader _loader;

  static const _listAsset = 'assets/mocks/customs_requests_list.json';

  Future<List<CustomsRequestSummary>> listRequests() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final json = await _loader.loadMap(_listAsset);
    final items = json['items'];
    if (items is! List) return const [];

    return items
        .whereType<Map<String, dynamic>>()
        .map(
          (e) => CustomsRequestSummary(
            id: e['id']?.toString() ?? '',
            ownerFullName: e['ownerFullName'] as String? ?? '',
            carMake: e['carMake'] as String? ?? '',
            carModel: e['carModel'] as String? ?? '',
            vin: e['vin'] as String? ?? '',
            status: e['status'] as String? ?? 'new',
            statusSinceDateLabel: e['statusSinceDateLabel'] as String?,
            isTest: e['isTest'] == true,
            managerFullName: e['managerFullName'] as String?,
          ),
        )
        .toList(growable: false);
  }
}
