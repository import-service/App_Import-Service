/// Какой чат заявки сейчас на экране (для игнора push).
final class ChatScreenPresence {
  String? _openRequestId;

  String? get openRequestId => _openRequestId;

  void enter(String requestId) {
    _openRequestId = requestId.trim();
  }

  void leave(String requestId) {
    if (_openRequestId == requestId.trim()) {
      _openRequestId = null;
    }
  }

  bool isOpen(String requestId) =>
      _openRequestId != null && _openRequestId == requestId.trim();
}
