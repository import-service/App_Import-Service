import 'package:dio/dio.dart';
import 'package:import_service_app/core/error/error_handler.dart';
import 'package:import_service_app/core/error/exceptions.dart';
import 'package:import_service_app/core/logging/app_log.dart';
import 'package:import_service_app/domain/entities/chat_message.dart';
import 'package:uuid/uuid.dart';

/// REST по чату: [api-app.md] `GET/POST` `/customs-requests/:id/messages`, `read`.
final class RequestChatRemoteDataSource {
  RequestChatRemoteDataSource(this._dio);

  final Dio _dio;
  static const Uuid _uuid = Uuid();

  static List<Map<String, dynamic>> _messageItemsFromResponse(dynamic data) {
    if (data is List<dynamic>) {
      return data.map((e) => e is Map<String, dynamic> ? e : null).whereType<Map<String, dynamic>>().toList();
    }
    if (data is! Map<String, dynamic>) {
      return <Map<String, dynamic>>[];
    }
    for (final key in <String>['items', 'data', 'results', 'messages', 'rows']) {
      final v = data[key];
      if (v is List<dynamic>) {
        return v.map((e) => e is Map<String, dynamic> ? e : null).whereType<Map<String, dynamic>>().toList();
      }
    }
    return <Map<String, dynamic>>[];
  }

  /// Последние сверху — превращаем в список для сортировки `createdAt` ↓/↑.
  Future<List<ChatMessage>> getMessages(
    String requestId, {
    int limit = 50,
    int? beforeId,
  }) async {
    final idEnc = Uri.encodeComponent(requestId);
    final path = 'customs-requests/$idEnc/messages';
    try {
      final q = <String, dynamic>{'limit': limit};
      if (beforeId != null) {
        q['beforeId'] = beforeId;
      }
      final response = await _dio.get<dynamic>(path, queryParameters: q);
      final data = response.data;
      final raw = _messageItemsFromResponse(data);
      return raw.map((e) => ChatMessage.fromJson(e)).toList();
    } on DioException catch (e, st) {
      final mapped = ErrorHandler.handle(e);
      AppLog.error('Chat messages: $path', tag: 'RequestChatRemote', error: e, stackTrace: st);
      throw mapped;
    } on ServerException {
      rethrow;
    } catch (e, st) {
      AppLog.error('Chat messages', tag: 'RequestChatRemote', error: e, stackTrace: st);
      throw const UnknownServerException('Не удалось загрузить сообщения');
    }
  }

  Future<ChatMessage> postMessage(
    String requestId, {
    required String text,
    String? clientMessageId,
    List<ChatAttachment> attachments = const <ChatAttachment>[],
  }) async {
    final idEnc = Uri.encodeComponent(requestId);
    final path = 'customs-requests/$idEnc/messages';
    final id = (clientMessageId != null && clientMessageId.isNotEmpty)
        ? clientMessageId
        : _uuid.v4();
    try {
      final payload = <String, dynamic>{
        'text': text,
        'clientMessageId': id,
        if (attachments.isNotEmpty)
          'attachments': attachments
              .map(
                (a) => <String, dynamic>{
                  'fileUrl': a.fileUrl,
                  if (a.fileName != null) 'fileName': a.fileName,
                  if (a.mimeType != null) 'mimeType': a.mimeType,
                },
              )
              .toList(),
      };
      final response = await _dio.post<dynamic>(path, data: payload);
      final d = response.data;
      if (d is! Map<String, dynamic>) {
        return ChatMessage(
          id: null,
          clientMessageId: id,
          text: text,
          isFrom1c: false,
          createdAt: DateTime.now().toUtc(),
          readByUser: true,
        );
      }
      if (d.containsKey('id') && d.containsKey('text')) {
        return ChatMessage.fromJson(d);
      }
      final inner = d['message'] ?? d['data'] ?? d['item'];
      if (inner is Map<String, dynamic>) {
        return ChatMessage.fromJson(inner);
      }
      return ChatMessage.fromJson(d);
    } on DioException catch (e, st) {
      final mapped = ErrorHandler.handle(e);
      AppLog.error('Chat send: $path', tag: 'RequestChatRemote', error: e, stackTrace: st);
      throw mapped;
    } on ServerException {
      rethrow;
    } catch (e, st) {
      AppLog.error('Chat send', tag: 'RequestChatRemote', error: e, stackTrace: st);
      throw const UnknownServerException('Не удалось отправить сообщение');
    }
  }

  Future<void> markRead(
    String requestId, {
    required int upToMessageId,
  }) async {
    final idEnc = Uri.encodeComponent(requestId);
    final path = 'customs-requests/$idEnc/messages/read';
    try {
      await _dio.post<dynamic>(
        path,
        data: <String, dynamic>{'upToMessageId': upToMessageId},
      );
    } on DioException catch (e, st) {
      final mapped = ErrorHandler.handle(e);
      AppLog.error('Chat read: $path', tag: 'RequestChatRemote', error: e, stackTrace: st);
      throw mapped;
    } on ServerException {
      rethrow;
    } catch (e, st) {
      AppLog.error('Chat read', tag: 'RequestChatRemote', error: e, stackTrace: st);
    }
  }
}
