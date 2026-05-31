import 'package:equatable/equatable.dart';

/// Сообщение чата заявки ([api-app.md], camelCase + snake_case при парсе).
final class ChatMessage extends Equatable {
  const ChatMessage({
    this.id,
    this.clientMessageId,
    required this.text,
    required this.isFrom1c,
    required this.createdAt,
    this.readByUser = true,
    this.attachments = const <ChatAttachment>[],
  });

  final int? id;
  final String? clientMessageId;
  final String text;
  final bool isFrom1c;
  final DateTime createdAt;
  final bool readByUser;
  final List<ChatAttachment> attachments;

  static DateTime? _parseTime(dynamic v) {
    if (v == null) return null;
    if (v is String) {
      return DateTime.tryParse(v);
    }
    return null;
  }

  static bool _readFromJson(Map<String, dynamic> json) {
    final a = json['readByUser'] ?? json['read_by_user'];
    if (a is bool) return a;
    final readAt = json['readByUserAt'] ?? json['read_by_user_at'];
    if (readAt is String && readAt.trim().isNotEmpty) return true;
    return true;
  }

  static bool _from1cFromJson(Map<String, dynamic> json) {
    final a = json['from1c'] ?? json['from_1c'];
    if (a is bool) return a;
    final direction = (json['direction']?.toString().trim().toLowerCase() ?? '');
    if (direction == 'from_1c') return true;
    final authorType = (json['authorType'] ?? json['author_type'])
        ?.toString()
        .trim()
        .toLowerCase();
    if (authorType == 'manager_1c') return true;
    return false;
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final idRaw = json['id'] ?? json['messageId'] ?? json['message_id'];
    int? id;
    if (idRaw is int) {
      id = idRaw;
    } else if (idRaw is num) {
      id = idRaw.toInt();
    } else if (idRaw is String) {
      id = int.tryParse(idRaw);
    }
    final text = ((json['text'] as String?) ??
            (json['textContent'] as String?) ??
            (json['text_content'] as String?))
        ?.trim() ??
        '';
    return ChatMessage(
      id: id,
      clientMessageId: json['clientMessageId'] as String? ?? json['client_message_id'] as String?,
      text: text,
      isFrom1c: _from1cFromJson(json),
      createdAt: _parseTime(json['createdAt'] ?? json['created_at'] ?? json['ts']) ?? DateTime.now().toUtc(),
      readByUser: _readFromJson(json),
      attachments: _attachmentsFromJson(json),
    );
  }

  static List<ChatAttachment> _attachmentsFromJson(Map<String, dynamic> json) {
    final raw = json['attachments'];
    if (raw is List<dynamic>) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map((e) => ChatAttachment.fromJson(e))
          .toList();
    }
    if (raw is Map<String, dynamic>) {
      final nested = raw['attachments'];
      if (nested is List<dynamic>) {
        return nested
            .whereType<Map<String, dynamic>>()
            .map((e) => ChatAttachment.fromJson(e))
            .toList();
      }
    }
    return const [];
  }

  @override
  List<Object?> get props => [id, clientMessageId, text, isFrom1c, createdAt, readByUser, attachments];
}

/// Вложение-ссылка (не бинарник) — [api-app.md] POST [attachments].
final class ChatAttachment extends Equatable {
  const ChatAttachment({
    required this.fileUrl,
    this.fileName,
    this.mimeType,
  });

  final String fileUrl;
  final String? fileName;
  final String? mimeType;

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    return ChatAttachment(
      fileUrl: (json['fileUrl'] as String? ?? json['file_url'] as String?)?.trim() ?? '',
      fileName: json['fileName'] as String? ?? json['file_name'] as String?,
      mimeType: json['mimeType'] as String? ?? json['mime_type'] as String?,
    );
  }

  @override
  List<Object?> get props => [fileUrl, fileName, mimeType];
}
