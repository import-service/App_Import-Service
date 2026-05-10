import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:import_service_app/core/auth/auth_session_controller.dart';
import 'package:import_service_app/core/constants/api_config.dart';
import 'package:import_service_app/core/error/failures.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/data/websocket/chat_broadcast_wss_client.dart';
import 'package:import_service_app/domain/entities/chat_message.dart';
import 'package:import_service_app/domain/repositories/request_chat_repository.dart';
import 'package:import_service_app/presentation/bloc/request_chat/request_chat_state.dart';
import 'package:uuid/uuid.dart';

/// Чат по заявке: демо-ответ, REST + WSS [api-app.md].
final class RequestChatCubit extends Cubit<RequestChatState> {
  RequestChatCubit({
    required this.requestId,
    required RequestChatRepository repository,
    required AuthSessionController session,
    required JsonStringsService strings,
    required ChatBroadcastWssClient wss,
  })  : _repo = repository,
        _session = session,
        _strings = strings,
        _wss = wss,
        super(const RequestChatState()) {
    Future<void>.microtask(load);
  }

  final String requestId;
  final RequestChatRepository _repo;
  final AuthSessionController _session;
  final JsonStringsService _strings;
  final ChatBroadcastWssClient _wss;
  int _demoSeq = 0;
  static const Uuid _uuid = Uuid();

  List<ChatMessage> _sortAndDedupe(Iterable<ChatMessage> all) {
    final byId = <int, ChatMessage>{};
    final withoutId = <ChatMessage>[];
    for (final m in all) {
      if (m.id != null) {
        byId[m.id!] = m;
      } else {
        withoutId.add(m);
      }
    }
    final combined = <ChatMessage>[...byId.values, ...withoutId];
    combined.sort((a, b) {
      final t = a.createdAt.compareTo(b.createdAt);
      if (t != 0) {
        return t;
      }
      return (a.id ?? 0).compareTo(b.id ?? 0);
    });
    return combined;
  }

  Future<void> load() async {
    if (requestId.isEmpty) {
      emit(state.copyWith(isLoading: false, error: 'id'));
      return;
    }
    if (_session.isDemo) {
      emit(
        state.copyWith(
          isLoading: false,
          messages: const <ChatMessage>[],
          isUnavailable: false,
          error: null,
        ),
      );
      return;
    }
    emit(state.copyWith(isLoading: true, error: null, isUnavailable: false));
    final r = await _repo.loadMessages(requestId, limit: 100);
    r.fold(
      (f) {
        if (f is ChatNotAvailableFailure) {
          emit(
            state.copyWith(
              isLoading: false,
              isUnavailable: true,
            ),
          );
        } else {
          emit(
            state.copyWith(
              isLoading: false,
              error: f.message,
            ),
          );
        }
      },
      (raw) {
        final sorted = _sortAndDedupe(raw);
        emit(
          state.copyWith(
            isLoading: false,
            messages: sorted,
            error: null,
          ),
        );
        unawaited(_markReadInBackground(sorted));
        _connectWss();
      },
    );
  }

  void _connectWss() {
    if (_session.isDemo) {
      return;
    }
    final t = _session.accessToken;
    if (t == null || t.isEmpty) {
      return;
    }
    if (_wss.isActive) {
      return;
    }
    final url = ApiConfig.chatWebsocketUrl(requestId, t);
    _wss.connect(
      url: url,
      onMessage: (msg) {
        if (isClosed) {
          return;
        }
        _ingestWssMessage(msg);
      },
      onError: (e, st) {
        if (isClosed) {
          return;
        }
        emit(state.copyWith(wssConnected: false));
      },
      onDone: () {
        if (isClosed) {
          return;
        }
        emit(state.copyWith(wssConnected: false));
      },
    );
    emit(state.copyWith(wssConnected: true));
  }

