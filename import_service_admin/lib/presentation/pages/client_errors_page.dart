import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_admin/core/di/injection_container.dart';
import 'package:import_service_admin/core/error/exceptions.dart';
import 'package:import_service_admin/core/theme/app_theme.dart';
import 'package:import_service_admin/core/ui/server_error_ui.dart';
import 'package:import_service_admin/data/datasources/remote/client_errors_remote_data_source.dart';

class ClientErrorsPage extends StatefulWidget {
  const ClientErrorsPage({super.key});

  @override
  State<ClientErrorsPage> createState() => _ClientErrorsPageState();
}

class _ClientErrorsPageState extends State<ClientErrorsPage> {
  bool _loading = true;
  String? _error;
  int _total = 0;
  int _retentionDays = 14;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await sl<ClientErrorsRemoteDataSource>().fetchLatest(limit: 100);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _total = page.total;
        _retentionDays = page.retentionDays;
        _items = page.items;
      });
    } catch (e) {
      if (!mounted) return;
      if (shouldHideErrorForAuth(e)) return;
      setState(() {
        _loading = false;
        _error = e is ServerException ? e.message : e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const Gap(12),
              FilledButton(onPressed: _load, child: const Text('Повторить')),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Ошибки МП за $_retentionDays дн. · всего: $_total',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const Gap(4),
          Text(
            'Сюда попадают FlutterError, uncaught и AppLog.error. Агент смотрит этот список при разборе сбоев.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const Gap(12),
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: Text('Пока ошибок нет')),
            )
          else
            for (final row in _items) ...[
              _ErrorTile(row: row),
              const Gap(8),
            ],
        ],
      ),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  const _ErrorTile({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final fatal = row['fatal'] == true;
    final message = '${row['message'] ?? ''}';
    final stack = '${row['stack'] ?? ''}';
    final meta = [
      if (row['createdAt'] != null) '${row['createdAt']}',
      if (row['login'] != null) '${row['login']}',
      if (row['role'] != null) '${row['role']}',
      if (row['platform'] != null) '${row['platform']}',
      if (row['appVersion'] != null)
        'v${row['appVersion']}+${row['buildNumber'] ?? ''}',
      if (row['tag'] != null) '${row['tag']}',
    ].where((s) => s.trim().isNotEmpty).join(' · ');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: Icon(
          fatal ? Icons.error : Icons.warning_amber_rounded,
          color: fatal ? Colors.red.shade700 : Colors.orange.shade800,
        ),
        title: Text(
          message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          meta,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        children: [
          if ((row['deviceInfo'] ?? '').toString().isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Устройство: ${row['deviceInfo']}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          const Gap(8),
          SelectableText(
            stack.isEmpty ? message : stack,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ],
      ),
    );
  }
}
