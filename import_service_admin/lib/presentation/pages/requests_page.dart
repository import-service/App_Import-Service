import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:import_service_admin/core/di/injection_container.dart';
import 'package:import_service_admin/core/error/exceptions.dart';
import 'package:import_service_admin/core/logging/one_c_log.dart';
import 'package:import_service_admin/core/ui/app_snackbars.dart';
import 'package:import_service_admin/core/ui/server_error_ui.dart';
import 'package:import_service_admin/domain/entities/customs_request.dart';
import 'package:import_service_admin/domain/repositories/customs_requests_repository.dart';
import 'package:import_service_admin/presentation/widgets/requests/request_list_card.dart';

class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key});

  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  Future<({List<CustomsRequest> items, int total})>? _future;
  final _sending = <String>{};
  String? _statusFilter;
  var _depsReady = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final status = GoRouterState.of(context).uri.queryParameters['status'];
    final normalized =
        (status != null && status.trim().isNotEmpty) ? status.trim() : null;
    if (!_depsReady || normalized != _statusFilter) {
      _statusFilter = normalized;
      _depsReady = true;
      _reload();
    }
  }

  void _reload() {
    setState(() {
      _future = sl<CustomsRequestsRepository>().listRequests(
        limit: 200,
        status: _statusFilter,
      );
    });
  }

  Future<void> _resendUpdateTo1C(CustomsRequest item) async {
    if (_sending.contains(item.id)) return;
    setState(() => _sending.add(item.id));
    try {
      await sl<CustomsRequestsRepository>().resendUpdateTo1C(item.id);
      if (!mounted) return;
      AppSnackBars.showSuccess(
        'Изменения заявки отправлены в 1С',
        context: context,
      );
      _reload();
    } on UnauthorizedException {
      return;
    } on OneCCreateFailedException catch (e) {
      OneCLog.failure(e, action: 'resend-update-to-1c #${item.id}');
      if (!mounted) return;
      AppSnackBars.showError(e.message, context: context);
    } on ServerException catch (e) {
      if (!mounted) return;
      AppSnackBars.showError(e.message, context: context);
    } catch (e) {
      if (!mounted) return;
      AppSnackBars.showError('Ошибка: $e', context: context);
    } finally {
      if (mounted) setState(() => _sending.remove(item.id));
    }
  }

  Future<void> _sendTo1C(CustomsRequest item) async {
    if (_sending.contains(item.id)) return;
    setState(() => _sending.add(item.id));
    try {
      await sl<CustomsRequestsRepository>().resendTo1C(item.id);
      if (!mounted) return;
      AppSnackBars.showSuccess('Заявка отправлена в 1С', context: context);
      _reload();
    } on UnauthorizedException {
      return;
    } on OneCCreateFailedException catch (e) {
      OneCLog.failure(e, action: 'resend-to-1c #${item.id}');
      if (!mounted) return;
      AppSnackBars.showError(e.message, context: context);
    } on ServerException catch (e) {
      if (!mounted) return;
      AppSnackBars.showError(e.message, context: context);
    } catch (e) {
      if (!mounted) return;
      AppSnackBars.showError('Ошибка: $e', context: context);
    } finally {
      if (mounted) setState(() => _sending.remove(item.id));
    }
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
    return FutureBuilder<({List<CustomsRequest> items, int total})>(
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

        final items = snapshot.data?.items ?? const [];
        if (items.isEmpty) {
          return const Center(child: Text('Заявок нет'));
        }

        return RefreshIndicator(
          onRefresh: () async {
            _reload();
            await _future;
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Gap(12),
            itemBuilder: (context, index) {
              final item = items[index];
              return RequestListCard(
                item: item,
                sending: _sending.contains(item.id),
                onOpenDetail: () => _openDetail(item),
                onSendTo1C: item.canSendTo1C ? () => _sendTo1C(item) : null,
                onResendUpdateTo1C:
                    item.canResendUpdateTo1C ? () => _resendUpdateTo1C(item) : null,
              );
            },
          ),
        );
      },
    );
  }
}
