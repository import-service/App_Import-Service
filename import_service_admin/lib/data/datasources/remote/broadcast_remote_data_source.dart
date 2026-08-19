import 'package:dio/dio.dart';
import 'package:import_service_admin/core/error/error_handler.dart';
import 'package:import_service_admin/core/error/exceptions.dart';

class BroadcastRemoteDataSource {
  BroadcastRemoteDataSource(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> send({
    required String text,
    String? senderName,
    List<int>? fileBytes,
    String? fileName,
  }) async {
    try {
      final form = FormData.fromMap(<String, dynamic>{
        'text': text,
        if (senderName != null && senderName.trim().isNotEmpty)
          'senderName': senderName.trim(),
        if (fileBytes != null && fileBytes.isNotEmpty && fileName != null)
          'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
      });
      final response = await _dio.post<dynamic>(
        'admin/broadcasts',
        data: form,
        options: Options(
          receiveTimeout: const Duration(minutes: 5),
          sendTimeout: const Duration(minutes: 5),
        ),
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const UnknownServerException('Некорректный ответ рассылки');
      }
      return data;
    } on DioException catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
