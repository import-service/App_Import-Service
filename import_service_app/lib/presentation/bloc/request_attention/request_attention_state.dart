import 'package:equatable/equatable.dart';

final class RequestAttentionState extends Equatable {
  const RequestAttentionState({
    this.statusUpdatedIds = const {},
    this.docsActionIds = const {},
    this.fileHighlightDocTypes = const {},
    this.statusUpdateSummaries = const {},
  });

  final Set<String> statusUpdatedIds;
  final Set<String> docsActionIds;

  /// `requestId` → docType для подсветки после `request_files_update`.
  final Map<String, Set<String>> fileHighlightDocTypes;

  /// `requestId` → краткое описание изменения (push / локальная сборка).
  final Map<String, String> statusUpdateSummaries;

  bool hasStatusUpdate(String requestId) => statusUpdatedIds.contains(requestId.trim());

  bool hasDocsAction(String requestId) => docsActionIds.contains(requestId.trim());

  String? statusUpdateSummaryFor(String requestId) {
    return statusUpdateSummaries[requestId.trim()];
  }

  Set<String> highlightedDocTypesFor(String requestId) {
    return fileHighlightDocTypes[requestId.trim()] ?? const {};
  }

  @override
  List<Object?> get props => [
        statusUpdatedIds,
        docsActionIds,
        fileHighlightDocTypes,
        statusUpdateSummaries,
      ];
}
