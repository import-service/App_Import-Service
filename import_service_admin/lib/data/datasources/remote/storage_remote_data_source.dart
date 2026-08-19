import 'package:dio/dio.dart';
import 'package:import_service_admin/core/error/error_handler.dart';
import 'package:import_service_admin/core/error/exceptions.dart';

class StorageRemoteDataSource {
  StorageRemoteDataSource(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> fetchStats() async {
    try {
      final response = await _dio.get<dynamic>('admin/storage/stats');
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const UnknownServerException('Некорректная статистика хранилища');
      }
      return data;
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<List<Map<String, dynamic>>> fetchExpiredClosed() async {
    try {
      final response = await _dio.get<dynamic>('admin/storage/expired-closed');
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const UnknownServerException('Некорректный список просроченных');
      }
      final raw = data['items'];
      if (raw is! List) return const [];
      return raw.whereType<Map<String, dynamic>>().toList(growable: false);
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<int> updateRetentionMonths(int months) async {
    try {
      final response = await _dio.put<dynamic>(
        'admin/storage/retention',
        data: {'retentionMonths': months},
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) return months;
      return data['retentionMonths'] is int
          ? data['retentionMonths'] as int
          : int.tryParse('${data['retentionMonths']}') ?? months;
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<Map<String, dynamic>> purgeExpired() async {
    try {
      final response = await _dio.post<dynamic>('admin/storage/purge-expired');
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const UnknownServerException('Некорректный ответ очистки');
      }
      return data;
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<void> deleteRequest(String id) async {
    try {
      await _dio.delete<dynamic>(
        'admin/customs-requests/${Uri.encodeComponent(id)}',
      );
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<List<Map<String, dynamic>>> fetchArchives() async {
    try {
      final response = await _dio.get<dynamic>('admin/archives');
      final data = response.data;
      if (data is! Map<String, dynamic>) return const [];
      final raw = data['items'];
      if (raw is! List) return const [];
      return raw.whereType<Map<String, dynamic>>().toList(growable: false);
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<List<Map<String, dynamic>>> previewPeriod({
    required String periodFrom,
    required String periodTo,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        'admin/archives/preview',
        queryParameters: <String, dynamic>{
          'periodFrom': periodFrom,
          'periodTo': periodTo,
        },
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) return const [];
      final raw = data['items'];
      if (raw is! List) return const [];
      return raw.whereType<Map<String, dynamic>>().toList(growable: false);
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<({List<int> bytes, String filename})> exportZip({
    required String periodFrom,
    required String periodTo,
    required String archivedByName,
    String? archiveLocation,
  }) async {
    try {
      final body = <String, dynamic>{
        'periodFrom': periodFrom,
        'periodTo': periodTo,
        'archivedByName': archivedByName,
      };
      final loc = archiveLocation?.trim();
      if (loc != null && loc.isNotEmpty) {
        body['archiveLocation'] = loc;
      }
      final response = await _dio.post<List<int>>(
        'admin/archives/export',
        data: body,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(minutes: 5),
          sendTimeout: const Duration(minutes: 2),
        ),
      );
      final bytes = response.data ?? <int>[];
      final disp = response.headers.value('content-disposition') ?? '';
      final m = RegExp(r'filename="?([^"]+)"?').firstMatch(disp);
      return (
        bytes: bytes,
        filename: m?.group(1) ?? 'request-archive.zip',
      );
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<Map<String, dynamic>> importPreview(List<int> zipBytes, String filename) async {
    try {
      final form = FormData.fromMap(<String, dynamic>{
        'file': MultipartFile.fromBytes(zipBytes, filename: filename),
      });
      final response = await _dio.post<dynamic>(
        'admin/archives/import-preview',
        data: form,
        options: Options(
          receiveTimeout: const Duration(minutes: 5),
          sendTimeout: const Duration(minutes: 5),
        ),
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const UnknownServerException('Некорректный ответ разбора ZIP');
      }
      return data;
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<Map<String, dynamic>> importZip({
    required List<int> zipBytes,
    required String filename,
    required List<int> requestIds,
  }) async {
    try {
      final form = FormData.fromMap(<String, dynamic>{
        'file': MultipartFile.fromBytes(zipBytes, filename: filename),
      });
      final response = await _dio.post<dynamic>(
        'admin/archives/import',
        data: form,
        queryParameters: <String, dynamic>{
          if (requestIds.isNotEmpty) 'requestIds': requestIds.join(','),
        },
        options: Options(
          receiveTimeout: const Duration(minutes: 5),
          sendTimeout: const Duration(minutes: 5),
        ),
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const UnknownServerException('Некорректный ответ импорта');
      }
      return data;
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<Map<String, dynamic>> purgeMarkedArchives() async {
    try {
      final response = await _dio.post<dynamic>('admin/archives/purge-marked');
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const UnknownServerException('Некорректный ответ очистки архива');
      }
      return data;
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
