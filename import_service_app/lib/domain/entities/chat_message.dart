import 'package:equatable/equatable.dart';

/// Сообщение чата заявки.
final class ChatMessage extends Equatable {
  const ChatMessage({
    this.id,
    this.clientMessageId,
    required this.text,
    required this.isFrom1c,
    required this.createdAt,
    this.readByUser = false,
    this.readBy1c = false,
    this.deliveryStatus,
    this.attachments = const <ChatAttachment>[],
  });

  final int? id;
  final String? clientMessageId;
  final String text;
  final bool isFrom1c;
  final DateTime createdAt;
  /// Входящее от 1С прочитано пользователем МП.
  final bool readByUser;
  /// Исходящее к 1С прочитано менеджером.
  final bool readBy1c;
  /// `pending` | `delivered` | `failed` — для исходящих.
  final String? deliveryStatus;
  final List<ChatAttachment> attachments;

  bool get isDelivered =>
      deliveryStatus == 'delivered' || readBy1c || (id != null && !isFrom1c);

  ChatMessage copyWith({
    int? id,
    String? clientMessageId,
    String? text,
    bool? isFrom1c,
    DateTime? createdAt,
    bool? readByUser,
    bool? readBy1c,
    String? deliveryStatus,
    List<ChatAttachment>? attachments,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      text: text ?? this.text,
      isFrom1c: isFrom1c ?? this.isFrom1c,
      createdAt: createdAt ?? this.createdAt,
      readByUser: readByUser ?? this.readByUser,
      readBy1c: readBy1c ?? this.readBy1c,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      attachments: attachments ?? this.attachments,
    );
  }

  static DateTime? _parseTime(dynamic v) {
    if (v == null) return null;
    if (v is String) {
      return DateTime.tryParse(v);
    }
    return null;
  }

  static bool _hasTimestamp(Map<String, dynamic> json, List<String> keys) {
    for (final k in keys) {
      final v = json[k];
      if (v is String && v.trim().isNotEmpty) return true;
      if (v != null && v is! String) return true;
    }
    return false;
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
    final isFrom1c = _from1cFromJson(json);
    final delivery = (json['deliveryStatus'] ?? json['delivery_status'])
        ?.toString()
        .trim()
        .toLowerCase();
    return ChatMessage(
      id: id,
      clientMessageId:
          json['clientMessageId'] as String? ?? json['client_message_id'] as String?,
      text: text,
      isFrom1c: isFrom1c,
      createdAt: _parseTime(json['createdAt'] ?? json['created_at'] ?? json['ts']) ??
          DateTime.now().toUtc(),
      readByUser: _hasTimestamp(json, ['readByUserAt', 'read_by_user_at']) ||
          json['readByUser'] == true ||
          json['read_by_user'] == true,
      readBy1c: _hasTimestamp(json, ['readBy1cAt', 'read_by_1c_at']) ||
          json['readBy1c'] == true ||
          json['read_by_1c'] == true,
      deliveryStatus: delivery,
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
            .whereType<Map>()
            .map((e) => ChatAttachment.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    }
    return const [];
  }

  @override
  List<Object?> get props => [
        id,
        clientMessageId,
        text,
        isFrom1c,
        createdAt,
        readByUser,
        readBy1c,
        deliveryStatus,
        attachments,
      ];
}

/// Вложение-ссылка (не бинарник).
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
