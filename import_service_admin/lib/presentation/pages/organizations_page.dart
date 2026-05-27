import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_admin/core/di/injection_container.dart';
import 'package:import_service_admin/core/ui/server_error_ui.dart';
import 'package:import_service_admin/domain/entities/organization.dart';
import 'package:import_service_admin/domain/repositories/organizations_repository.dart';

class OrganizationsPage extends StatefulWidget {
  const OrganizationsPage({super.key});

  @override
  State<OrganizationsPage> createState() => _OrganizationsPageState();
}

class _OrganizationsPageState extends State<OrganizationsPage> {
  final _searchController = TextEditingController();
  late Future<({List<Organization> items, int total})> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = sl<OrganizationsRepository>().list(
        limit: 100,
        query: _searchController.text.trim(),
      );
    });
  }

  void _openDetail(Organization org) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(org.companyName.isNotEmpty ? org.companyName : org.login),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _DetailRow('ID', '${org.id}'),
              _DetailRow('1С ID', org.id1c),
              _DetailRow('Логин', org.login),
              _DetailRow('Роль', org.role),
              _DetailRow('Тип', org.orgType),
              _DetailRow('ИНН', org.inn),
              _DetailRow('Телефон', org.phone),
              if (org.isDeleted) const _DetailRow('Статус', 'Удалена'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
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
                    hintText: 'login, ИНН, компания…',
                  ),
                  onSubmitted: (_) => _reload(),
                ),
              ),
              const Gap(8),
              FilledButton(onPressed: _reload, child: const Text('Найти')),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<({List<Organization> items, int total})>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                final panel = buildRetryErrorPanel(
                  error: snapshot.error,
                  onRetry: _reload,
                );
                if (panel != null) return panel;
                return const SizedBox.shrink();
              }

              final items = snapshot.data?.items ?? const [];
              final total = snapshot.data?.total ?? 0;

              if (items.isEmpty) {
                return const Center(child: Text('Организаций не найдено'));
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Всего: $total'),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        _reload();
                        await _future;
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const Gap(8),
                        itemBuilder: (context, index) {
                          final org = items[index];
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFFE0E0E0)),
                            ),
                            child: ListTile(
                              title: Text(
                                org.companyName.isNotEmpty
                                    ? org.companyName
                                    : org.login,
                              ),
                              subtitle: Text(
                                '${org.inn} · ${org.login}',
                              ),
                              trailing: org.isDeleted
                                  ? const Icon(Icons.archive_outlined,
                                      color: Colors.grey)
                                  : const Icon(Icons.chevron_right),
                              onTap: () => _openDetail(org),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
