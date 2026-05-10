import 'package:dartz/dartz.dart';
import 'package:import_service_app/core/error/failures.dart';
import 'package:import_service_app/domain/entities/chat_message.dart';

/// Чат по заявке: REST + при необходимости WSS (см. [RequestChatCubit]).
abstract class RequestChatRepository {
  Future<Either<Failure, List<ChatMessage>>> loadMessages(
    String requestId, {
    int limit = 50,
    int? beforeId,
  });

  Future<Either<Failure, ChatMessage>> sendMessage(
    String requestId, {
    required String text,
    String? clientMessageId,
    List<ChatAttachment> attachments = const <ChatAttachment>[],
  });

  Future<Either<Failure, void>> markReadUpTo(
    String requestId, {
    required int upToMessageId,
  });
}