  void _ingestWssMessage(ChatMessage msg) {
    if (msg.id != null) {
      if (state.messages.any((m) => m.id == msg.id)) {
        return;
      }
    }
    final c = msg.clientMessageId;
    if (c != null && c.isNotEmpty) {
      if (state.messages.any(
        (m) => m.id != null && m.clientMessageId == c,
      )) {
        return;
      }
    }
    final next = _sortAndDedupe(<ChatMessage>[...state.messages, msg]);
    emit(state.copyWith(messages: next));
    unawaited(_markReadInBackground(next));
  }

  Future<void> _markReadInBackground(List<ChatMessage> list) async {
    if (_session.isDemo) {
      return;
    }
    var maxId = 0;
    for (final m in list) {
      if (m.isFrom1c) {
        final n = m.id;
        if (n != null && n > maxId) {
          maxId = n;
        }
      }
    }
    if (maxId == 0) {
      return;
    }
    await _repo.markReadUpTo(requestId, upToMessageId: maxId);
  }

  Future<void> send(String text) async {
    var t = text.trim();
    if (t.isEmpty) {
      return;
    }
    if (t.length > 2000) {
      t = t.substring(0, 2000);
    }
    if (isClosed) {
      return;
    }

    if (_session.isDemo) {
      _appendDemoExchange(t);
      return;
    }
    if (state.isUnavailable) {
      return;
    }
    final clientId = _uuid.v4();
    final optimistic = ChatMessage(
      id: null,
      clientMessageId: clientId,
      text: t,
      isFrom1c: false,
      createdAt: DateTime.now().toUtc(),
      readByUser: true,
    );
    emit(
      state.copyWith(
        isSending: true,
        error: null,
        messages: _sortAndDedupe([...state.messages, optimistic]),
      ),
    );
    final r = await _repo.sendMessage(
      requestId,
      text: t,
      clientMessageId: clientId,
    );
    if (isClosed) {
      return;
    }
    r.fold(
      (f) {
        if (f is ChatNotAvailableFailure) {
          emit(
            state.copyWith(
              isSending: false,
              isUnavailable: true,
              messages: _removeByClientId(state.messages, clientId),
            ),
          );
        } else {
          emit(
            state.copyWith(
              isSending: false,
              error: f.message,
              messages: _removeByClientId(state.messages, clientId),
            ),
          );
        }
      },
      (server) {
        final afterRemove = _removeByClientId(state.messages, clientId);
        final next = _replaceOrAppendServer(afterRemove, server);
        emit(
          state.copyWith(
            isSending: false,
            messages: next,
          ),
        );
        unawaited(_markReadInBackground(next));
      },
    );
  }

  void _appendDemoExchange(String userText) {
    _demoSeq += 1;
    final u = ChatMessage(
      id: -_demoSeq * 2,
      text: userText,
      isFrom1c: false,
      createdAt: DateTime.now().toUtc(),
      readByUser: true,
    );
    _demoSeq += 1;
    final reply = ChatMessage(
      id: -_demoSeq * 2,
      text: _strings.chatDemoAutoReply,
      isFrom1c: true,
      createdAt: DateTime.now().toUtc().add(const Duration(milliseconds: 30)),
      readByUser: true,
    );
    emit(
      state.copyWith(
        messages: _sortAndDedupe([...state.messages, u, reply]),
        isSending: false,
        error: null,
      ),
    );
  }

  List<ChatMessage> _replaceOrAppendServer(List<ChatMessage> list, ChatMessage server) {
    if (server.id != null) {
      final withSameId = list.where((m) => m.id == server.id).isNotEmpty;
      if (withSameId) {
        return _sortAndDedupe(
          list.map((m) => m.id == server.id ? server : m).toList(),
        );
      }
    }
    return _sortAndDedupe([...list, server]);
  }

  List<ChatMessage> _removeByClientId(List<ChatMessage> list, String clientId) {
    return list.where((m) => m.clientMessageId != clientId).toList();
  }

  void clearError() {
    if (isClosed) {
      return;
    }
    emit(state.copyWith(error: null));
  }

  @override
  Future<void> close() {
    _wss.disconnect();
    return super.close();
  }
}
