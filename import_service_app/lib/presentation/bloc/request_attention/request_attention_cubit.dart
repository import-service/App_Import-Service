import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/data/local/request_file_seen_store.dart';
import 'package:import_service_app/domain/entities/customs_request_file.dart';
import 'package:import_service_app/presentation/bloc/request_attention/request_attention_state.dart';

final class RequestAttentionCubit extends Cubit<RequestAttentionState> {
  RequestAttentionCubit() : super(const RequestAttentionState());

  final Map<String, Timer> _changedClearTimers = {};

  RequestAttentionState _copy({
    Set<String>? statusUpdatedIds,
    Set<String>? docsActionIds,
    Map<String, Set<String>>? newDocTypes,
    Map<String, Set<String>>? changedDocTypes,
    Map<String, String>? statusUpdateSummaries,
  }) {
    return RequestAttentionState(
      statusUpdatedIds: statusUpdatedIds ?? state.statusUpdatedIds,
      docsActionIds: docsActionIds ?? state.docsActionIds,
      newDocTypes: newDocTypes ?? state.newDocTypes,
      changedDocTypes: changedDocTypes ?? state.changedDocTypes,
      statusUpdateSummaries:
          statusUpdateSummaries ?? state.statusUpdateSummaries,
    );
  }

  void markStatusUpdated(String requestId, {String? summary}) {
    final id = requestId.trim();
    if (id.isEmpty) return;
    final nextSummaries = Map<String, String>.from(state.statusUpdateSummaries);
    final trimmedSummary = summary?.trim();
    if (trimmedSummary != null && trimmedSummary.isNotEmpty) {
      nextSummaries[id] = trimmedSummary;
    }
    emit(
      _copy(
        statusUpdatedIds: {...state.statusUpdatedIds, id},
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
      _copy(
        statusUpdatedIds: next,
        statusUpdateSummaries: nextSummaries,
      ),
    );
  }

  void markDocsAction(String requestId) {
    final id = requestId.trim();
    if (id.isEmpty || state.docsActionIds.contains(id)) return;
    emit(_copy(docsActionIds: {...state.docsActionIds, id}));
  }

  void clearDocsAction(String requestId) {
    final id = requestId.trim();
    if (id.isEmpty || !state.docsActionIds.contains(id)) return;
    final next = {...state.docsActionIds}..remove(id);
    emit(_copy(docsActionIds: next));
  }

  /// Сравнить текущие файлы с baseline; при первом заходе — только seed.
  Future<void> syncFromFiles(
    String requestId,
    Iterable<CustomsRequestFile> files,
  ) async {
    final id = requestId.trim();
    if (id.isEmpty) return;
    final store = sl<RequestFileSeenStore>();
    final current = store.fingerprintsFromFiles(files);
    final baseline = store.readBaseline(id);

    if (baseline == null) {
      await store.writeBaseline(id, current);
      emit(
        _copy(
          newDocTypes: _withoutRequest(state.newDocTypes, id),
          changedDocTypes: _withoutRequest(state.changedDocTypes, id),
        ),
      );
      return;
    }

    final news = <String>{};
    final changed = <String>{};
    for (final e in current.entries) {
      final prev = baseline[e.key];
      if (prev == null) {
        news.add(e.key);
      } else if (prev != e.value) {
        changed.add(e.key);
      }
    }

    emit(
      _copy(
        newDocTypes: _withRequestSet(state.newDocTypes, id, news),
        changedDocTypes: _withRequestSet(state.changedDocTypes, id, changed),
      ),
    );
  }

  /// Push `changedDocTypes`: новые → red, уже известные → yellow !.
  Future<void> applyPushChangedDocTypes(
    String requestId,
    Iterable<String> docTypes,
    Iterable<CustomsRequestFile> files,
  ) async {
    final id = requestId.trim();
    if (id.isEmpty) return;
    await syncFromFiles(id, files);
    final codes = docTypes
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    if (codes.isEmpty) return;

    final store = sl<RequestFileSeenStore>();
    final baseline = store.readBaseline(id) ?? {};
    final news = {...state.newDocTypesFor(id)};
    final changed = {...state.changedDocTypesFor(id)};
    for (final code in codes) {
      if (baseline.containsKey(code)) {
        changed.add(code);
        news.remove(code);
      } else {
        news.add(code);
      }
    }
    emit(
      _copy(
        newDocTypes: _withRequestSet(state.newDocTypes, id, news),
        changedDocTypes: _withRequestSet(state.changedDocTypes, id, changed),
      ),
    );
  }

  /// Открыли секцию: сразу гасим «новые», жёлтый «!» — через [clearAfter].
  void onSectionOpened({
    required String requestId,
    required Iterable<String> sectionDocTypes,
    required Iterable<CustomsRequestFile> allFiles,
    Duration clearChangedAfter = const Duration(minutes: 1),
  }) {
    final id = requestId.trim();
    if (id.isEmpty) return;
    final codes = sectionDocTypes
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    if (codes.isEmpty) {
      // Пустая секция — нечего гасить.
      return;
    }

    final news = {...state.newDocTypesFor(id)}..removeAll(codes);
    emit(_copy(newDocTypes: _withRequestSet(state.newDocTypes, id, news)));

    // Зафиксировать fingerprint новых (чтобы не вспыхнули снова).
    unawaited(_mergeSeen(id, codes, allFiles));

    final timerKey = '$id:${codes.join(',')}';
    _changedClearTimers[timerKey]?.cancel();
    _changedClearTimers[timerKey] = Timer(clearChangedAfter, () {
      _changedClearTimers.remove(timerKey);
      if (isClosed) return;
      final still = {...state.changedDocTypesFor(id)}..removeAll(codes);
      emit(
        _copy(
          changedDocTypes: _withRequestSet(state.changedDocTypes, id, still),
        ),
      );
      unawaited(_mergeSeen(id, codes, allFiles));
    });
  }

  Future<void> _mergeSeen(
    String requestId,
    Set<String> codes,
    Iterable<CustomsRequestFile> allFiles,
  ) async {
    final store = sl<RequestFileSeenStore>();
    final baseline = Map<String, String>.from(store.readBaseline(requestId) ?? {});
    final current = store.fingerprintsFromFiles(allFiles);
    for (final code in codes) {
      final fp = current[code];
      if (fp != null) baseline[code] = fp;
    }
    await store.writeBaseline(requestId, baseline);
  }

  /// Устарело: раньше одна подсветка. Теперь — через [applyPushChangedDocTypes].
  void markFileHighlights(String requestId, Iterable<String> docTypes) {
    final id = requestId.trim();
    if (id.isEmpty) return;
    final codes = docTypes
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    if (codes.isEmpty) return;
    final changed = {...state.changedDocTypesFor(id), ...codes};
    emit(
      _copy(
        changedDocTypes: _withRequestSet(state.changedDocTypes, id, changed),
      ),
    );
  }

  void clearFileHighlights(String requestId) {
    final id = requestId.trim();
    if (id.isEmpty) return;
    final hadNew = state.newDocTypes.containsKey(id);
    final hadChanged = state.changedDocTypes.containsKey(id);
    if (!hadNew && !hadChanged) return;
    emit(
      _copy(
        newDocTypes: _withoutRequest(state.newDocTypes, id),
        changedDocTypes: _withoutRequest(state.changedDocTypes, id),
      ),
    );
  }

  static Map<String, Set<String>> _withRequestSet(
    Map<String, Set<String>> source,
    String id,
    Set<String> codes,
  ) {
    final next = Map<String, Set<String>>.from(source);
    if (codes.isEmpty) {
      next.remove(id);
    } else {
      next[id] = Set<String>.unmodifiable(codes);
    }
    return next;
  }

  static Map<String, Set<String>> _withoutRequest(
    Map<String, Set<String>> source,
    String id,
  ) {
    if (!source.containsKey(id)) return source;
    final next = Map<String, Set<String>>.from(source)..remove(id);
    return next;
  }

  @override
  Future<void> close() {
    for (final t in _changedClearTimers.values) {
      t.cancel();
    }
    _changedClearTimers.clear();
    return super.close();
  }
}
