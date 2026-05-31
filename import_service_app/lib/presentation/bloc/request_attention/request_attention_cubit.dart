import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:import_service_app/presentation/bloc/request_attention/request_attention_state.dart';

final class RequestAttentionCubit extends Cubit<RequestAttentionState> {
  RequestAttentionCubit() : super(const RequestAttentionState());

  void markStatusUpdated(String requestId, {String? summary}) {
    final id = requestId.trim();
    if (id.isEmpty) return;
    final nextSummaries = Map<String, String>.from(state.statusUpdateSummaries);
    final trimmedSummary = summary?.trim();
    if (trimmedSummary != null && trimmedSummary.isNotEmpty) {
      nextSummaries[id] = trimmedSummary;
    }
    emit(
      RequestAttentionState(
        statusUpdatedIds: {...state.statusUpdatedIds, id},
        docsActionIds: state.docsActionIds,
        fileHighlightDocTypes: state.fileHighlightDocTypes,
        statusUpdateSummaries: nextSummaries,
      ),
    );
  }

  void clearStatusUpdated(String requestId) {
    final id = requestId.trim();
    if (id.isEmpty || !state.statusUpdatedIds.contains(id)) return;
    final next = {...state.statusUpdatedIds}..remove(id);
    final nextSummaries = Map<String, String>.from(state.statusUpdateSummaries)
      ..remove(id);
    emit(
      RequestAttentionState(
        statusUpdatedIds: next,
        docsActionIds: state.docsActionIds,
        fileHighlightDocTypes: state.fileHighlightDocTypes,
        statusUpdateSummaries: nextSummaries,
      ),
    );
  }

  void markDocsAction(String requestId) {
    final id = requestId.trim();
    if (id.isEmpty || state.docsActionIds.contains(id)) return;
    emit(
      RequestAttentionState(
        statusUpdatedIds: state.statusUpdatedIds,
        docsActionIds: {...state.docsActionIds, id},
        fileHighlightDocTypes: state.fileHighlightDocTypes,
        statusUpdateSummaries: state.statusUpdateSummaries,
      ),
    );
  }

  void clearDocsAction(String requestId) {
    final id = requestId.trim();
    if (id.isEmpty || !state.docsActionIds.contains(id)) return;
    final next = {...state.docsActionIds}..remove(id);
    emit(
      RequestAttentionState(
        statusUpdatedIds: state.statusUpdatedIds,
        docsActionIds: next,
        fileHighlightDocTypes: state.fileHighlightDocTypes,
        statusUpdateSummaries: state.statusUpdateSummaries,
      ),
    );
  }

  void markFileHighlights(String requestId, Iterable<String> docTypes) {
    final id = requestId.trim();
    if (id.isEmpty) return;
    final codes = docTypes
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    if (codes.isEmpty) return;
    final nextMap = Map<String, Set<String>>.from(state.fileHighlightDocTypes);
    nextMap[id] = codes;
    emit(
      RequestAttentionState(
        statusUpdatedIds: state.statusUpdatedIds,
        docsActionIds: state.docsActionIds,
        fileHighlightDocTypes: nextMap,
        statusUpdateSummaries: state.statusUpdateSummaries,
      ),
    );
  }

  void clearFileHighlights(String requestId) {
    final id = requestId.trim();
    if (id.isEmpty || !state.fileHighlightDocTypes.containsKey(id)) return;
    final nextMap = Map<String, Set<String>>.from(state.fileHighlightDocTypes)..remove(id);
    emit(
      RequestAttentionState(
        statusUpdatedIds: state.statusUpdatedIds,
        docsActionIds: state.docsActionIds,
        fileHighlightDocTypes: nextMap,
        statusUpdateSummaries: state.statusUpdateSummaries,
      ),
    );
  }
}
