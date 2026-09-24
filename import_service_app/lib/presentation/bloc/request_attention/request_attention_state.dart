import 'package:equatable/equatable.dart';

final class RequestAttentionState extends Equatable {
  const RequestAttentionState({
    this.statusUpdatedIds = const {},
    this.docsActionIds = const {},
    this.newDocTypes = const {},
    this.changedDocTypes = const {},
    this.statusUpdateSummaries = const {},
  });

  final Set<String> statusUpdatedIds;
  final Set<String> docsActionIds;

  /// Новые docType (ещё не «смотрели» в секции) — красный кружок.
  final Map<String, Set<String>> newDocTypes;

  /// Изменённые docType (перезаливка) — жёлтый «!».
  final Map<String, Set<String>> changedDocTypes;

  /// `requestId` → краткое описание изменения (push / локальная сборка).
  final Map<String, String> statusUpdateSummaries;

  bool hasStatusUpdate(String requestId) =>
      statusUpdatedIds.contains(requestId.trim());

  bool hasDocsAction(String requestId) =>
      docsActionIds.contains(requestId.trim());

  String? statusUpdateSummaryFor(String requestId) {
    return statusUpdateSummaries[requestId.trim()];
  }

  Set<String> newDocTypesFor(String requestId) {
    return newDocTypes[requestId.trim()] ?? const {};
  }

  Set<String> changedDocTypesFor(String requestId) {
    return changedDocTypes[requestId.trim()] ?? const {};
  }

  /// Совместимость: подсветка = new ∪ changed.
  Set<String> highlightedDocTypesFor(String requestId) {
    return {...newDocTypesFor(requestId), ...changedDocTypesFor(requestId)};
  }

  @override
  List<Object?> get props => [
        statusUpdatedIds,
        docsActionIds,
        newDocTypes,
        changedDocTypes,
        statusUpdateSummaries,
      ];
}
