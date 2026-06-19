import 'dart:io';

import 'package:dio/dio.dart';
import 'package:import_service_app/core/error/error_handler.dart';
import 'package:import_service_app/core/error/exceptions.dart';
import 'package:import_service_app/core/logging/app_log.dart';
import 'package:import_service_app/data/models/customs_request_upload_result.dart';
import 'package:import_service_app/domain/entities/request_file_upload_entry.dart';
import 'package:import_service_app/domain/entities/request_files_batch_upload_result.dart';
import 'package:import_service_app/data/models/request_form_model.dart';
import 'package:import_service_app/data/models/registration_request_model.dart';
import 'package:import_service_app/domain/entities/car_list_item.dart';
import 'package:import_service_app/domain/entities/request_status.dart';

final class CustomsRequestsRemoteDataSource {
  CustomsRequestsRemoteDataSource(this._dio);

  final Dio _dio;

  /// [api-app.md]: `GET /api/customs-requests?limit=&offset=&status=`
  Future<List<CarListItem>> listRequests({
    int? limit,
    int? offset,
    String? status,
  }) async {
    try {
      final q = <String, dynamic>{};
      if (limit != null) {
        q['limit'] = limit;
      }
      if (offset != null) {
        q['offset'] = offset;
      }
      if (status != null && status.isNotEmpty) {
        q['status'] = status;
      }
      final response = await _dio.get<dynamic>(
        'customs-requests',
        queryParameters: q.isEmpty ? null : q,
      );
      final data = response.data;
      final rawList = _extractList(data);
      return rawList.map(_toCarListItem).toList(growable: false);
    } on DioException catch (e, st) {
      final mapped = ErrorHandler.handle(e);
      AppLog.error(
        'Requests list failed: /api/customs-requests',
        tag: 'CustomsRequestsRemoteDataSource',
        error: e,
        stackTrace: st,
      );
      throw mapped;
    } on ServerException {
      rethrow;
    } catch (e, st) {
      AppLog.error(
        'Unexpected requests list failure',
        tag: 'CustomsRequestsRemoteDataSource',
        error: e,
        stackTrace: st,
      );
      throw const UnknownServerException('Не удалось получить заявки');
    }
  }

  /// Список файлов комплекта create из формы (первый путь на каждый docType).
  static List<RequestFileUploadEntry> fileEntriesFromForm(RequestFormModel form) {
    final sources = <({String docType, List<String> paths})>[
      (docType: 'passport_front', paths: form.passportFrontPaths),
      (docType: 'passport_registration', paths: form.passportAddressPaths),
      (docType: 'inn', paths: form.innPaths),
      (docType: 'snils', paths: form.snilsPaths),
      (docType: 'invoice', paths: form.invoicePaths),
      (docType: 'contract', paths: form.contractPaths),
      (docType: 'payment_check', paths: form.paymentReceiptPaths),
      (docType: 'car_nameplate_photo', paths: form.vinPlatePhotoPaths),
      (docType: 'car_mileage_photo', paths: form.odometerPhotoPaths),
      (docType: 'car_front_photo', paths: form.carFrontPhotoPaths),
      (docType: 'car_back_photo', paths: form.carRearPhotoPaths),
      (docType: 'add_doc1', paths: form.additionalFile1Paths),
      (docType: 'add_doc2', paths: form.additionalFile2Paths),
    ];
    final expanded = <RequestFileUploadEntry>[];
    for (final bucket in sources) {
      for (final p in bucket.paths) {
        final trimmed = p.trim();
        if (trimmed.isEmpty) continue;
        if (_looksLikeUrl(trimmed)) continue;
        expanded.add((docType: bucket.docType, localPath: trimmed));
        break;
      }
    }
    return expanded;
  }

