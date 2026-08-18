import 'package:equatable/equatable.dart';

final class RequestChatUnreadState extends Equatable {
  const RequestChatUnreadState({
    required this.requestIds,
  });

  final Set<String> requestIds;

  bool has(String requestId) => requestIds.contains(requestId.trim());

  bool get hasAny => requestIds.isNotEmpty;

  @override
  List<Object?> get props => [requestIds];
}
