import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/extensions/navigation_context.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/presentation/bloc/chat_list/chat_list_cubit.dart';
import 'package:import_service_app/presentation/bloc/chat_list/chat_list_state.dart';
import 'package:import_service_app/presentation/bloc/request_chat_unread/request_chat_unread_cubit.dart';
import 'package:import_service_app/presentation/bloc/request_chat_unread/request_chat_unread_state.dart';
import 'package:import_service_app/presentation/widgets/cards/chat_list_card.dart';

class ChatsTabView extends StatelessWidget {
  const ChatsTabView({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = sl<JsonStringsService>();
    return BlocBuilder<ChatListCubit, ChatListState>(
      bloc: sl<ChatListCubit>(),
      builder: (context, listState) {
        return BlocBuilder<RequestChatUnreadCubit, RequestChatUnreadState>(
          bloc: sl<RequestChatUnreadCubit>(),
          builder: (context, unreadState) {
            if (listState.isLoading && listState.items.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            return RefreshIndicator(
              onRefresh: () => sl<ChatListCubit>().load(),
              child: _body(context, strings, listState, unreadState),
            );
          },
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    JsonStringsService strings,
    ChatListState listState,
    RequestChatUnreadState unreadState,
  ) {
    if (listState.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 320,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  listState.error ?? strings.chatsEmpty,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: listState.items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = listState.items[index];
        final hasUnread = unreadState.has(item.requestId) || item.unread;
        return ChatListCard(
          item: item,
          hasUnread: hasUnread,
          noPreviewText: strings.chatsNoPreview,
          onTap: () async {
            sl<RequestChatUnreadCubit>().clearUnread(item.requestId);
            await context.pushRequestChat(item.requestId);
            await sl<ChatListCubit>().load();
          },
        );
      },
    );
  }
}
