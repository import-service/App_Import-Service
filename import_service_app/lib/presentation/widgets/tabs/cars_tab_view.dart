import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:import_service_app/core/extensions/navigation_context.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/navigation/home_cars_navigation_controller.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/presentation/bloc/car_inventory/car_inventory_cubit.dart';
import 'package:import_service_app/presentation/bloc/car_inventory/car_inventory_state.dart';
import 'package:import_service_app/presentation/bloc/request_attention/request_attention_cubit.dart';
import 'package:import_service_app/presentation/bloc/request_attention/request_attention_state.dart';
import 'package:import_service_app/presentation/bloc/request_chat_unread/request_chat_unread_cubit.dart';
import 'package:import_service_app/presentation/bloc/request_chat_unread/request_chat_unread_state.dart';
import 'package:import_service_app/presentation/bloc/request_draft/request_draft_cubit.dart';
import 'package:import_service_app/presentation/bloc/request_draft/request_draft_state.dart';
import 'package:import_service_app/domain/entities/car_list_item.dart';
import 'package:import_service_app/domain/entities/request_status.dart';
import 'package:import_service_app/domain/repositories/cars_repository.dart';
import 'package:import_service_app/presentation/models/demo_car.dart';
import 'package:import_service_app/presentation/widgets/bottom_sheets/request_drafts_bottom_sheet.dart';
import 'package:import_service_app/presentation/widgets/cards/car_card.dart';
import 'package:import_service_app/presentation/helpers/request_detail_pending_actions.dart';
import 'package:import_service_app/presentation/helpers/request_status_labels.dart';
import 'package:import_service_app/presentation/widgets/filters/car_status_chips_bar.dart';
import 'package:import_service_app/presentation/widgets/forms/app_search_bar_field.dart';

class CarsTabView extends StatefulWidget {
  const CarsTabView({
    super.key,
    required this.noDataText,
    required this.searchHint,
    required this.statuses,
  });

  final String noDataText;
  final String searchHint;
  final List<String> statuses;

  @override
  State<CarsTabView> createState() => _CarsTabViewState();
}

class _CarsTabViewState extends State<CarsTabView> {
  int _selectedStatusIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  bool _initialLoading = true;

  static const List<RequestStatus> _statusOrder = <RequestStatus>[
    RequestStatus.inProgress,
    RequestStatus.inTransit,
    RequestStatus.delivered,
  ];

