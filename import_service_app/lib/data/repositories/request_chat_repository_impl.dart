import 'package:dartz/dartz.dart';
import 'package:import_service_app/core/auth/auth_session_controller.dart';
import 'package:import_service_app/core/error/exceptions.dart';
import 'package:import_service_app/core/error/failures.dart';
import 'package:import_service_app/data/datasources/remote/request_chat_remote_data_source.dart';
import 'package:import_service_app/domain/entities/chat_list_item.dart';
import 'package:import_service_app/domain/entities/chat_message.dart';
import 'package:import_service_app/domain/repositories/request_chat_repository.dart';

final class RequestChatRepositoryImpl implements RequestChatRepository {
  RequestChatRepositoryImpl({
    required RequestChatRemoteDataSource remote,
    required AuthSessionController session,
  })  : _remote = remote,
        _session = session;

  final RequestChatRemoteDataSource _remote;
  final AuthSessionController _session;

  @override
  Future<Either<Failure, List<ChatListItem>>> listChats() async {
    if (_session.isDemo) {
      return const Right(<ChatListItem>[]);
    }
    try {
      final list = await _remote.getChats();
      return Right(list);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ChatMessage>>> loadMessages(
    String requestId, {
    int limit = 50,
    int? beforeId,
    bool isSvhChat = false,
    String? svhManagerId,
  }) async {
    if (_session.isDemo) {
      return const Right(<ChatMessage>[]);
    }
    try {
      final list = await _remote.getMessages(
        requestId,
        limit: limit,
        beforeId: beforeId,
        isSvhChat: isSvhChat,
        svhManagerId: svhManagerId,
      );
      return Right(list);
    } on ConflictException catch (e) {
      return Left(ChatNotAvailableFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ChatMessage>> sendMessage(
    String requestId, {
    required String text,
    String? clientMessageId,
    List<ChatAttachment> attachments = const <ChatAttachment>[],
    bool isSvhChat = false,
    String? svhManagerId,
  }) async {
    try {
      final msg = await _remote.postMessage(
        requestId,
        text: text,
        clientMessageId: clientMessageId,
        attachments: attachments,
        isSvhChat: isSvhChat,
        svhManagerId: svhManagerId,
      );
      return Right(msg);
    } on ConflictException catch (e) {
      return Left(ChatNotAvailableFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> markReadUpTo(
    String requestId, {
    required int upToMessageId,
    bool isSvhChat = false,
    String? svhManagerId,
  }) async {
    if (_session.isDemo) {
      return const Right(null);
    }
    try {
      await _remote.markRead(
        requestId,
        upToMessageId: upToMessageId,
        isSvhChat: isSvhChat,
        svhManagerId: svhManagerId,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ChatAttachment>> uploadAttachment(
    String requestId, {
    required String filePath,
    String? fileName,
    bool isSvhChat = false,
  }) async {
    try {
      final att = await _remote.uploadAttachment(
        requestId,
        filePath: filePath,
        fileName: fileName,
        isSvhChat: isSvhChat,
      );
      return Right(att);
    } on ConflictException catch (e) {
      return Left(ChatNotAvailableFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
