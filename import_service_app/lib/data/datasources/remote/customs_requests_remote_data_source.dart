import 'dart:io';

import 'package:dio/dio.dart';
import 'package:import_service_app/core/error/error_handler.dart';
import 'package:import_service_app/core/error/exceptions.dart';
import 'package:import_service_app/core/logging/app_log.dart';
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

  Future<CarListItem> createRequest(
    RequestFormModel form, {
    void Function(int done, int total)? onUploadProgress,
  }) async {
    try {
      final payload = await _buildCreatePayload(
        form,
        onUploadProgress: onUploadProgress,
      );
      final response = await _dio.post<dynamic>('customs-requests', data: payload);
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const UnknownServerException('Invalid customs request response format');
      }
      return _toCarListItem(data);
    } on DioException catch (e, st) {
      final mapped = ErrorHandler.handle(e);
      AppLog.error(
        'Request create failed: /api/customs-requests',
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

  /// [api-app.md]: `GET /api/customs-requests/:id` (полный объект, `files`, слив `vehiclePhotoUrls`).
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

  Future<Map<String, dynamic>> _buildCreatePayload(
    RequestFormModel form, {
    void Function(int done, int total)? onUploadProgress,
  }) async {
    final files = <Map<String, dynamic>>[];
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
    final expanded = <({String docType, String source})>[];
    for (final bucket in sources) {
      for (final p in bucket.paths) {
        final trimmed = p.trim();
        if (trimmed.isEmpty) continue;
        expanded.add((docType: bucket.docType, source: trimmed));
      }
    }
    final total = expanded.length;
    var done = 0;
    if (total > 0) {
      onUploadProgress?.call(0, total);
    }
    for (final e in expanded) {
      final item = await _buildFileEntry(docType: e.docType, source: e.source);
      done += 1;
      onUploadProgress?.call(done, total);
      if (item != null) files.add(item);
    }

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
      'files': files,
    };
  }

  Future<Map<String, dynamic>?> _buildFileEntry({
    required String docType,
    required String source,
  }) async {
    if (_looksLikeUrl(source)) {
      return <String, dynamic>{
        'docType': docType,
        'fileName': _fileName(source),
        'mimeType': _mimeByExtension(_extension(source)),
        'fileUrl': source,
      };
    }
    final file = File(source);
    if (!await file.exists()) return null;
    final ext = _extension(source);
    final fileUrl = await _uploadFileAndGetUrl(
      filePath: source,
      fileName: _fileName(source),
      mimeType: _mimeByExtension(ext),
    );
    return <String, dynamic>{
      'docType': docType,
      'fileName': _fileName(source),
      'mimeType': _mimeByExtension(ext),
      'fileUrl': fileUrl,
    };
  }

  Future<String> _uploadFileAndGetUrl({
    required String filePath,
    required String fileName,
    required String mimeType,
  }) async {
    final form = FormData.fromMap(<String, dynamic>{
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final response = await _dio.post<dynamic>(
      'customs-requests/upload',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    final data = response.data;
    final url = _extractUploadedFileUrl(data);
    if (url == null || url.isEmpty) {
      throw const UnknownServerException('Upload response has no fileUrl');
    }
    return url;
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

  static String _extension(String path) {
    final name = _fileName(path).toLowerCase();
    final idx = name.lastIndexOf('.');
    if (idx < 0 || idx == name.length - 1) return '';
    return name.substring(idx + 1);
  }

  static String _mimeByExtension(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }
}
