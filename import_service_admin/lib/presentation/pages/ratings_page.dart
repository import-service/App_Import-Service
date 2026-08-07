import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:import_service_admin/core/di/injection_container.dart';
import 'package:import_service_admin/core/theme/app_theme.dart';
import 'package:import_service_admin/core/ui/server_error_ui.dart';
import 'package:import_service_admin/domain/entities/customs_request.dart';
import 'package:import_service_admin/domain/repositories/customs_requests_repository.dart';
import 'package:import_service_admin/presentation/widgets/requests/request_list_card.dart';

/// Список заявок с оценкой клиента (для руководства).
class RatingsPage extends StatefulWidget {
  const RatingsPage({super.key});

  @override
  State<RatingsPage> createState() => _RatingsPageState();
}

class _RatingsPageState extends State<RatingsPage> {
  Future<({List<CustomsRequest> items, int total})>? _future;
  int? _ratingMaxFilter;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = sl<CustomsRequestsRepository>().listRequests(
        limit: 200,
        hasRating: true,
        ratingMax: _ratingMaxFilter,
      );
    });
  }

  void _openDetail(CustomsRequest item) {
    context.push('/requests/${Uri.encodeComponent(item.id)}');
  }

  @override
  Widget build(BuildContext context) {
    final future = _future;
    if (future == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Фильтр:'),
              ChoiceChip(
                label: const Text('Все оценки'),
                selected: _ratingMaxFilter == null,
                onSelected: (_) {
                  setState(() => _ratingMaxFilter = null);
                  _reload();
                },
              ),
              ChoiceChip(
                label: const Text('≤ 3 ★'),
                selected: _ratingMaxFilter == 3,
                onSelected: (_) {
                  setState(() => _ratingMaxFilter = 3);
                  _reload();
                },
              ),
            ],
          ),
        ),
        const Gap(8),
        Expanded(
          child: FutureBuilder<({List<CustomsRequest> items, int total})>(
            future: future,
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
              final data = snapshot.data;
              final items = data?.items ?? const <CustomsRequest>[];
              if (items.isEmpty) {
                return Center(
                  child: Text(
                    'Пока нет оценок от клиентов',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Gap(10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return RequestListCard(
                      item: item,
                      sending: false,
                      onOpenDetail: () => _openDetail(item),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
