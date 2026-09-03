import 'package:dio/dio.dart';
import 'package:import_service_app/core/error/error_handler.dart';
import 'package:import_service_app/core/error/exceptions.dart';
import 'package:import_service_app/core/logging/app_log.dart';

/// `POST /api/feedback` — обратная связь из Профиля.
class FeedbackRemoteDataSource {
  FeedbackRemoteDataSource(this._dio);

  final Dio _dio;

  Future<void> submitFeedback({
    required String message,
    String? appVersion,
    String? platform,
  }) async {
    try {
      final body = <String, dynamic>{'message': message.trim()};
      final version = appVersion?.trim() ?? '';
      if (version.isNotEmpty) {
        body['appVersion'] = version;
      }
      final plat = platform?.trim() ?? '';
      if (plat.isNotEmpty) {
        body['platform'] = plat;
      }
      final response = await _dio.post<dynamic>('feedback', data: body);
      final data = response.data;
      if (data is! Map<String, dynamic> || data['ok'] != true) {
        throw const UnknownServerException('Invalid feedback response');
      }
    } on DioException catch (e, st) {
      final mapped = ErrorHandler.handle(e);
      AppLog.error(
        'Submit feedback failed: /api/feedback',
        tag: 'FeedbackRemoteDataSource',
        error: e,
        stackTrace: st,
      );
      throw mapped;
    } on ServerException {
      rethrow;
    } catch (e, st) {
      AppLog.error(
        'Unexpected feedback failure',
        tag: 'FeedbackRemoteDataSource',
        error: e,
        stackTrace: st,
      );
      throw const UnknownServerException('Не удалось отправить обратную связь');
    }
  }
}
