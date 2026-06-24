import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:import_service_admin/core/di/injection_container.dart';
import 'package:import_service_admin/core/theme/app_theme.dart';
import 'package:import_service_admin/core/ui/app_snackbars.dart';
import 'package:import_service_admin/data/datasources/remote/storage_remote_data_source.dart';

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
  final _retentionCtrl = TextEditingController(text: '6');

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _retentionCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final stats = await _storage.fetchStats();
      final expired = await _storage.fetchExpiredClosed();
      if (!mounted) return;
      _retentionCtrl.text = '${stats['retentionMonths'] ?? 6}';
      setState(() {
        _stats = stats;
        _expired = expired;
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