  /// `POST /customs-requests` без `files`, затем батч upload (contract-files-v2).
  Future<CreateRequestResult> createRequestWithFiles(
    RequestFormModel form, {
    void Function(int done, int total)? onUploadProgress,
  }) async {
    try {
      AppLog.trace('create: POST without files', tag: 'CreateReq');
      final payload = _buildCreateFormPayload(form);
      final response = await _dio.post<dynamic>('customs-requests', data: payload);
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const UnknownServerException('Invalid customs request response format');
      }
      final created = _toCarListItem(data);
      final requestId = created.id.trim();
      if (requestId.isEmpty) {
        throw const UnknownServerException('Create response has no request id');
      }

      final entries = fileEntriesFromForm(form);
      if (entries.isEmpty) {
        AppLog.trace('create: no local files to upload', tag: 'CreateReq');
        return CreateRequestResult(item: created);
      }

      final batch = await uploadRequestFilesBatch(
        requestId: requestId,
        items: entries,
        onProgress: onUploadProgress,
      );
      AppLog.trace(
        'create: uploads done failed=${batch.failedDocTypes.length}',
        tag: 'CreateReq',
      );
      return CreateRequestResult(
        item: batch.item,
        failedDocTypes: batch.failedDocTypes,
      );
    } on DioException catch (e, st) {
      final mapped = ErrorHandler.handle(e);
      AppLog.error(
        'Request create failed',
        tag: 'CustomsRequestsRemoteDataSource',
        error: e,
        stackTrace: st,
      );
      throw mapped;
    } on ServerException {
      rethrow;
    } catch (e, st) {
      AppLog.error(
        'Unexpected request create failure',
        tag: 'CustomsRequestsRemoteDataSource',
        error: e,
        stackTrace: st,
      );
      throw const UnknownServerException('Не удалось создать заявку');
    }
  }

  /// Совместимость: возвращает заявку даже при частичном upload (см. [failedDocTypes] в логах).
  Future<CarListItem> createRequest(
    RequestFormModel form, {
    void Function(int done, int total)? onUploadProgress,
  }) async {
    final result = await createRequestWithFiles(
      form,
      onUploadProgress: onUploadProgress,
    );
    return result.item;
  }

  static List<Map<String, dynamic>> _extractList(dynamic data) {
    if (data is List<dynamic>) {
      return data.whereType<Map<String, dynamic>>().toList(growable: false);
    }
    if (data is Map<String, dynamic>) {
      final candidates = <String>['items', 'data', 'results', 'rows'];
      for (final key in candidates) {
        final value = data[key];
        if (value is List<dynamic>) {
          return value.whereType<Map<String, dynamic>>().toList(growable: false);
        }
      }
    }
    return const <Map<String, dynamic>>[];
  }

  /// [contract-files-v2.md]: `GET /api/customs-requests/:id`
  Future<CarListItem> getRequestById(String id) async {
    final path = 'customs-requests/${Uri.encodeComponent(id)}';
    try {
      final response = await _dio.get<dynamic>(path);
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const UnknownServerException('Invalid customs request detail');
      }
      return _toCarListItem(data);
    } on DioException catch (e, st) {
      final mapped = ErrorHandler.handle(e);
      AppLog.error(
        'Request detail failed: $path',
        tag: 'CustomsRequestsRemoteDataSource',
        error: e,
        stackTrace: st,
      );
      throw mapped;
    } on ServerException {
      rethrow;
    } catch (e, st) {
      AppLog.error(
        'Unexpected request detail failure',
        tag: 'CustomsRequestsRemoteDataSource',
        error: e,
        stackTrace: st,
      );
      throw const UnknownServerException('Не удалось загрузить заявку');
    }
  }

  static CarListItem _toCarListItem(Map<String, dynamic> json) {
    final make = (json['carMake'] as String?)?.trim() ?? '';
    final cModel = (json['carModel'] as String?)?.trim() ?? '';
    final v1 = (json['vin'] as String?)?.trim() ?? '';
    final v2 = (json['vinFull'] as String?)?.trim() ?? '';
    final legacy = (json['vinMasked'] as String?)?.trim() ?? '';
    final mergedVin = v1.isNotEmpty
        ? v1
        : (v2.isNotEmpty
            ? v2
            : legacy);
    final owner = (json['ownerFullName'] as String?)?.trim().isNotEmpty == true
        ? (json['ownerFullName'] as String).trim()
        : ((json['individualFullName'] as String?)?.trim() ?? '—');
    final merged = <String, dynamic>{
      ...json,
      'id': (json['id'] ?? '').toString(),
      'ownerFullName': owner,
      'carMake': make,
      'carModel': cModel,
      'vin': mergedVin,
      'status': (json['status'] as String?) ?? RequestStatus.newRequest.apiValue,
    };
    return CarListItem.fromJson(merged);
  }

  static Map<String, dynamic> _buildCreateFormPayload(RequestFormModel form) {
    return <String, dynamic>{
      'orgType': form.organizationType == OrganizationType.ip ? 'IP' : 'OOO',
      'legalEntityName': form.companyName.trim(),
      'inn': form.companyInn.trim(),
      'legalInn': form.companyInn.trim(),
      'legalEmail': form.companyEmail.trim(),
      'legalPhone': form.companyPhone.trim(),
      'individualFullName': form.personFullName.trim(),
      'individualPhone': form.personPhone.trim(),
      'individualSnils': form.personSnils.trim(),
      'carMake': form.carBrand.trim(),
      'carModel': form.carModel.trim(),
      'vin': form.vin.trim(),
      'hasSunroof': form.hasSunroof,
      'hasAllWheelDrive': form.hasAllWheelDrive,
      'importedLast12Months': form.wasInRussiaLast12Months,
      'ownsOtherCars': form.hasOtherCars,
      'commentText': form.comment.trim(),
      'isTest': form.isTest,
    };
  }

  /// Один файл v2: `POST /api/customs-requests/upload`.
  Future<CustomsRequestUploadResponse> uploadRequestFile({
    required String requestId,
    required String docType,
    required String localPath,
    required int uploadIndex,
    required int uploadTotal,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw UnknownServerException('Файл не найден: $localPath');
    }
    final fileName = _fileName(localPath);
    try {
      final form = FormData.fromMap(<String, dynamic>{
        'requestId': requestId,
        'docType': docType,
        'uploadIndex': uploadIndex,
        'uploadTotal': uploadTotal,
        'file': await MultipartFile.fromFile(localPath, filename: fileName),
      });
      AppLog.trace(
        'upload $uploadIndex/$uploadTotal docType=$docType requestId=$requestId',
        tag: 'UploadV2',
      );
      final response = await _dio.post<dynamic>(
        'customs-requests/upload',
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      );
      return _parseUploadResponse(response.data);
    } on DioException catch (e, st) {
      final mapped = ErrorHandler.handle(e);
      AppLog.error(
        'Upload failed docType=$docType',
        tag: 'UploadV2',
        error: e,
        stackTrace: st,
      );
      throw mapped;
    }
  }

  Future<CarListItem> _getRequestByIdWithRetry(
    String id, {
    int attempts = 3,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        return await getRequestById(id);
      } catch (e, st) {
        lastError = e;
        AppLog.trace(
          'detail refresh attempt ${attempt + 1}/$attempts failed',
          tag: 'UploadV2',
        );
        if (attempt < attempts - 1) {
          await Future<void>.delayed(
            Duration(milliseconds: 400 * (attempt + 1)),
          );
        } else {
          AppLog.error(
            'detail refresh failed after upload',
            tag: 'UploadV2',
            error: e,
            stackTrace: st,
          );
        }
      }
    }
    if (lastError is ServerException) throw lastError;
    throw const UnknownServerException('Не удалось загрузить заявку');
  }

  /// Батч upload: при ошибке одного файла — в [failedDocTypes], остальные продолжаем.
  Future<RequestFilesBatchUploadResult> uploadRequestFilesBatch({
    required String requestId,
    required List<RequestFileUploadEntry> items,
    void Function(int done, int total)? onProgress,
  }) async {
    if (items.isEmpty) {
      final item = await getRequestById(requestId);
      return RequestFilesBatchUploadResult(item: item);
    }

    final total = items.length;
    var done = 0;
    onProgress?.call(0, total);

    final failed = <String>[];
    CarListItem? latest;

    for (var i = 0; i < items.length; i++) {
      final entry = items[i];
      final index = i + 1;
      try {
        final upload = await uploadRequestFile(
          requestId: requestId,
          docType: entry.docType,
          localPath: entry.localPath,
          uploadIndex: index,
          uploadTotal: total,
        );
        AppLog.trace(
          'upload ok=${upload.ok} batchComplete=${upload.batchComplete}',
          tag: 'UploadV2',
        );
        if (!upload.ok) {
          failed.add(entry.docType);
          continue;
        }
        try {
          latest = await _getRequestByIdWithRetry(requestId);
        } on ServerException {
          // Upload принят сервером — не считаем ошибкой загрузки файла.
        }
      } on ServerException catch (e) {
        AppLog.error(
          'upload skip docType=${entry.docType}: ${e.message}',
          tag: 'UploadV2',
        );
        failed.add(entry.docType);
        if (latest == null) {
          try {
            latest = await getRequestById(requestId);
          } catch (_) {
            // оставим latest null
          }
        }
      } catch (e, st) {
        AppLog.error(
          'upload skip docType=${entry.docType}',
          tag: 'UploadV2',
          error: e,
          stackTrace: st,
        );
        failed.add(entry.docType);
      }
      done += 1;
      onProgress?.call(done, total);
    }

    latest ??= await _getRequestByIdWithRetry(requestId);
    return RequestFilesBatchUploadResult(
      item: latest,
      failedDocTypes: failed,
    );
  }

  /// Подпись / чек: upload 1/1 + GET (вместо устаревшего `POST …/:id/files`).
  Future<CarListItem> attachRequestFiles({
    required String requestId,
    required List<RequestFileUploadEntry> items,
  }) async {
    if (items.isEmpty) {
      throw const UnknownServerException('Нет файлов для прикрепления');
    }
    final batch = await uploadRequestFilesBatch(
      requestId: requestId,
      items: items,
    );
    if (batch.failedDocTypes.isNotEmpty) {
      throw UnknownServerException(
        'Не удалось загрузить: ${batch.failedDocTypes.join(', ')}',
      );
    }
    return batch.item;
  }

  static CustomsRequestUploadResponse _parseUploadResponse(dynamic data) {
    if (data is! Map<String, dynamic>) {
      throw const UnknownServerException('Invalid upload response format');
    }
    final ok = data['ok'] == true;
    final batchComplete = data['batchComplete'] == true;
    final nested = data['file'];
    if (nested is Map<String, dynamic>) {
      return CustomsRequestUploadResponse(
        ok: ok,
        batchComplete: batchComplete,
        docType: nested['docType'] as String?,
        fileUrl: nested['fileUrl'] as String?,
        mimeType: nested['mimeType'] as String?,
        fileSizeBytes: nested['fileSizeBytes'] is int
            ? nested['fileSizeBytes'] as int
            : int.tryParse('${nested['fileSizeBytes']}'),
        replaced: nested['replaced'] == true,
      );
    }
    return CustomsRequestUploadResponse(
      ok: ok,
      batchComplete: batchComplete,
      fileUrl: _extractUploadedFileUrl(data),
    );
  }

  static String? _extractUploadedFileUrl(dynamic data) {
    if (data is Map<String, dynamic>) {
      final direct = data['fileUrl'] ?? data['url'];
      if (direct is String && direct.trim().isNotEmpty) return direct.trim();
      final nested = data['file'] ?? data['data'] ?? data['item'] ?? data['result'];
      if (nested is Map<String, dynamic>) {
        final v = nested['fileUrl'] ?? nested['url'];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
    }
    return null;
  }

  static bool _looksLikeUrl(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }

  static String _fileName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final idx = normalized.lastIndexOf('/');
    return idx >= 0 ? normalized.substring(idx + 1) : normalized;
  }

}
