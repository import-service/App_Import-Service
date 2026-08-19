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

class _StoragePageState extends State<StoragePage> {
  final _storage = sl<StorageRemoteDataSource>();
  bool _loading = true;
  bool _busy = false;
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _expired = const [];
  List<Map<String, dynamic>> _archives = const [];
  List<Map<String, dynamic>> _preview = const [];
  List<Map<String, dynamic>> _importItems = const [];
  final Set<int> _importSelected = <int>{};
  List<int>? _importZipBytes;
  String _importZipName = 'archive.zip';
  final _retentionCtrl = TextEditingController(text: '6');
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  final _fioCtrl = TextEditingController();
  final _placeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
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
    _retentionCtrl.dispose();
    _fromCtrl.dispose();
    _toCtrl.dispose();
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

  Future<void> _loadPreview() async {
    setState(() => _busy = true);
    try {
      final items = await _storage.previewPeriod(
        periodFrom: _fromCtrl.text.trim(),
        periodTo: _toCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _preview = items);
      AppSnackBars.showSuccess('Заявок за период: ${items.length}', context: context);
    } catch (e) {
      if (!mounted) return;
      AppSnackBars.showError('$e', context: context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportZip() async {
    final fio = _fioCtrl.text.trim();
    if (fio.isEmpty) {
      AppSnackBars.showError('Укажите ФИО кто архивирует', context: context);
      return;
    }
    setState(() => _busy = true);
    try {
      final place = _placeCtrl.text.trim();
      final r = await _storage.exportZip(
        periodFrom: _fromCtrl.text.trim(),
        periodTo: _toCtrl.text.trim(),
        archivedByName: fio,
        archiveLocation: place.isEmpty ? null : place,
      );
      if (!mounted) return;
      if (place.isNotEmpty) {
        await sl<SharedPreferences>().setString(_kArchiveLocationLastKey, place);
      }
      if (!mounted) return;
      saveBytesAsFile(Uint8List.fromList(r.bytes), r.filename);
      AppSnackBars.showSuccess('ZIP скачан. Сохраните файл на физноситель.', context: context);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      AppSnackBars.showError('$e', context: context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickImportZip() async {
    final picked = await pickZipFile();
    if (picked == null) return;
    setState(() => _busy = true);
    try {
      final preview = await _storage.importPreview(picked.bytes, picked.name);
      final raw = preview['requests'];
      final items = raw is List
          ? raw.whereType<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _importZipBytes = picked.bytes;
        _importZipName = picked.name;
        _importItems = items;
        _importSelected
          ..clear()
          ..addAll(
            items.map((e) => int.tryParse('${e['id']}') ?? 0).where((id) => id > 0),
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
    if (bytes == null || _importSelected.isEmpty) {
      AppSnackBars.showError('Выберите ZIP и заявки', context: context);
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await _storage.importZip(
        zipBytes: bytes,
        filename: _importZipName,
        requestIds: _importSelected.toList(),
      );
      if (!mounted) return;
      AppSnackBars.showSuccess('Восстановлено: ${r['restored'] ?? 0}', context: context);
      setState(() {
        _importZipBytes = null;
        _importItems = const [];
        _importSelected.clear();
      });
      await _reload();
    } catch (e) {
      if (!mounted) return;
      AppSnackBars.showError('$e', context: context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _purgeMarked() async {
    setState(() => _busy = true);
    try {
      final r = await _storage.purgeMarkedArchives();
      if (!mounted) return;
      AppSnackBars.showSuccess(
        'Очищено заявок (файлы сняты): ${r['purged'] ?? 0}',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final stats = _stats ?? {};
    final stale = stats['staleOutbound'];
    final staleList = stale is List ? stale.whereType<Map<String, dynamic>>().toList() : <Map<String, dynamic>>[];

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Хранилище файлов', style: theme.textTheme.titleLarge),
          const Gap(8),
          Text(
            'Файлы заявок хранятся на сервере. Закрытые заявки удаляются автоматически по сроку.',
            style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
          const Gap(20),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _row('Папка uploads', '${stats['uploadsPath'] ?? '—'}'),
                const Gap(10),
                _row('Занято файлами', _fmtBytes(stats['uploadsBytes'])),
                const Gap(10),
                _row('Диск всего', _fmtBytes(stats['diskTotalBytes'])),
                const Gap(10),
                _row('Свободно на диске', _fmtBytes(stats['diskFreeBytes'])),
              ],
            ),
          ),
          const Gap(16),
          Text('Архив заявок на физноситель', style: theme.textTheme.titleMedium),
          const Gap(8),
          Text(
            'Общий чат организации не архивируется. Период — не больше 3 месяцев. '
            'Путь физносителя необязателен; последнее значение подставляется автоматически. '
            'Скачанный ZIP сразу не удаляет файлы с сервера.',
            style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
          const Gap(12),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _fromCtrl,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Период с',
                    border: OutlineInputBorder(),
                  ),
                  onTap: _busy ? null : () => _pickDate(_fromCtrl),
                ),
                const Gap(10),
                TextField(
                  controller: _toCtrl,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Период по',
                    border: OutlineInputBorder(),
                  ),
                  onTap: _busy ? null : () => _pickDate(_toCtrl),
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
                  onPressed: _busy ? null : _loadPreview,
                  child: const Text('Показать заявки за период'),
                ),
                const Gap(8),
                FilledButton(
                  onPressed: _busy ? null : _exportZip,
                  child: const Text('Скачать ZIP и пометить'),
                ),
                if (_preview.isNotEmpty) ...[
                  const Gap(10),
                  Text('К выгрузке: ${_preview.length}', style: theme.textTheme.bodySmall),
                  for (final p in _preview.take(12))
                    Text(
                      '№${p['id']}  ${p['vin'] ?? ''}  ${p['ownerFullName'] ?? ''}',
                      style: theme.textTheme.bodySmall,
                    ),
                  if (_preview.length > 12)
                    Text('… и ещё ${_preview.length - 12}', style: theme.textTheme.bodySmall),
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
                const Gap(8),
                OutlinedButton(
                  onPressed: _busy ? null : _pickImportZip,
                  child: const Text('Выбрать ZIP'),
                ),
                if (_importItems.isNotEmpty) ...[
                  const Gap(8),
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
                  FilledButton(
                    onPressed: _busy ? null : _runImport,
                    child: const Text('Импортировать выбранные'),
                  ),
                ],
                const Gap(8),
                OutlinedButton(
                  onPressed: _busy ? null : _purgeMarked,
                  child: const Text('Снять с сервера уже выгруженное'),
                ),
              ],
            ),
          ),
          if (_archives.isNotEmpty) ...[
            const Gap(12),
            Text('Кто архивировал и куда', style: theme.textTheme.titleSmall),
            const Gap(8),
            for (final a in _archives)
              _card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${a['archivedByName'] ?? '—'} · ${a['adminLogin'] ?? ''}'),
                    Text(
                      '${a['archiveLocation'] ?? ''}',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      '${a['periodFrom']} — ${a['periodTo']} · заявок: ${a['requestCount']}',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
          ],
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
