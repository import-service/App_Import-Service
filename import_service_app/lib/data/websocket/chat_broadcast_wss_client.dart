import 'dart:convert' show jsonDecode, utf8;

import 'package:import_service_app/core/logging/app_log.dart';
import 'package:import_service_app/domain/entities/chat_message.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// [api-app.md] Realtime: `wss://.../ws/<requestId>/?token=...`, JSON-события.
final class ChatBroadcastWssClient {
  WebSocketChannel? _channel;
  bool get isActive => _channel != null;

  void connect({
    required String url,
    required void Function(ChatMessage message) onMessage,
    void Function(Object error, StackTrace? st)? onError,
    void Function()? onDone,
  }) {
    disconnect();
    try {
      final ch = WebSocketChannel.connect(Uri.parse(url));
      _channel = ch;
      ch.stream.listen(
        (data) {
          if (data is String) {
            _tryDispatch(data, onMessage);
            return;
          }
          if (data is List<int>) {
            _tryDispatch(utf8.decode(data), onMessage);
          }
        },
        onError: (Object e, StackTrace st) {
          onError?.call(e, st);
        },
        onDone: onDone,
      );
    } catch (e, st) {
      AppLog.error('WSS connect', tag: 'ChatWss', error: e, stackTrace: st);
      onError?.call(e, st);
    }
  }

  void _tryDispatch(String raw, void Function(ChatMessage message) onMessage) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final o = Map<String, dynamic>.from(decoded);
      final type = o['type'] as String?;
      if (type == 'message_incoming' || type == 'message_created' || type == 'message_incoming_1c') {
        _emitFromContainer(o, onMessage);
        return;
      }
      if (o.containsKey('message')) {
        _emitFromContainer(o, onMessage);
        return;
      }
      if (o.containsKey('id') && (o.containsKey('text') || o.containsKey('message'))) {
        onMessage(ChatMessage.fromJson(o));
        return;
      }
    } catch (e, st) {
      AppLog.error('WSS parse', tag: 'ChatWss', error: e, stackTrace: st);
    }
  }

  void _emitFromContainer(Map<String, dynamic> o, void Function(ChatMessage message) onMessage) {
    final raw = o['message'] ?? o['payload'] ?? o['data'] ?? o['item'];
    if (raw is Map) {
      onMessage(ChatMessage.fromJson(Map<String, dynamic>.from(raw)));
    }
  }

  void disconnect() {
    try {
      _channel?.sink.close();
    } catch (_) {
      // ignore
    } finally {
      _channel = null;
    }
  }
}
