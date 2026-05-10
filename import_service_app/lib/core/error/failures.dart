import 'package:equatable/equatable.dart';

/// Ошибка для слоя domain / presentation (например `Either<Failure, T>`).
abstract class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

/// Чат по заявке недоступен (например нет [external1cId], 409 [CHAT_NOT_AVAILABLE]).
class ChatNotAvailableFailure extends Failure {
  const ChatNotAvailableFailure([super.message = 'Chat not available']);
}
