import 'package:import_service_admin/domain/entities/customs_request.dart';

abstract class CustomsRequestsRepository {
  Future<({List<CustomsRequest> items, int total})> listRequests({
    int limit,
    int offset,
    String? status,
    bool? hasRating,
    int? ratingMax,
  });

  Future<CustomsRequest> getRequest(String id);

  Future<CustomsRequest> resendTo1C(String id);

  Future<CustomsRequest> resendUpdateTo1C(String id);

  /// ZIP фото машины (СВХ) для скачивания.
  Future<({List<int> bytes, String filename})> downloadSvhCarPhotosZip(String id);

  /// Пересобрать ZIP и отправить в 1С.
  Future<void> sendSvhCarPhotosZipTo1C(String id);

  /// ZIP архива транзита для скачивания.
  Future<({List<int> bytes, String filename})> downloadTransitArchivePhotosZip(
    String id,
  );

  /// Пересобрать ZIP архива транзита и отправить в 1С.
  Future<void> sendTransitArchivePhotosZipTo1C(String id);
}
