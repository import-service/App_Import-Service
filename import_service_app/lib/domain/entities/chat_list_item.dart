import 'package:equatable/equatable.dart';

/// Строка вкладки «Чаты»: заявка с доступным чатом (`external1cId`).
final class ChatListItem extends Equatable {
  const ChatListItem({
    required this.requestId,
    required this.carMake,
    required this.carModel,
    required this.vin,
    this.managerFullName,
    this.external1cId,
    this.lastText,
    this.lastAt,
    this.unread = false,
    this.unreadCount = 0,
  });

  final String requestId;
  final String carMake;
  final String carModel;
  final String vin;
  final String? managerFullName;
  final String? external1cId;
  final String? lastText;
  final DateTime? lastAt;
  final bool unread;
  final int unreadCount;

  String get displayCarLine {
    final a = carMake.trim();
    final b = carModel.trim();
    if (a.isEmpty && b.isEmpty) {
      return '—';
    }
    if (a.isEmpty) {
      return b;
    }
    if (b.isEmpty) {
      return a;
    }
    return '$a $b';
  }

  factory ChatListItem.fromJson(Map<String, dynamic> json) {
    final idRaw = json['requestId'] ?? json['request_id'] ?? json['id'];
    return ChatListItem(
      requestId: idRaw == null ? '' : idRaw.toString(),
      carMake: _str(json, 'carMake', 'car_make'),
      carModel: _str(json, 'carModel', 'car_model'),
      vin: _str(json, 'vin', 'vin'),
      managerFullName: _opt(json, 'managerFullName', 'manager_full_name'),
      external1cId: _opt(json, 'external1cId', 'external_1c_id'),
      lastText: _opt(json, 'lastText', 'last_text'),
      lastAt: _dt(json['lastAt'] ?? json['last_at']),
      unread: json['unread'] == true || _int(json['unreadCount'] ?? json['unread_count']) > 0,
      unreadCount: _int(json['unreadCount'] ?? json['unread_count']),
    );
  }

  static String _str(Map<String, dynamic> j, String a, String b) {
    return (j[a] ?? j[b])?.toString().trim() ?? '';
  }

  static String? _opt(Map<String, dynamic> j, String a, String b) {
    final s = _str(j, a, b);
    return s.isEmpty ? null : s;
  }

  static int _int(dynamic raw) {
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  static DateTime? _dt(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toUtc();
    return DateTime.tryParse(raw.toString())?.toUtc();
  }

  @override
  List<Object?> get props => [
        requestId,
        carMake,
        carModel,
        vin,
        managerFullName,
        external1cId,
        lastText,
        lastAt,
        unread,
        unreadCount,
      ];
}
