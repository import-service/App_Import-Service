import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:import_service_admin/core/di/injection_container.dart';
import 'package:import_service_admin/core/theme/app_theme.dart';
import 'package:import_service_admin/core/ui/server_error_ui.dart';
import 'package:import_service_admin/core/error/exceptions.dart';
import 'package:import_service_admin/data/datasources/remote/store_versions_remote_data_source.dart';
import 'package:import_service_admin/domain/repositories/customs_requests_repository.dart';
import 'package:import_service_admin/domain/repositories/organizations_repository.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int? _requestsTotal;
  int? _newCount;
  int? _orgsTotal;
  String? _error;
  List<Map<String, dynamic>> _storeVersions = const [];
  String? _storeVersionsError;
  bool _scanningStores = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _requestsTotal = null;
      _newCount = null;
      _orgsTotal = null;
      _storeVersionsError = null;
    });
    try {
      final all = await sl<CustomsRequestsRepository>().listRequests(limit: 200);
      final newList = await sl<CustomsRequestsRepository>().listRequests(
        limit: 1,
        status: 'new',
      );
      final orgs = await sl<OrganizationsRepository>().list(limit: 1);
      List<Map<String, dynamic>> stores = const [];
      String? storesErr;
      try {
        stores = await sl<StoreVersionsRemoteDataSource>().fetchLatest();
      } catch (e) {
        storesErr = e is ServerException ? e.message : e.toString();
      }
      if (!mounted) return;
      setState(() {
        _requestsTotal = all.total;
        _newCount = newList.total;
        _orgsTotal = orgs.total;
        _storeVersions = stores;
        _storeVersionsError = storesErr;
      });
    } catch (e) {
      if (!mounted) return;
      if (shouldHideErrorForAuth(e)) return;
      setState(() {
        _error = e is ServerException ? e.message : e.toString();
      });
    }
  }

  Future<void> _scanStores() async {
    if (_scanningStores) return;
    setState(() => _scanningStores = true);
    try {
      final stores = await sl<StoreVersionsRemoteDataSource>().scanNow();
      if (!mounted) return;
      setState(() {
        _storeVersions = stores;
        _storeVersionsError = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сканирование сторов завершено')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ServerException ? e.message : 'Не удалось сканировать сторы',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _scanningStores = false);
    }
  }

  void _goRequests({String? status}) {
    if (status != null && status.isNotEmpty) {
      context.go('/requests?status=${Uri.encodeQueryComponent(status)}');
    } else {
      context.go('/requests');
    }
  }

  void _goOrganizations() {
    context.go('/organizations');
  }

  String _storeLabel(String store) {
    switch (store) {
      case 'google_play':
        return 'Google Play';
      case 'rustore':
        return 'RuStore';
      case 'app_store':
        return 'App Store';
      default:
        return store;
    }
  }

  String _formatStoreVersion(Map<String, dynamic> row) {
    final name = row['versionName']?.toString();
    final code = row['versionCode'];
    if (name != null && name.isNotEmpty) {
      if (code != null) return '$name (build $code)';
      return name;
    }
    if (code != null) return 'build $code';
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const Gap(12),
            FilledButton(onPressed: _load, child: const Text('Повторить')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Обзор',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const Gap(20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _StatCard(
                title: 'Заявки',
                value: _requestsTotal?.toString() ?? '…',
                icon: Icons.assignment_outlined,
                color: AppTheme.primaryBlue,
                onTap: () => _goRequests(),
              ),
              _StatCard(
                title: 'Статус new',
                value: _newCount?.toString() ?? '…',
                subtitle: 'можно отправить в 1С',
                icon: Icons.upload_outlined,
                color: AppTheme.accentRed,
                onTap: () => _goRequests(status: 'new'),
              ),
              _StatCard(
                title: 'Организации',
                value: _orgsTotal?.toString() ?? '…',
                icon: Icons.business_outlined,
                color: const Color(0xFF2E7D32),
                onTap: _goOrganizations,
              ),
            ],
          ),
          const Gap(28),
          Row(
            children: [
              Text(
                'Версии в сторах',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: _scanningStores ? null : _scanStores,
                icon: _scanningStores
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: const Text('Сканировать'),
              ),
            ],
          ),
          const Gap(12),
          if (_storeVersionsError != null)
            Text(
              _storeVersionsError!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.accentRed,
                  ),
            ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_storeVersions.isEmpty)
                    const Text('Нет данных — запустите сканирование')
                  else
                    for (final row in _storeVersions)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                _storeLabel(row['store']?.toString() ?? ''),
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                _formatStoreVersion(row),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                row['status'] == 'error'
                                    ? row['errorMessage']?.toString() ?? 'ошибка'
                                    : row['scannedAt']?.toString() ?? '—',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 28),
                const Gap(12),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                ),
                const Gap(4),
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                if (subtitle != null) ...[
                  const Gap(4),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
