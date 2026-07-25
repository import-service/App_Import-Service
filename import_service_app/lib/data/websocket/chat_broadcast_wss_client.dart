import 'dart:async';
import 'dart:convert' show jsonDecode, jsonEncode, utf8;

import 'package:import_service_app/core/logging/app_log.dart';
import 'package:import_service_app/domain/entities/chat_message.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Событие read из комнаты (МП или 1С).
final class ChatReadEvent {
  const ChatReadEvent({
    required this.upToMessageId,
    required this.by,
  });

  final int upToMessageId;
  /// `user` | `1c`
  final String by;
}

/// Полный дуплекс чата: history / send / read + входящие события.
final class ChatBroadcastWssClient {
  WebSocketChannel? _channel;
  Completer<Map<String, dynamic>>? _pendingSendAck;
  Completer<Map<String, dynamic>>? _pendingHistory;
  Completer<Map<String, dynamic>>? _pendingReadAck;

  bool get isActive => _channel != null;

  void connect({
    required String url,
    required void Function(ChatMessage message) onMessage,
    void Function(ChatReadEvent event)? onRead,
    void Function(Object error, StackTrace? st)? onError,
    void Function()? onDone,
  }) {
    disconnect();
    try {
      final ch = WebSocketChannel.connect(Uri.parse(url));
      _channel = ch;
      ch.stream.listen(
        (data) {
          final raw = data is String
              ? data
              : data is List<int>
                  ? utf8.decode(data)
                  : null;
          if (raw == null) return;
          _dispatch(raw, onMessage, onRead);
        },
        onError: (Object e, StackTrace st) {
          _failPending(e);
          onError?.call(e, st);
        },
        onDone: () {
          _failPending(StateError('wss closed'));
          onDone?.call();
        },
      );
    } catch (e, st) {
      AppLog.error('WSS connect', tag: 'ChatWss', error: e, stackTrace: st);
      onError?.call(e, st);
    }
  }

  void _failPending(Object e) {
    if (_pendingSendAck != null && !_pendingSendAck!.isCompleted) {
      _pendingSendAck!.completeError(e);
    }
    if (_pendingHistory != null && !_pendingHistory!.isCompleted) {
      _pendingHistory!.completeError(e);
    }
    if (_pendingReadAck != null && !_pendingReadAck!.isCompleted) {
      _pendingReadAck!.completeError(e);
    }
    _pendingSendAck = null;
    _pendingHistory = null;
    _pendingReadAck = null;
  }

  void _dispatch(
    String raw,
    void Function(ChatMessage message) onMessage,
    void Function(ChatReadEvent event)? onRead,
  ) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final o = Map<String, dynamic>.from(decoded);
      final type = (o['type'] as String?)?.trim().toLowerCase() ?? '';

      if (type == 'send_ack') {
        final c = _pendingSendAck;
        _pendingSendAck = null;
        if (c != null && !c.isCompleted) c.complete(o);
        return;
      }
      if (type == 'history') {
        final c = _pendingHistory;
        _pendingHistory = null;
        if (c != null && !c.isCompleted) c.complete(o);
        return;
      }
      if (type == 'read_ack') {
        final c = _pendingReadAck;
        _pendingReadAck = null;
        if (c != null && !c.isCompleted) c.complete(o);
        return;
      }
      if (type == 'read') {
        final upTo = _asInt(o['upToMessageId'] ?? o['up_to_message_id']);
        final by = (o['by'] as String?)?.trim().toLowerCase() ?? '';
        if (upTo != null && upTo > 0 && onRead != null) {
          onRead(ChatReadEvent(upToMessageId: upTo, by: by));
        }
        return;
      }
      if (type == 'ready' || type == 'pong' || type == 'error') {
        return;
      }
      if (type == 'message_incoming' ||
          type == 'message_created' ||
          type == 'message_incoming_1c') {
        _emitFromContainer(o, onMessage);
        return;
      }
      if (o.containsKey('message')) {
        _emitFromContainer(o, onMessage);
        return;
      }
      if (o.containsKey('id') &&
          (o.containsKey('text') || o.containsKey('text_content'))) {
        onMessage(ChatMessage.fromJson(o));
      }
    } catch (e, st) {
      AppLog.error('WSS parse', tag: 'ChatWss', error: e, stackTrace: st);
    }
  }

  void _emitFromContainer(
    Map<String, dynamic> o,
    void Function(ChatMessage message) onMessage,
  ) {
    final raw = o['message'] ?? o['payload'] ?? o['data'] ?? o['item'];
    if (raw is Map) {
      onMessage(ChatMessage.fromJson(Map<String, dynamic>.from(raw)));
    }
  }

  static int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  void _send(Map<String, dynamic> body) {
    final ch = _channel;
    if (ch == null) {
      throw StateError('wss not connected');
    }
    ch.sink.add(jsonEncode(body));
  }

  Future<List<ChatMessage>> requestHistory({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (_pendingHistory != null) {
      throw StateError('history already pending');
    }
    final c = Completer<Map<String, dynamic>>();
    _pendingHistory = c;
    _send({'type': 'history'});
    final o = await c.future.timeout(timeout);
    final items = o['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ChatMessage?> sendMessage({
    required String clientMessageId,
    required String text,
    List<ChatAttachment> attachments = const [],
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (_pendingSendAck != null) {
      throw StateError('send already pending');
    }
    final c = Completer<Map<String, dynamic>>();
    _pendingSendAck = c;
    _send({
      'type': 'send',
      'clientMessageId': clientMessageId,
      'text': text,
      'attachments': attachments
          .map(
            (a) => {
              'fileUrl': a.fileUrl,
              if (a.fileName != null) 'fileName': a.fileName,
              if (a.mimeType != null) 'mimeType': a.mimeType,
            },
          )
          .toList(),
    });
    final o = await c.future.timeout(timeout);
    if (o['ok'] != true) {
      throw StateError((o['message'] ?? o['error'] ?? 'send_failed').toString());
    }
    final msg = o['message'];
    if (msg is Map) {
      return ChatMessage.fromJson(Map<String, dynamic>.from(msg));
    }
    return null;
  }

  Future<void> sendRead({
    required int upToMessageId,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (_pendingReadAck != null) {
      throw StateError('read already pending');
    }
    final c = Completer<Map<String, dynamic>>();
    _pendingReadAck = c;
    _send({'type': 'read', 'upToMessageId': upToMessageId});
    final o = await c.future.timeout(timeout);
    if (o['ok'] == false) {
      throw StateError((o['message'] ?? o['error'] ?? 'read_failed').toString());
    }
  }

  void disconnect() {
    _failPending(StateError('wss disconnect'));
    try {
      _channel?.sink.close();
    } catch (_) {
      // ignore
    } finally {
      _channel = null;
    }
  }
}
