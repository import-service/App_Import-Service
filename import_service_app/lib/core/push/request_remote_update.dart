/// Push: обновление заявки (метаданные или файлы).
final class RequestRemoteUpdate {
  const RequestRemoteUpdate({
    required this.requestId,
    this.isFilesUpdate = false,
    this.changedDocTypes = const [],
    this.status,
    this.statusSubType,
    this.previousStatus,
    this.changeSummary,
  });

  final String requestId;
  final bool isFilesUpdate;
  final List<String> changedDocTypes;

  /// Код верхнего статуса из FCM data (`status`).
  final String? status;

  /// Подстатус из FCM data (`statusSubType`).
  final String? statusSubType;

  /// Предыдущий статус (если бэк пришлёт `previousStatus`).
  final String? previousStatus;

  /// Готовая строка для UI (`changeSummary`), приоритет над локальной сборкой.
  final String? changeSummary;
}
