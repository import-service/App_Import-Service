import 'package:equatable/equatable.dart';
import 'package:import_service_app/domain/entities/chat_message.dart';

const Object _usePrevious = Object();

class RequestChatState extends Equatable {
  const RequestChatState({
    this.messages = const <ChatMessage>[],
    this.isLoading = true,
    this.isSending = false,
    this.isUnavailable = false,
    this.wssConnected = false,
    this.error,
  });

  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isSending;
  final bool isUnavailable;
  final bool wssConnected;
  final String? error;

  RequestChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isSending,
    bool? isUnavailable,
    bool? wssConnected,
    Object? error = _usePrevious,
  }) {
    return RequestChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      isUnavailable: isUnavailable ?? this.isUnavailable,
      wssConnected: wssConnected ?? this.wssConnected,
      error: identical(_usePrevious, error) ? this.error : error as String?,
    );
  }

  @override
  List<Object?> get props => [messages, isLoading, isSending, isUnavailable, wssConnected, error];
}
