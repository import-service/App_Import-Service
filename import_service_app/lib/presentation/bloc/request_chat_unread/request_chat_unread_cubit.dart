import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:import_service_app/presentation/bloc/request_chat_unread/request_chat_unread_state.dart';

final class RequestChatUnreadCubit extends Cubit<RequestChatUnreadState> {
  RequestChatUnreadCubit() : super(const RequestChatUnreadState(requestIds: {}));

  /// Локально прочитанные: не возвращать точку из `replaceFromServer`, пока не придёт
  /// новый `markUnread` (push / новое сообщение).
  final Set<String> _clearedSuppress = {};

  void markUnread(String requestId) {
    final id = requestId.trim();
    if (id.isEmpty) return;
    _clearedSuppress.remove(id);
    if (state.requestIds.contains(id)) return;
    emit(RequestChatUnreadState(requestIds: {...state.requestIds, id}));
  }

  void clearUnread(String requestId) {
    final id = requestId.trim();
    if (id.isEmpty) return;
    _clearedSuppress.add(id);
    if (!state.requestIds.contains(id)) return;
    final next = {...state.requestIds}..remove(id);
    emit(RequestChatUnreadState(requestIds: next));
  }

  /// Источник правды с сервера (`GET /customs-requests/chats`).
  /// Не реанимирует id из [_clearedSuppress] (открыли чат, markRead ещё не догнал).
  void replaceFromServer(Set<String> requestIds) {
    final fromServer =
        requestIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    _clearedSuppress.removeWhere((id) => !fromServer.contains(id));
    final next = fromServer.difference(_clearedSuppress);
    if (next.length == state.requestIds.length &&
        next.containsAll(state.requestIds)) {
      return;
    }
    emit(RequestChatUnreadState(requestIds: next));
  }

  void clearAll() {
    _clearedSuppress.clear();
    if (state.requestIds.isEmpty) return;
    emit(const RequestChatUnreadState(requestIds: {}));
  }
}
