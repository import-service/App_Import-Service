import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:import_service_app/data/local/request_draft_attachments_space.dart';
import 'package:import_service_app/data/models/request_draft.dart';
import 'package:import_service_app/presentation/bloc/request_draft/request_draft_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Черновики заявок, синхр. с [SharedPreferences], привязаны к userId сессии.
final class RequestDraftCubit extends Cubit<RequestDraftState> {
  RequestDraftCubit(this._prefs, {String? Function()? ownerIdProvider})
    : _ownerIdProvider = ownerIdProvider,
      super(const RequestDraftState(drafts: []));

  static const _prefsKeyBase = 'request_drafts_v1';
  static const _anonymousOwner = 'anon';
  final SharedPreferences _prefs;
  final String? Function()? _ownerIdProvider;

  /// Ключи черновиков в prefs: их нельзя терять при clear() сессионных ключей.
  static bool isDraftsPrefsKey(String key) =>
      key == _prefsKeyBase || key.startsWith('$_prefsKeyBase:');

  String get _ownerKey {
    final owner = (_ownerIdProvider?.call() ?? '').trim();
    return owner.isEmpty ? _anonymousOwner : owner;
  }

  String get _prefsKey => '$_prefsKeyBase:$_ownerKey';

  /// Загрузка с диска черновиков текущего владельца, без файлов (как в прежнем store).
  void reloadFromDisk() {
    emit(RequestDraftState(drafts: _loadDrafts(_prefsKey)));
  }

  List<RequestDraft> _loadDrafts(String key) {
    return _decodeDrafts(_prefs.getString(key));
  }

  List<RequestDraft> _decodeDrafts(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) return const [];
      final list =
          decoded
              .whereType<Map<String, dynamic>>()
              .map(RequestDraft.fromJson)
              .where((d) => d.id.isNotEmpty)
              .toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    } catch (_) {
      return const [];
    }
  }

  /// После входа/восстановления сессии: старые черновики без владельца
  /// привязываются к текущему пользователю, затем грузятся его черновики.
  Future<void> bindToCurrentOwner() async {
    if (_ownerKey != _anonymousOwner) {
      await _migrateLegacyDrafts();
    }
    reloadFromDisk();
  }

  Future<void> _migrateLegacyDrafts() async {
    final raw = _prefs.getString(_prefsKeyBase);
    if (raw == null || raw.isEmpty) return;
    await _prefs.remove(_prefsKeyBase);
    final legacy = _decodeDrafts(raw);
    if (legacy.isEmpty) return;
    final byId = <String, RequestDraft>{
      for (final d in _loadDrafts(_prefsKey)) d.id: d,
    };
    for (final d in legacy) {
      byId.putIfAbsent(d.id, () => d);
    }
    final merged = byId.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _persistList(merged);
  }

  RequestDraft? draftById(String id) {
    for (final d in state.drafts) {
      if (d.id == id) return d;
    }
    return null;
  }

  Future<void> upsert(RequestDraft draft) async {
    final list = state.drafts.where((e) => e.id != draft.id).toList()
      ..add(draft);
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

  /// Сброс состояния в памяти без удаления черновиков с диска (выход из аккаунта).
  void reset() {
    emit(const RequestDraftState(drafts: []));
  }

  /// Полная очистка черновиков текущего владельца (вход в демо).
  Future<void> clearAll() async {
    for (final d in _loadDrafts(_prefsKey)) {
      await RequestDraftAttachmentsSpace.deleteDraftDirectory(d.id);
    }
    emit(const RequestDraftState(drafts: []));
    await _prefs.remove(_prefsKey);
  }

  Future<void> _persist() => _persistList(state.drafts);

  Future<void> _persistList(List<RequestDraft> drafts) async {
    final encoded = jsonEncode(
      drafts.map((e) => e.toJson()).toList(growable: false),
    );
    await _prefs.setString(_prefsKey, encoded);
  }
}
