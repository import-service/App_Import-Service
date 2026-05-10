import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:import_service_app/data/local/request_draft_attachments_space.dart';
import 'package:import_service_app/data/models/request_draft.dart';
import 'package:import_service_app/presentation/bloc/request_draft/request_draft_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Черновики заявок, синхр. с [SharedPreferences].
final class RequestDraftCubit extends Cubit<RequestDraftState> {
  RequestDraftCubit(this._prefs) : super(const RequestDraftState(drafts: []));

  static const _prefsKey = 'request_drafts_v1';
  final SharedPreferences _prefs;

  /// Загрузка с диска, без файлов (как в прежнем store).
  void reloadFromDisk() {
    final raw = _prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      emit(const RequestDraftState(drafts: []));
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) {
        emit(const RequestDraftState(drafts: []));
        return;
      }
      final list = decoded
          .whereType<Map<String, dynamic>>()
          .map(RequestDraft.fromJson)
          .where((d) => d.id.isNotEmpty)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      emit(RequestDraftState(drafts: list));
    } catch (_) {
      emit(const RequestDraftState(drafts: []));
    }
  }

  RequestDraft? draftById(String id) {
    for (final d in state.drafts) {
      if (d.id == id) return d;
    }
    return null;
  }

  Future<void> upsert(RequestDraft draft) async {
    final list = state.drafts.where((e) => e.id != draft.id).toList()..add(draft);
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    emit(RequestDraftState(drafts: list));
    await _persist();
  }

  Future<void> delete(String id) async {
    await RequestDraftAttachmentsSpace.deleteDraftDirectory(id);
    final list = state.drafts.where((e) => e.id != id).toList();
    emit(RequestDraftState(drafts: list));
    await _persist();
  }

  Future<void> _persist() async {
    final encoded =
        jsonEncode(state.drafts.map((e) => e.toJson()).toList(growable: false));
    await _prefs.setString(_prefsKey, encoded);
  }
}
