import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:import_service_admin/core/di/injection_container.dart';
import 'package:import_service_admin/core/theme/app_theme.dart';
import 'package:import_service_admin/core/ui/app_snackbars.dart';
import 'package:import_service_admin/core/util/browser_download.dart';
import 'package:import_service_admin/data/datasources/remote/storage_remote_data_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kArchiveLocationLastKey = 'storage_archive_location_last';

class StoragePage extends StatefulWidget {
  const StoragePage({super.key});

  @override
  State<StoragePage> createState() => _StoragePageState();
}

class _StoragePageState extends State<StoragePage> with SingleTickerProviderStateMixin {
  final _storage = sl<StorageRemoteDataSource>();
  late final TabController _tabs;
  bool _loading = true;
  bool _busy = false;
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _expired = const [];
  List<Map<String, dynamic>> _archives = const [];
  Map<String, dynamic>? _eligiblePreview;
  final Set<int> _exportSelected = <int>{};
  ArchiveEligibleFilters _archiveFilters = const ArchiveEligibleFilters();
  bool _testMode = false;
  List<Map<String, dynamic>> _importOrganizations = const [];
  List<Map<String, dynamic>> _importItems = const [];
  final Set<int> _importSelected = <int>{};
  final Set<int> _importOrgChatSelected = <int>{};
  List<int>? _importZipBytes;
  String _importZipName = 'archive.zip';
  String? _importPeriodLabel;
  final _retentionCtrl = TextEditingController(text: '6');
  final _beforeCtrl = TextEditingController();
  final _fioCtrl = TextEditingController();
  final _placeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _beforeCtrl.text = _ymd(DateTime.now().subtract(const Duration(days: 30)));
    _loadSavedArchiveLocation();
    _reload();
  }

  void _loadSavedArchiveLocation() {
    final saved = sl<SharedPreferences>().getString(_kArchiveLocationLastKey);
    if (saved != null && saved.trim().isNotEmpty) {
      _placeCtrl.text = saved.trim();
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _retentionCtrl.dispose();
    _beforeCtrl.dispose();
    _fioCtrl.dispose();
    _placeCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final stats = await _storage.fetchStats();
      final expired = await _storage.fetchExpiredClosed();
      var archives = <Map<String, dynamic>>[];
      try {
        archives = await _storage.fetchArchives();
      } catch (_) {
        archives = const [];
      }
      if (!mounted) return;
      _retentionCtrl.text = '${stats['retentionMonths'] ?? 6}';
      setState(() {
        _stats = stats;
        _expired = expired;
        _archives = archives;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppSnackBars.showError('$e', context: context);
    }
  }

  Future<void> _saveRetention() async {
    final months = int.tryParse(_retentionCtrl.text.trim());
    if (months == null || months < 1 || months > 120) {
      AppSnackBars.showError('Срок: от 1 до 120 месяцев', context: context);
      return;
    }
    setState(() => _busy = true);
    try {
      await _storage.updateRetentionMonths(months);
      if (!mounted) return;
      AppSnackBars.showSuccess('Срок хранения сохранён', context: context);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      AppSnackBars.showError('$e', context: context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _ymd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(ctrl.text) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (picked != null) ctrl.text = _ymd(picked);
  }

  Future<void> _loadEligiblePreview() async {
    setState(() => _busy = true);
    try {
      final preview = await _storage.previewEligible(
        archiveBefore: _beforeCtrl.text.trim(),
        filters: _archiveFilters,
        testMode: _testMode,
      );
      if (!mounted) return;
      final orgsRaw = preview['organizations'];
      final orgs = orgsRaw is List
          ? orgsRaw.whereType<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];
      final ids = <int>{};
      for (final org in orgs) {
        final reqs = org['requests'];
        if (reqs is List) {
          for (final r in reqs.whereType<Map<String, dynamic>>()) {
            final id = int.tryParse('${r['id']}') ?? 0;
            if (id > 0) ids.add(id);
          }
        }
      }
      final flatRaw = preview['items'];
      if (flatRaw is List) {
        for (final r in flatRaw.whereType<Map<String, dynamic>>()) {
          final id = int.tryParse('${r['id']}') ?? 0;
          if (id > 0) ids.add(id);
        }
      }
      setState(() {
        _eligiblePreview = preview;
        _exportSelected
          ..clear()
          ..addAll(ids);
      });
      final count = preview['count'] ?? 0;
      AppSnackBars.showSuccess('Под архив: $count заявок', context: context);
    } catch (e) {
      if (!mounted) return;
      AppSnackBars.showError('$e', context: context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _archiveZip() async {
    final fio = _fioCtrl.text.trim();
    if (fio.isEmpty) {
      AppSnackBars.showError('Укажите ФИО кто архивирует', context: context);
      return;
    }
    if (_exportSelected.isEmpty) {
      AppSnackBars.showError('Выберите заявки или обновите список', context: context);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Архивировать заявки?'),
        content: Text(
          'Будет создан ZIP на сервере (скачивание 24 ч). '
          'Выбрано заявок: ${_exportSelected.length}. '
          'Файлы заявок с сервера удалятся сразу после проверки ZIP.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Архивировать')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      final place = _placeCtrl.text.trim();
      final r = await _storage.archiveExport(
        archiveBefore: _beforeCtrl.text.trim(),
        archivedByName: fio,
        archiveLocation: place.isEmpty ? null : place,
        requestIds: _exportSelected.toList(),
        filters: _archiveFilters,
        testMode: _testMode,
      );
      if (!mounted) return;
      if (place.isNotEmpty) {
        await sl<SharedPreferences>().setString(_kArchiveLocationLastKey, place);
      }
      if (!mounted) return;
      final archiveId = int.tryParse('${r['archiveId']}') ?? 0;
      if (archiveId > 0) {
        try {
          final dl = await _storage.downloadArchiveZip(archiveId);
          if (!mounted) return;
          saveBytesAsFile(Uint8List.fromList(dl.bytes), dl.filename);
        } catch (_) {
          if (!mounted) return;
          AppSnackBars.showError(
            'Архив №$archiveId создан на сервере; скачайте из вкладки «История»',
            context: context,
          );
        }
      }
      if (!mounted) return;
      AppSnackBars.showSuccess(
        'Архив №${r['archiveId']} · заявок: ${r['requestCount']}. '
        'Повторное скачивание — 24 ч.',
        context: context,
      );
      setState(() {
        _eligiblePreview = null;
        _exportSelected.clear();
      });
      await _reload();
      _tabs.animateTo(2);
    } catch (e) {
      if (!mounted) return;
      AppSnackBars.showError('$e', context: context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setTestMode(bool enabled) async {
    if (enabled == _testMode) return;
    if (!enabled) {
      setState(() => _busy = true);
      try {
        await _storage.cleanupArchiveTestMode();
        if (!mounted) return;
        setState(() {
          _testMode = false;
          _eligiblePreview = null;
          _exportSelected.clear();
        });
        AppSnackBars.showSuccess('Тестовые заявки удалены', context: context);
      } catch (e) {
        if (!mounted) return;
        AppSnackBars.showError('$e', context: context);
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }
    setState(() {
      _testMode = true;
      _eligiblePreview = null;
      _exportSelected.clear();
    });
  }

  Future<void> _seedTestRequests() async {
    if (!_testMode) return;
    setState(() => _busy = true);
    try {
      final r = await _storage.seedArchiveTestMode();
      if (!mounted) return;
      final preview = await _storage.previewEligible(
        archiveBefore: _beforeCtrl.text.trim(),
        filters: _archiveFilters,
        testMode: true,
      );
      if (!mounted) return;
      final orgsRaw = preview['organizations'];
      final orgs = orgsRaw is List
          ? orgsRaw.whereType<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];
      final ids = <int>{};
      for (final org in orgs) {
        final reqs = org['requests'];
        if (reqs is List) {
          for (final row in reqs.whereType<Map<String, dynamic>>()) {
            final id = int.tryParse('${row['id']}') ?? 0;
            if (id > 0) ids.add(id);
          }
        }
      }
      setState(() {
        _eligiblePreview = preview;
        _exportSelected
          ..clear()
          ..addAll(ids);
      });
      AppSnackBars.showSuccess(
        'Создано тестовых заявок: ${r['count'] ?? 0}. В списке: ${preview['count'] ?? 0}',
        context: context,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBars.showError('$e', context: context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadHistoryArchive(int archiveId) async {
    setState(() => _busy = true);
    try {
      final dl = await _storage.downloadArchiveZip(archiveId);
      if (!mounted) return;
      saveBytesAsFile(Uint8List.fromList(dl.bytes), dl.filename);
      AppSnackBars.showSuccess('ZIP скачан', context: context);
    } catch (e) {
      if (!mounted) return;
      AppSnackBars.showError('$e', context: context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _selectAllExportForOrg(Map<String, dynamic> org, bool selected) {
    final requests = org['requests'];
    setState(() {
      if (requests is List) {
        for (final r in requests.whereType<Map<String, dynamic>>()) {
          final id = int.tryParse('${r['id']}') ?? 0;
          if (id <= 0) continue;
          if (selected) {
            _exportSelected.add(id);
          } else {
            _exportSelected.remove(id);
          }
        }
      }
    });
  }

  List<Map<String, dynamic>> get _exportOrganizations {
    final orgs = _eligiblePreview?['organizations'];
    if (orgs is List) {
      return orgs.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  Widget _buildArchiveFilterSwitches() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Только status=closed'),
          value: _archiveFilters.requireClosed,
          onChanged: _busy
              ? null
              : (v) => setState(() {
                    _archiveFilters = ArchiveEligibleFilters(
                      requireClosed: v,
                      inactivityDays: _archiveFilters.inactivityDays,
                      checkRequestUpdated: _archiveFilters.checkRequestUpdated,
                      checkChatMessages: _archiveFilters.checkChatMessages,
                      checkFiles: _archiveFilters.checkFiles,
                      checkOrgSessions: _archiveFilters.checkOrgSessions,
                    );
                  }),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Без правок заявки ${_archiveFilters.inactivityDays} дн.'),
          value: _archiveFilters.checkRequestUpdated,
          onChanged: _busy
              ? null
              : (v) => setState(() {
                    _archiveFilters = ArchiveEligibleFilters(
                      requireClosed: _archiveFilters.requireClosed,
                      inactivityDays: _archiveFilters.inactivityDays,
                      checkRequestUpdated: v,
                      checkChatMessages: _archiveFilters.checkChatMessages,
                      checkFiles: _archiveFilters.checkFiles,
                      checkOrgSessions: _archiveFilters.checkOrgSessions,
                    );
                  }),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Без сообщений чата ${_archiveFilters.inactivityDays} дн.'),
          value: _archiveFilters.checkChatMessages,
          onChanged: _busy
              ? null
              : (v) => setState(() {
                    _archiveFilters = ArchiveEligibleFilters(
                      requireClosed: _archiveFilters.requireClosed,
                      inactivityDays: _archiveFilters.inactivityDays,
                      checkRequestUpdated: _archiveFilters.checkRequestUpdated,
                      checkChatMessages: v,
                      checkFiles: _archiveFilters.checkFiles,
                      checkOrgSessions: _archiveFilters.checkOrgSessions,
                    );
                  }),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Без новых файлов ${_archiveFilters.inactivityDays} дн.'),
          value: _archiveFilters.checkFiles,
          onChanged: _busy
              ? null
              : (v) => setState(() {
                    _archiveFilters = ArchiveEligibleFilters(
                      requireClosed: _archiveFilters.requireClosed,
                      inactivityDays: _archiveFilters.inactivityDays,
                      checkRequestUpdated: _archiveFilters.checkRequestUpdated,
                      checkChatMessages: _archiveFilters.checkChatMessages,
                      checkFiles: v,
                      checkOrgSessions: _archiveFilters.checkOrgSessions,
                    );
                  }),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Без входов org ${_archiveFilters.inactivityDays} дн.'),
          value: _archiveFilters.checkOrgSessions,
          onChanged: _busy
              ? null
              : (v) => setState(() {
                    _archiveFilters = ArchiveEligibleFilters(
                      requireClosed: _archiveFilters.requireClosed,
                      inactivityDays: _archiveFilters.inactivityDays,
                      checkRequestUpdated: _archiveFilters.checkRequestUpdated,
                      checkChatMessages: _archiveFilters.checkChatMessages,
                      checkFiles: _archiveFilters.checkFiles,
                      checkOrgSessions: v,
                    );
                  }),
        ),
      ],
    );
  }

  Widget _buildExportOrgTree() {
    final orgs = _exportOrganizations;
    if (orgs.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final org in orgs) _buildExportOrgTile(org),
      ],
    );
  }

  Widget _buildExportOrgTile(Map<String, dynamic> org) {
    final oid = int.tryParse('${org['organizationId']}') ?? 0;
    final name = '${org['organizationName'] ?? 'Org #$oid'}';
    final requests = org['requests'] is List
        ? (org['requests'] as List).whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];
    final reqIds = requests.map((r) => int.tryParse('${r['id']}') ?? 0).where((id) => id > 0);
    final allSelected = reqIds.isNotEmpty && reqIds.every(_exportSelected.contains);

    return ExpansionTile(
      title: Text(name),
      subtitle: Text('${requests.length} заявок · общий чат в ZIP'),
      leading: Checkbox(
        value: allSelected,
        tristate: true,
        onChanged: _busy ? null : (v) => _selectAllExportForOrg(org, v == true),
      ),
      children: [
        for (final r in requests)
          CheckboxListTile(
            dense: true,
            value: _exportSelected.contains(int.tryParse('${r['id']}') ?? -1),
            title: Text('№${r['id']}  ${r['vin'] ?? ''}'),
            subtitle: Text(
              '${r['ownerFullName'] ?? ''} · ${_fmtBytes(r['storageBytes'])}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            onChanged: _busy
                ? null
                : (v) {
                    final id = int.tryParse('${r['id']}') ?? 0;
                    if (id <= 0) return;
                    setState(() {
                      if (v == true) {
                        _exportSelected.add(id);
                      } else {
                        _exportSelected.remove(id);
                      }
                    });
                  },
          ),
      ],
    );
  }

  void _selectAllImportForOrg(Map<String, dynamic> org, bool selected) {
    final oid = int.tryParse('${org['organizationId']}') ?? 0;
    final requests = org['requests'];
    setState(() {
      if (selected) {
        if (oid > 0 && _orgHasChat(org)) _importOrgChatSelected.add(oid);
        if (requests is List) {
          for (final r in requests.whereType<Map<String, dynamic>>()) {
            final id = int.tryParse('${r['id']}') ?? 0;
            if (id > 0) _importSelected.add(id);
          }
        }
      } else {
        if (oid > 0) _importOrgChatSelected.remove(oid);
        if (requests is List) {
          for (final r in requests.whereType<Map<String, dynamic>>()) {
            final id = int.tryParse('${r['id']}') ?? 0;
            if (id > 0) _importSelected.remove(id);
          }
        }
      }
    });
  }

  bool _orgHasChat(Map<String, dynamic> org) {
    final chat = org['orgChat'];
    if (chat is Map<String, dynamic>) {
      return chat['available'] == true;
    }
    return true;
  }

  Future<void> _pickImportZip() async {
    final picked = await pickZipFile();
    if (picked == null) return;
    setState(() => _busy = true);
    try {
      final preview = await _storage.importPreview(picked.bytes, picked.name);
      final orgsRaw = preview['organizations'];
      final orgs = orgsRaw is List
          ? orgsRaw.whereType<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];
      final flatRaw = preview['requests'];
      final flat = flatRaw is List
          ? flatRaw.whereType<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _importZipBytes = picked.bytes;
        _importZipName = picked.name;
        _importPeriodLabel = preview['periodLabel']?.toString();
        _importOrganizations = orgs;
        _importItems = flat;
        _importSelected
          ..clear()
          ..addAll(
            flat.map((e) => int.tryParse('${e['id']}') ?? 0).where((id) => id > 0),
          );
        _importOrgChatSelected
          ..clear()
          ..addAll(
            orgs
                .map((o) => int.tryParse('${o['organizationId']}') ?? 0)
                .where((id) => id > 0),
          );
      });
    } catch (e) {
      if (!mounted) return;
      AppSnackBars.showError('$e', context: context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runImport() async {
    final bytes = _importZipBytes;
    if (bytes == null || (_importSelected.isEmpty && _importOrgChatSelected.isEmpty)) {
      AppSnackBars.showError('Выберите ZIP и что импортировать', context: context);
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await _storage.importZip(
        zipBytes: bytes,
        filename: _importZipName,
        requestIds: _importSelected.toList(),
        orgChatOrgIds: _importOrgChatSelected.toList(),
      );
      if (!mounted) return;
      AppSnackBars.showSuccess(
        'Заявок: ${r['restored'] ?? 0}, общих чатов: ${r['orgChatsRestored'] ?? 0}',
        context: context,
      );
      setState(() {
        _importZipBytes = null;
        _importItems = const [];
        _importOrganizations = const [];
        _importSelected.clear();
        _importOrgChatSelected.clear();
        _importPeriodLabel = null;
      });
      await _reload();
    } catch (e) {
      if (!mounted) return;
      AppSnackBars.showError('$e', context: context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _purgeExpired() async {
    setState(() => _busy = true);
    try {
      final r = await _storage.purgeExpired();
      if (!mounted) return;
      AppSnackBars.showSuccess(
        'Удалено заявок: ${r['deleted'] ?? 0}, файлов: ${r['filesRemoved'] ?? 0}',
        context: context,
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      AppSnackBars.showError('$e', context: context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteRequest(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить заявку?'),
        content: Text('Заявка №$id и все файлы будут удалены безвозвратно.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.accentRed),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await _storage.deleteRequest(id);
      if (!mounted) return;
      AppSnackBars.showSuccess('Заявка $id удалена', context: context);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      AppSnackBars.showError('$e', context: context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _fmtBytes(dynamic v) {
    final n = v is int ? v : int.tryParse('$v') ?? 0;
    if (n < 1024) return '$n Б';
    if (n < 1024 * 1024) return '${(n / 1024).toStringAsFixed(1)} КБ';
    if (n < 1024 * 1024 * 1024) {
      return '${(n / (1024 * 1024)).toStringAsFixed(1)} МБ';
    }
    return '${(n / (1024 * 1024 * 1024)).toStringAsFixed(2)} ГБ';
  }

  Widget _buildImportOrgTree() {
    if (_importOrganizations.isEmpty && _importItems.isEmpty) {
      return const SizedBox.shrink();
    }
    if (_importOrganizations.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final p in _importItems)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _importSelected.contains(int.tryParse('${p['id']}') ?? -1),
              title: Text('№${p['id']}  ${p['vin'] ?? ''}'),
              onChanged: _busy
                  ? null
                  : (v) {
                      final id = int.tryParse('${p['id']}') ?? 0;
                      if (id <= 0) return;
                      setState(() {
                        if (v == true) {
                          _importSelected.add(id);
                        } else {
                          _importSelected.remove(id);
                        }
                      });
                    },
            ),
        ],
      );
    }

    return Column(
      children: [
        for (final org in _importOrganizations) _buildImportOrgTile(org),
      ],
    );
  }

  Widget _buildImportOrgTile(Map<String, dynamic> org) {
    final oid = int.tryParse('${org['organizationId']}') ?? 0;
    final name = '${org['organizationName'] ?? 'Org #$oid'}';
    final requests = org['requests'] is List
        ? (org['requests'] as List).whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];
    final reqIds = requests.map((r) => int.tryParse('${r['id']}') ?? 0).where((id) => id > 0);
    final allReqSelected = reqIds.isNotEmpty && reqIds.every(_importSelected.contains);
    final chatSelected = oid > 0 && _importOrgChatSelected.contains(oid);
    final allSelected = allReqSelected && (!_orgHasChat(org) || chatSelected);

    return ExpansionTile(
      title: Text(name),
      subtitle: Text('${requests.length} заявок'),
      leading: Checkbox(
        value: allSelected,
        tristate: true,
        onChanged: _busy
            ? null
            : (v) {
                _selectAllImportForOrg(org, v == true);
              },
      ),
      children: [
        if (_orgHasChat(org) && oid > 0)
          CheckboxListTile(
            dense: true,
            value: chatSelected,
            title: const Text('Общий чат'),
            onChanged: _busy
                ? null
                : (v) {
                    setState(() {
                      if (v == true) {
                        _importOrgChatSelected.add(oid);
                      } else {
                        _importOrgChatSelected.remove(oid);
                      }
                    });
                  },
          ),
        for (final r in requests)
          CheckboxListTile(
            dense: true,
            value: _importSelected.contains(int.tryParse('${r['id']}') ?? -1),
            title: Text('№${r['id']}  ${r['vin'] ?? ''}  ${r['ownerFullName'] ?? ''}'),
            onChanged: _busy
                ? null
                : (v) {
                    final id = int.tryParse('${r['id']}') ?? 0;
                    if (id <= 0) return;
                    setState(() {
                      if (v == true) {
                        _importSelected.add(id);
                      } else {
                        _importSelected.remove(id);
                      }
                    });
                  },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final stats = _stats ?? {};
    final diskLow = stats['diskLow'] == true;
    final stale = stats['staleOutbound'];
    final staleList = stale is List ? stale.whereType<Map<String, dynamic>>().toList() : <Map<String, dynamic>>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text('Хранилище', style: theme.textTheme.titleLarge),
        ),
        TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Информация'),
            Tab(text: 'Архивация'),
            Tab(text: 'История'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (diskLow)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                'Мало места на диске — рекомендуется архивация.',
                                style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.accentRed),
                              ),
                            ),
                          _row('Файлы заявок', _fmtBytes(stats['uploadsBytes'])),
                          const Gap(8),
                          _row('Вложения чатов', _fmtBytes(stats['chatAttachmentsBytes'])),
                          const Gap(8),
                          _row('Всего данных', _fmtBytes(stats['dataBytes'] ?? stats['uploadsBytes'])),
                          const Gap(8),
                          _row('Свободно на диске', _fmtBytes(stats['diskFreeBytes'])),
                          const Gap(8),
                          _row('Диск всего', _fmtBytes(stats['diskTotalBytes'])),
                        ],
                      ),
                    ),
                    const Gap(16),
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Автоудаление (только closed)', style: theme.textTheme.titleSmall),
                          const Gap(10),
                          TextField(
                            controller: _retentionCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(
                              labelText: 'Месяцев после закрытия',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const Gap(12),
                          FilledButton(
                            onPressed: _busy ? null : _saveRetention,
                            child: const Text('Сохранить срок'),
                          ),
                          const Gap(8),
                          OutlinedButton(
                            onPressed: _busy ? null : _purgeExpired,
                            child: const Text('Удалить просроченные closed сейчас'),
                          ),
                        ],
                      ),
                    ),
                    if (staleList.isNotEmpty) ...[
                      const Gap(16),
                      _card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Не отправлено в 1С более суток',
                              style: theme.textTheme.titleSmall?.copyWith(color: AppTheme.accentRed),
                            ),
                            const Gap(8),
                            for (final s in staleList)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  '№${s['requestId']} — create: ${s['createPending'] == true ? 'да' : 'нет'}, '
                                  'update: ${s['updatePending'] == true ? 'да' : 'нет'}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const Gap(16),
                    Text('Просроченные closed (${_expired.length})', style: theme.textTheme.titleMedium),
                    const Gap(8),
                    if (_expired.isEmpty)
                      Text('Нет заявок для автоудаления', style: theme.textTheme.bodyMedium)
                    else
                      for (final row in _expired)
                        _card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('№${row['id']} — ${row['ownerFullName'] ?? ''}'),
                                    Text(
                                      'VIN ${row['vin'] ?? '—'} · ${_fmtBytes(row['bytes'])}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Удалить',
                                onPressed: _busy ? null : () => _deleteRequest('${row['id']}'),
                                icon: const Icon(Icons.delete_outline, color: AppTheme.accentRed),
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'ZIP сохраняется на сервере 24 ч; файлы заявок удаляются сразу после проверки. '
                    'Общий чат org попадает в ZIP и снимается, когда у org не осталось файлов на сервере.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                  ),
                  const Gap(12),
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Тестовый режим'),
                          subtitle: Text(
                            _testMode
                                ? 'В списке только тестовые заявки (МП/1С их не видят)'
                                : 'Обычный режим: только боевые заявки',
                            style: theme.textTheme.bodySmall,
                          ),
                          value: _testMode,
                          onChanged: _busy ? null : _setTestMode,
                        ),
                        FilledButton(
                          onPressed: (!_testMode || _busy) ? null : _seedTestRequests,
                          child: const Text('Создать тестовые заявки'),
                        ),
                      ],
                    ),
                  ),
                  const Gap(12),
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Фильтры отбора', style: theme.textTheme.titleSmall),
                        _buildArchiveFilterSwitches(),
                      ],
                    ),
                  ),
                  const Gap(12),
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _beforeCtrl,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Созданы до (archiveBefore)',
                            border: OutlineInputBorder(),
                          ),
                          onTap: _busy ? null : () => _pickDate(_beforeCtrl),
                        ),
                        const Gap(10),
                        TextField(
                          controller: _fioCtrl,
                          decoration: const InputDecoration(
                            labelText: 'ФИО кто архивирует',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const Gap(10),
                        TextField(
                          controller: _placeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Место / путь физносителя (необязательно)',
                            hintText: r'D:\Архив\2026-Q1',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const Gap(12),
                        OutlinedButton(
                          onPressed: _busy ? null : _loadEligiblePreview,
                          child: const Text('Обновить список заявок'),
                        ),
                        if (_eligiblePreview != null) ...[
                          const Gap(10),
                          Text(
                            'Найдено: ${_eligiblePreview!['count'] ?? 0}, выбрано: ${_exportSelected.length}',
                            style: theme.textTheme.bodySmall,
                          ),
                          const Gap(8),
                          _buildExportOrgTree(),
                          const Gap(8),
                          FilledButton(
                            onPressed: _busy ? null : _archiveZip,
                            child: const Text('Архивировать выбранное'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Gap(12),
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Импорт ZIP', style: theme.textTheme.titleSmall),
                        if (_importPeriodLabel != null) ...[
                          const Gap(4),
                          Text('Период архива: $_importPeriodLabel', style: theme.textTheme.bodySmall),
                        ],
                        const Gap(8),
                        OutlinedButton(
                          onPressed: _busy ? null : _pickImportZip,
                          child: const Text('Выбрать ZIP'),
                        ),
                        if (_importOrganizations.isNotEmpty || _importItems.isNotEmpty) ...[
                          const Gap(8),
                          _buildImportOrgTree(),
                          FilledButton(
                            onPressed: _busy ? null : _runImport,
                            child: const Text('Импортировать выбранное'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              RefreshIndicator(
                onRefresh: _reload,
                child: _archives.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text('Архивов пока нет', style: theme.textTheme.bodyLarge),
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          for (final a in _archives) _buildHistoryArchiveTile(a),
                        ],
                      ),
              ),
            ],
          ),
        ),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
      ],
    );
  }

  Widget _buildHistoryArchiveTile(Map<String, dynamic> a) {
    final theme = Theme.of(context);
    final id = int.tryParse('${a['id']}') ?? 0;
    final canDownload = a['downloadAvailable'] == true;
    final orgs = a['organizations'];
    final orgList = orgs is List ? orgs.whereType<Map<String, dynamic>>().toList() : <Map<String, dynamic>>[];

    return _card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        title: Text('№$id · ${a['zipFileName'] ?? a['periodLabel'] ?? ''}'),
        subtitle: Text(
          '${a['archivedByName'] ?? '—'} · ${a['createdAt'] ?? ''}',
          style: theme.textTheme.bodySmall,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Место: ${a['archiveLocation'] ?? '—'}', style: theme.textTheme.bodySmall),
                Text(
                  'Заявок: ${a['requestCount']} · ${_fmtBytes(a['zipSizeBytes'])}',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  canDownload
                      ? 'Скачивание до: ${a['zipExpiresAt'] ?? '24 ч'}'
                      : 'Файл на сервере: ${a['downloadState'] ?? 'недоступен'}',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                ),
                const Gap(8),
                if (canDownload && id > 0)
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _downloadHistoryArchive(id),
                    icon: const Icon(Icons.download),
                    label: const Text('Скачать ZIP'),
                  ),
                if (orgList.isNotEmpty) ...[
                  const Gap(8),
                  Text('Состав', style: theme.textTheme.titleSmall),
                  for (final org in orgList)
                    Text(
                      '${org['organizationName'] ?? org['organizationId']}: '
                      '${(org['requests'] as List?)?.length ?? 0} заявок',
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsetsGeometry? margin}) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.requestCardBorder),
      ),
      child: child,
    );
  }

  Widget _row(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
        ),
        Expanded(
          flex: 3,
          child: SelectableText(value),
        ),
      ],
    );
  }
}
