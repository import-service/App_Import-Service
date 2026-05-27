import 'package:import_service_admin/data/datasources/mock/mock_json_loader.dart';
import 'package:import_service_admin/data/models/customs_request_mapper.dart';
import 'package:import_service_admin/domain/entities/customs_request.dart';

class CustomsRequestsMockDataSource {
  CustomsRequestsMockDataSource(this._loader);

  final MockJsonLoader _loader;

  static const _listAsset = 'assets/mocks/customs_requests_list.json';

  Future<List<CustomsRequest>> listRequests() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final json = await _loader.loadMap(_listAsset);
    final items = json['items'];
    if (items is! List) return const [];

    return items
        .whereType<Map<String, dynamic>>()
        .map(CustomsRequestMapper.fromJson)
        .toList(growable: false);
  }

  Future<CustomsRequest> getRequest(String id) async {
    final list = await listRequests();
    return list.firstWhere(
      (e) => e.id == id,
      orElse: () => throw StateError('Заявка $id не найдена в моках'),
    );
  }
}
