import 'package:dio/dio.dart';
import 'package:import_service_admin/core/error/error_handler.dart';
import 'package:import_service_admin/core/error/exceptions.dart';

class AndroidApkRemoteDataSource {
  AndroidApkRemoteDataSource(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> fetchStatus() async {
    try {
      final response = await _dio.get<dynamic>('admin/android-apk');
      final data = response.data;
      if (data is! Map) {
        throw const UnknownServerException('Некорректный ответ android-apk');
      }
      return data.map((k, v) => MapEntry(k.toString(), v));
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<Map<String, dynamic>> upload({
    required List<int> fileBytes,
    required String fileName,
    required int versionCode,
    String? versionName,
  }) async {
    try {
      final form = FormData.fromMap(<String, dynamic>{
        'versionCode': '$versionCode',
        if (versionName != null && versionName.trim().isNotEmpty)
          'versionName': versionName.trim(),
        'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
      });
      final response = await _dio.post<dynamic>(
        'admin/android-apk',
        data: form,
        options: Options(
          sendTimeout: const Duration(minutes: 10),
          receiveTimeout: const Duration(minutes: 10),
        ),
      );
      final data = response.data;
      if (data is! Map) {
        throw const UnknownServerException('Некорректный ответ загрузки APK');
      }
      return data.map((k, v) => MapEntry(k.toString(), v));
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
