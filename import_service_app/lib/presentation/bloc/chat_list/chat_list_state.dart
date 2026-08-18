import 'package:equatable/equatable.dart';
import 'package:import_service_app/domain/entities/chat_list_item.dart';

final class ChatListState extends Equatable {
  const ChatListState({
    this.items = const <ChatListItem>[],
    this.isLoading = false,
    this.error,
  });

  final List<ChatListItem> items;
  final bool isLoading;
  final String? error;

  ChatListState copyWith({
    List<ChatListItem>? items,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ChatListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [items, isLoading, error];
}
