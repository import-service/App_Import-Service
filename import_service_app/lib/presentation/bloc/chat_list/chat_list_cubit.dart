import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:import_service_app/core/auth/auth_session_controller.dart';
import 'package:import_service_app/domain/entities/chat_list_item.dart';
import 'package:import_service_app/domain/repositories/request_chat_repository.dart';
import 'package:import_service_app/presentation/bloc/car_inventory/car_inventory_cubit.dart';
import 'package:import_service_app/presentation/bloc/chat_list/chat_list_state.dart';
import 'package:import_service_app/presentation/bloc/request_chat_unread/request_chat_unread_cubit.dart';
import 'package:import_service_app/presentation/helpers/request_status_labels.dart';

final class ChatListCubit extends Cubit<ChatListState> {
  ChatListCubit({
    required RequestChatRepository repository,
    required AuthSessionController session,
    required CarInventoryCubit inventory,
    required RequestChatUnreadCubit unread,
  })  : _repository = repository,
        _session = session,
        _inventory = inventory,
        _unread = unread,
        super(const ChatListState());

  final RequestChatRepository _repository;
  final AuthSessionController _session;
  final CarInventoryCubit _inventory;
  final RequestChatUnreadCubit _unread;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    if (_session.isDemo) {
      emit(
        ChatListState(
          items: _demoItems(),
          isLoading: false,
        ),
      );
      return;
    }
    final result = await _repository.listChats();
    result.fold(
      (f) => emit(
        state.copyWith(isLoading: false, error: f.message),
      ),
      (items) {
        final pinned = <ChatListItem>[
          ...items.where((e) => e.isOrgChat),
          ...items.where((e) => !e.isOrgChat),
        ];
        emit(ChatListState(items: pinned, isLoading: false));
        _unread.replaceFromServer(
          pinned.where((e) => e.unread).map((e) => e.requestId).toSet(),
        );
      },
    );
  }

  void reset() {
    emit(const ChatListState());
  }

  List<ChatListItem> _demoItems() {
    final unread = _unread.state;
    final org = ChatListItem(
      requestId: ChatListItem.orgChatId,
      kind: 'org',
      carMake: '',
      carModel: '',
      vin: '',
      unread: unread.has(ChatListItem.orgChatId),
      unreadCount: unread.has(ChatListItem.orgChatId) ? 1 : 0,
    );
    final requests = _inventory.items
        .where(
          (c) => requestChatAvailable(
            status: c.status,
            external1cId: c.external1cId,
            managerFullName: c.managerFullName,
            isArchivedOffline: c.isArchivedOffline,
          ),
        )
        .map(
          (c) => ChatListItem(
            requestId: c.id,
            carMake: c.carMake,
            carModel: c.carModel,
            vin: c.vin,
            managerFullName: c.managerFullName,
            external1cId: c.external1cId,
            unread: unread.has(c.id),
            unreadCount: unread.has(c.id) ? 1 : 0,
          ),
        )
        .toList();
    return <ChatListItem>[org, ...requests];
  }
}
