import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/extensions/navigation_context.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/core/util/vin_from_scan.dart';
import 'package:import_service_app/domain/entities/car_list_item.dart';
import 'package:import_service_app/domain/repositories/cars_repository.dart';
import 'package:import_service_app/presentation/helpers/request_status_labels.dart';
import 'package:import_service_app/presentation/models/demo_car.dart';
import 'package:import_service_app/presentation/widgets/cards/car_card.dart';
import 'package:import_service_app/presentation/widgets/forms/app_search_bar_field.dart';

/// Список всех заявок для менеджера СВХ (серверный поиск VIN / q + пагинация).
class SvhCarsTabView extends StatefulWidget {
  const SvhCarsTabView({super.key, this.initialVin});

  /// Если задан (из QR) — сразу ищем по VIN.
  final String? initialVin;

  @override
  State<SvhCarsTabView> createState() => SvhCarsTabViewState();
}

class SvhCarsTabViewState extends State<SvhCarsTabView> {
  static const int _pageSize = 20;

  final TextEditingController _searchController = TextEditingController();
  final List<CarListItem> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final vin = widget.initialVin?.trim();
    if (vin != null && vin.isNotEmpty) {
      _searchController.text = vin;
    }
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Вызов из shell после скана QR.
  void applyVinSearch(String vin) {
    final v = vin.trim();
    if (v.isEmpty) return;
    _searchController.text = v;
    _reload();
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _reload);
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _hasMore = true;
      _items.clear();
    });
    await _fetchPage(reset: true);
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    await _fetchPage(reset: false);
  }

  Future<void> _fetchPage({required bool reset}) async {
    final s = sl<JsonStringsService>();
    final raw = _searchController.text.trim();
    final vinHint = extractVinFromScanPayload(raw);
    final result = await sl<CarsRepository>().listVehicles(
      limit: _pageSize,
      offset: reset ? 0 : _items.length,
      vin: vinHint,
      q: vinHint == null && raw.isNotEmpty ? raw : null,
      syncInventory: false,
    );

    if (!mounted) return;
    result.fold(
      (failure) {
        setState(() {
          _loading = false;
          _loadingMore = false;
          _error = failure.message.isNotEmpty
              ? failure.message
              : s.text('svhCarsLoadError');
        });
      },
      (page) {
        setState(() {
          _loading = false;
          _loadingMore = false;
          _error = null;
          if (reset) {
            _items
              ..clear()
              ..addAll(page);
          } else {
            _items.addAll(page);
          }
          _hasMore = page.length >= _pageSize;
        });
      },
    );
  }

  DemoCar _toCard(CarListItem c, JsonStringsService strings) {
    return DemoCar(
      id: c.id,
      ownerFullName: c.ownerFullName,
      carMake: c.carMake,
      carModel: c.carModel,
      vin: c.vin,
      statusLabel: requestStatusLabel(c.status, strings),
      requestStatus: c.status,
      managerFullName: c.managerFullName,
      external1cId: c.external1cId,
      clientRating: c.clientRating,
      clientRatingComment: c.clientRatingComment,
      isArchivedOffline: c.isArchivedOffline,
      archivedByName: c.archivedByName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = sl<JsonStringsService>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: AppSearchBarField(
            controller: _searchController,
            hintText: strings.text('svhCarsSearchHint'),
            onChanged: _onSearchChanged,
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _reload,
            child: _buildBody(strings),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(JsonStringsService strings) {
    if (_loading && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
        ],
      );
    }
    if (_error != null && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 280,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const Gap(12),
                    FilledButton(
                      onPressed: _reload,
                      child: Text(strings.text('svhCarsRetry')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 280,
            child: Center(
              child: Text(
                strings.text('svhCarsEmpty'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
            ),
          ),
        ],
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
          _loadMore();
        }
        return false;
      },
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const Gap(10),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final item = _items[index];
          return CarCard(
            car: _toCard(item, strings),
            onOpenDetails: () => context.pushSvhRequestDetail(item.id),
            suppressClientActions: true,
          );
        },
      ),
    );
  }
}
