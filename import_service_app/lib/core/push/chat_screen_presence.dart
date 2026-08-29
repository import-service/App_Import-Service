/// Какой чат сейчас на экране (для push и live-refresh).
final class ChatScreenPresence {
  String? _openRequestId;
  void Function()? _onLiveUpdate;

  String? get openRequestId => _openRequestId;

  void enter(String requestId, {void Function()? onLiveUpdate}) {
    _openRequestId = requestId.trim();
    _onLiveUpdate = onLiveUpdate;
  }

  void leave(String requestId) {
    if (_openRequestId == requestId.trim()) {
      _openRequestId = null;
      _onLiveUpdate = null;
    }
  }

  bool isOpen(String requestId) =>
      _openRequestId != null && _openRequestId == requestId.trim();

  /// Push / внешний сигнал: обновить открытый чат (HTTP merge), не показывать toast.
  void notifyLiveUpdate(String requestId) {
    if (!isOpen(requestId)) return;
    _onLiveUpdate?.call();
  }
}