  @override
  void initState() {
    super.initState();
    sl<HomeCarsNavigationController>().addListener(_onCarsNavigationIntent);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _applyCarsNavigationIntent();
      try {
        await sl<CarsRepository>().listVehicles();
      } finally {
        if (mounted) {
          _applyCarsNavigationIntent();
          setState(() => _initialLoading = false);
        }
      }
    });
  }

  @override
  void dispose() {
    sl<HomeCarsNavigationController>().removeListener(_onCarsNavigationIntent);
    _searchController.dispose();
    super.dispose();
  }

  void _onCarsNavigationIntent() => _applyCarsNavigationIntent();

  void _applyCarsNavigationIntent() {
    final index = sl<HomeCarsNavigationController>().statusFilterIndex;
    if (index == null || !mounted) return;
    if (index == _selectedStatusIndex) return;
    setState(() => _selectedStatusIndex = index);
  }

  void _onInventoryChanged() => _applyCarsNavigationIntent();

  Future<void> _refreshCars() => sl<CarsRepository>().listVehicles();

  /// Поиск по марке/модели: вхождение подстроки, без учёта регистра, пробелы схлопываются.
  static bool _modelMatchesQuery(String model, String rawQuery) {
    final q = rawQuery.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (q.isEmpty) return true;
    final m = model.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    return m.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CarInventoryCubit, CarInventoryState>(
      bloc: sl<CarInventoryCubit>(),
      listener: (context, state) => _onInventoryChanged(),
      child: BlocBuilder<RequestAttentionCubit, RequestAttentionState>(
      bloc: sl<RequestAttentionCubit>(),
      builder: (context, attentionState) => BlocBuilder<RequestChatUnreadCubit, RequestChatUnreadState>(
      bloc: sl<RequestChatUnreadCubit>(),
      builder: (context, unreadState) {
        /// Низ области вкладки (над нижней навигацией [HomePage]); слева — как у контента (20).
        const draftFabLeft = 20.0;
        const draftFabBottom = 12.0;

        // StackFit.expand: иначе при n==0 черновиков второй ребёнок — unpositioned
        // SizedBox.shrink() (0×0) и вместе с StackFit.loose стек схлопывается в
        // ноль по высоте, Expanded в Column не даёт пикселей — список «пустой».
        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  children: [
                    CarStatusChipsBar(
                      statuses: widget.statuses,
                      selectedIndex: _selectedStatusIndex,
                      onSelected: (index) {
                        setState(() => _selectedStatusIndex = index);
                      },
                    ),
                    const SizedBox(height: 12),
                    AppSearchBarField(
                      controller: _searchController,
                      hintText: widget.searchHint,
                      onChanged: (_) => setState(() {}),
                      clearTooltip: sl<JsonStringsService>().carsSearchClearA11y,
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: _initialLoading
                          ? const Center(child: CircularProgressIndicator())
                          : RefreshIndicator(
                              onRefresh: _refreshCars,
                              child: BlocBuilder<CarInventoryCubit, CarInventoryState>(
                                bloc: sl<CarInventoryCubit>(),
                                builder: (context, invState) {
                                  return _statusCarList(
                                    invState.items,
                                    _selectedStatusIndex,
                                    _searchController.text,
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            _draftsFab(left: draftFabLeft, bottom: draftFabBottom),
          ],
        );
      },
      ),
      ),
    );
  }

  Widget _draftsFab({required double left, required double bottom}) {
    return BlocBuilder<RequestDraftCubit, RequestDraftState>(
      bloc: sl<RequestDraftCubit>(),
      builder: (context, dState) {
        final n = dState.count;
        if (n == 0) return const SizedBox.shrink();
        return Positioned(
          left: left,
          bottom: bottom,
          child: Material(
            elevation: 4,
            color: AppTheme.primaryBlue,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => RequestDraftsBottomSheet.show(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Text(
                  sl<JsonStringsService>().requestDraftsFab(n),
                  style: const TextStyle(
                    color: AppTheme.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _statusCarList(
    List<CarListItem> fromServer,
    int statusIndex,
    String searchQuery,
  ) {
    final unreadState = sl<RequestChatUnreadCubit>().state;
    final attention = sl<RequestAttentionCubit>().state;
    final strings = sl<JsonStringsService>();
    final selectedStatus = _statusOrder[statusIndex.clamp(0, _statusOrder.length - 1)];
    final displayList = fromServer
        .where((c) {
          if (!_modelMatchesQuery(c.displayCarLine, searchQuery)) return false;
          // Первая вкладка: «В работе» = new + in_progress (разные подписи на карточке).
          if (selectedStatus == RequestStatus.inProgress) {
            return requestStatusInWorkTab(c.status);
          }
          if (selectedStatus == RequestStatus.delivered) {
            return requestStatusDeliveredTab(c.status);
          }
          return c.status == selectedStatus;
        })
        .map(
          (c) => DemoCar(
            id: c.id,
            ownerFullName: c.ownerFullName,
            carMake: c.carMake,
            carModel: c.carModel,
            vin: c.vin,
            statusLabel: _statusLabel(c.status),
            requestStatus: c.status,
            managerFullName: c.managerFullName,
            external1cId: c.external1cId,
            hasUnreadChat: unreadState.has(c.id),
            hasStatusUpdate: attention.hasStatusUpdate(c.id),
            hasDocsAction: attention.hasDocsAction(c.id),
            statusUpdateSummary: attention.statusUpdateSummaryFor(c.id),
            pendingActionHints: requestDetailUrgentActionHints(c, strings),
          ),
        )
        .toList();
    if (displayList.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 320,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  widget.noDataText,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 56),
      itemBuilder: (context, index) {
        final car = displayList[index];
        return CarCard(
          car: car,
          onOpenDetails: () {
            sl<RequestAttentionCubit>().clearStatusUpdated(car.id);
            sl<RequestAttentionCubit>().clearDocsAction(car.id);
            context.pushRequestDetail(car.id);
          },
          onOpenChat: () {
            sl<RequestChatUnreadCubit>().clearUnread(car.id);
            context.pushRequestChat(car.id);
          },
        );
      },
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemCount: displayList.length,
    );
  }

  String _statusLabel(RequestStatus status) {
    return requestStatusLabel(status, sl<JsonStringsService>());
  }
}
