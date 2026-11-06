import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_admin/core/di/injection_container.dart';
import 'package:import_service_admin/core/error/exceptions.dart';
import 'package:import_service_admin/core/theme/app_theme.dart';
import 'package:import_service_admin/core/ui/server_error_ui.dart';
import 'package:import_service_admin/data/datasources/remote/auth_attempts_remote_data_source.dart';

class AuthAttemptsPage extends StatefulWidget {
  const AuthAttemptsPage({super.key});

  @override
  State<AuthAttemptsPage> createState() => _AuthAttemptsPageState();
}

class _AuthAttemptsPageState extends State<AuthAttemptsPage> {
  final _searchController = TextEditingController();
  bool _loading = true;
  String? _error;
  int _total = 0;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await sl<AuthAttemptsRemoteDataSource>().fetchLatest(
        limit: 100,
        query: _searchController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _total = page.total;
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Поиск',
                    prefixIcon: Icon(Icons.search),
                    hintText: 'логин или компания…',
                  ),
                  onSubmitted: (_) => _load(),
                ),
              ),
              const Gap(8),
              FilledButton(onPressed: _load, child: const Text('Найти')),
            ],
          ),
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
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
            'Попытки входа в МП за 30 дн. · всего: $_total',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const Gap(4),
          Text(
            'Успешные входы и отказы (неверный логин или пароль). Хранятся 30 дней.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const Gap(12),
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: Text('Попыток входа нет')),
            )
          else
            for (final row in _items) ...[
              _AttemptTile(row: row),
              const Gap(8),
            ],
        ],
      ),
    );
  }
}

class _AttemptTile extends StatelessWidget {
  const _AttemptTile({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final success = row['success'] == 1 || row['success'] == true;
    final meta = [
      if (row['created_at'] != null) '${row['created_at']}',
      if (row['ip'] != null) '${row['ip']}',
    ].join(' · ');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: ListTile(
        leading: Icon(
          success ? Icons.check_circle_outline : Icons.block,
          color: success ? const Color(0xFF2E7D32) : Colors.red.shade700,
        ),
        title: Text(
          '${row['login'] ?? ''}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          [
            if ('${row['company_name'] ?? ''}'.isNotEmpty)
              '${row['company_name']}',
            if (meta.isNotEmpty) meta,
            if (!success && row['error_code'] != null) '${row['error_code']}',
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
      ),
    );
  }
}
