import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:import_service_app/presentation/bloc/request_chat_unread/request_chat_unread_state.dart';

final class RequestChatUnreadCubit extends Cubit<RequestChatUnreadState> {
  RequestChatUnreadCubit() : super(const RequestChatUnreadState(requestIds: {}));

  void markUnread(String requestId) {
    final id = requestId.trim();
    if (id.isEmpty || state.requestIds.contains(id)) return;
    emit(RequestChatUnreadState(requestIds: {...state.requestIds, id}));
  }

  void clearUnread(String requestId) {
    final id = requestId.trim();
    if (id.isEmpty || !state.requestIds.contains(id)) return;
    final next = {...state.requestIds}..remove(id);
    emit(RequestChatUnreadState(requestIds: next));
  }

  /// Источник правды с сервера (`GET /customs-requests/chats`).
  void replaceFromServer(Set<String> requestIds) {
    final next = requestIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    if (next.length == state.requestIds.length &&
        next.containsAll(state.requestIds)) {
      return;
    }
    emit(RequestChatUnreadState(requestIds: next));
  }

  void clearAll() {
    if (state.requestIds.isEmpty) return;
    emit(const RequestChatUnreadState(requestIds: {}));
  }
}
