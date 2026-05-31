import 'package:dartz/dartz.dart';
import 'package:import_service_app/core/error/failures.dart';
import 'package:import_service_app/data/models/request_form_model.dart';
import 'package:import_service_app/domain/entities/car_list_item.dart';
import 'package:import_service_app/domain/entities/create_vehicle_result.dart';
import 'package:import_service_app/domain/entities/request_file_upload_entry.dart';
import 'package:import_service_app/domain/entities/request_files_batch_upload_result.dart';

/// Список заявок и создание заявки.
abstract class CarsRepository {
  /// [api-app.md]: `GET /api/customs-requests` с опциями `limit` / `offset` / `status`.
  Future<Either<Failure, List<CarListItem>>> listVehicles({
    int? limit,
    int? offset,
    String? status,
  });

  /// Полная заявка по id; вне демо — `GET /api/customs-requests/:id`, результат сохраняется в локальном store.
  Future<Either<Failure, CarListItem>> getVehicle(String id);

  Future<Either<Failure, CreateVehicleResult>> createVehicle(
    RequestFormModel form, {
    void Function(int done, int total)? onUploadProgress,
  });

  /// Список локальных файлов из формы (для дозагрузки по [docType]).
  List<RequestFileUploadEntry> fileUploadEntriesFromForm(
    RequestFormModel form, {
    Set<String>? onlyDocTypes,
  });

  /// Дозагрузка файлов на существующую заявку (тот же батч v2).
  Future<Either<Failure, RequestFilesBatchUploadResult>> retryPendingUploads({
    required String requestId,
    required List<RequestFileUploadEntry> items,
    void Function(int done, int total)? onUploadProgress,
  });

  /// Демо: подгрузить моковые заявки «как с бэка» и сохранить в локальный store.
  Future<Either<Failure, void>> bootstrapDemoRequests();

  /// Upload v2: подпись (`*_sign`), чек оплаты и т.д.
  Future<Either<Failure, CarListItem>> attachRequestFile({
    required String requestId,
    required String docType,
    required String localFilePath,
  });
}
