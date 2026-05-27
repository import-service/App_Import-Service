import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:import_service_app/core/auth/auth_session_controller.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/core/ui/app_feedback_kind.dart';
import 'package:import_service_app/core/ui/app_feedback_service.dart';
import 'package:import_service_app/core/util/vin_display.dart';
import 'package:import_service_app/data/websocket/chat_broadcast_wss_client.dart';
import 'package:import_service_app/domain/entities/car_list_item.dart';
import 'package:import_service_app/domain/entities/chat_message.dart';
import 'package:import_service_app/presentation/helpers/request_status_labels.dart';
import 'package:import_service_app/domain/repositories/request_chat_repository.dart';
import 'package:import_service_app/presentation/bloc/car_inventory/car_inventory_cubit.dart';
import 'package:import_service_app/presentation/bloc/car_inventory/car_inventory_state.dart';
import 'package:import_service_app/presentation/bloc/request_chat/request_chat_cubit.dart';
import 'package:import_service_app/presentation/bloc/request_chat/request_chat_state.dart';
import 'package:intl/intl.dart';

/// Маршрут: `/request/:id/chat` — чат [api-app.md] REST+WSS; в демо: автоответ.
class RequestChatPage extends StatelessWidget {
  const RequestChatPage({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RequestChatCubit(
        requestId: requestId,
        repository: sl<RequestChatRepository>(),
        session: sl<AuthSessionController>(),
        strings: sl<JsonStringsService>(),
        wss: ChatBroadcastWssClient(),
      ),
      child: _RequestChatView(requestId: requestId),
    );
  }
}

class _RequestChatView extends StatefulWidget {
  const _RequestChatView({required this.requestId});

  final String requestId;

  @override
  State<_RequestChatView> createState() => _RequestChatViewState();
}

class _RequestChatViewState extends State<_RequestChatView> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) {
        return;
      }
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = sl<JsonStringsService>();
    final requestId = widget.requestId;
    final loc = Localizations.localeOf(context).toLanguageTag();

    return BlocConsumer<RequestChatCubit, RequestChatState>(
      listenWhen: (a, b) => a.error != b.error,
      listener: (context, state) {
        if (state.error != null && state.error!.isNotEmpty) {
          sl<AppFeedbackService>().show(
            state.error!,
            kind: AppFeedbackKind.error,
          );
          context.read<RequestChatCubit>().clearError();
        }
      },
      builder: (context, cstate) {
        if (cstate.isLoading) {
          return Scaffold(
            backgroundColor: AppTheme.pageBackground,
            appBar: _chatAppBar(context, s.chatPageTitle),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (cstate.isUnavailable) {
          return Scaffold(
            backgroundColor: AppTheme.pageBackground,
            appBar: _chatAppBar(context, s.chatPageTitle),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  s.chatUnavailable,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          );
        }

        if (cstate.messages.isNotEmpty) {
          _scrollToEnd();
        }

        return BlocBuilder<CarInventoryCubit, CarInventoryState>(
          bloc: sl<CarInventoryCubit>(),
          builder: (context, carState) {
            final car = _findItem(carState.items, requestId);
            return Scaffold(
              backgroundColor: AppTheme.pageBackground,
              appBar: _chatAppBar(context, s.chatPageTitle),
              body: Column(
                children: [
                  if (car != null) _headerCard(context, car, s) else const SizedBox.shrink(),
                  Expanded(
                    child: _messageList(
                      context: context,
                      cstate: cstate,
                      loc: loc,
                    ),
                  ),
                  _inputBar(
                    context: context,
                    cstate: cstate,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  PreferredSizeWidget _chatAppBar(BuildContext context, String title) {
    return AppBar(
      centerTitle: true,
      backgroundColor: AppTheme.accentRed,
      foregroundColor: AppTheme.white,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => context.pop(),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppTheme.white,
        ),
      ),
    );
  }

  Widget _messageList({
    required BuildContext context,
    required RequestChatState cstate,
    required String loc,
  }) {
    final s = sl<JsonStringsService>();
    final t = Theme.of(context);
    final list = cstate.messages;
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            s.chatEmptyHint,
            textAlign: TextAlign.center,
            style: t.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      );
    }
    final children = <Widget>[];
    DateTime? lastDay;
    for (var i = 0; i < list.length; i++) {
      final m = list[i];
      final local = m.createdAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      if (lastDay == null || day != lastDay) {
        lastDay = day;
        children.add(
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 6),
              child: Text(
                _formatDateSeparator(local, loc),
                style: t.textTheme.labelSmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ),
        );
      }
      children.add(
        _ChatBubble(
          message: m,
          loc: loc,
        ),
      );
    }
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      children: children,
    );
  }

  String _formatDateSeparator(DateTime d, String loc) {
    try {
      return DateFormat('d MMMM, y', loc).format(d);
    } catch (_) {
      return DateFormat('yyyy-MM-dd').format(d);
    }
  }

  Widget _inputBar({
    required BuildContext context,
    required RequestChatState cstate,
  }) {
    final s = sl<JsonStringsService>();
    return Material(
      color: AppTheme.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.attach_file_outlined, color: AppTheme.textSecondary),
                onPressed: () {
                  sl<AppFeedbackService>().show(
                    s.chatInDevelopment,
                    kind: AppFeedbackKind.warning,
                  );
                },
                tooltip: s.chatInDevelopment,
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: s.chatInputPlaceholder,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.requestCardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppTheme.inputOutlineGray,
                        width: 1.2,
                      ),
                    ),
                    filled: true,
                    fillColor: AppTheme.white,
                  ),
                  onSubmitted: (_) {
                    if (!cstate.isSending) {
                      _submit(context, cstate);
                    }
                  },
                ),
              ),
              IconButton(
                onPressed: cstate.isSending
                    ? null
                    : () => _submit(context, cstate),
                icon: Icon(
                  Icons.send_rounded,
                  color: cstate.isSending
                      ? AppTheme.textSecondary.withValues(alpha: 0.4)
                      : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit(BuildContext context, RequestChatState cstate) {
    if (cstate.isSending) {
      return;
    }
    final t = _controller.text;
    if (t.trim().isEmpty) {
      return;
    }
    context.read<RequestChatCubit>().send(t);
    _controller.clear();
  }

  Widget _headerCard(
    BuildContext context,
    CarListItem car,
    JsonStringsService s,
  ) {
    final chip = requestStatusLabel(car.status, s);
    final t = Theme.of(context);
    return Material(
      color: AppTheme.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              car.ownerFullName,
              style: t.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const Gap(2),
            Text(
              car.displayCarLine,
              style: t.textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const Gap(4),
            Text(
              'VIN: ${formatVinForList(car.vin)}',
              style: t.textTheme.labelSmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            if (car.managerFullName != null && car.managerFullName!.trim().isNotEmpty) ...[
              const Gap(4),
              Text(
                '${s.requestDetailManager}: ${car.managerFullName!.trim()}',
                style: t.textTheme.labelSmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
            const Gap(6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.requestCardStatusPillBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        chip,
                        style: t.textTheme.labelSmall?.copyWith(
                          color: AppTheme.accentRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: AppTheme.accentRed,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Gap(4),
            const Divider(height: 1),
          ],
        ),
      ),
    );
  }
}

CarListItem? _findItem(List<CarListItem> items, String id) {
  for (final e in items) {
    if (e.id == id) {
      return e;
    }
  }
  return null;
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.loc,
  });

  final ChatMessage message;
  final String loc;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isOut = !message.isFrom1c;
    final align = isOut ? Alignment.centerRight : Alignment.centerLeft;
    const outBg = Color(0xFFE6E6E6);
    final inDecoration = BoxDecoration(
      color: AppTheme.white,
      border: Border.all(color: AppTheme.requestCardBorder, width: 0.5),
      borderRadius: const BorderRadius.all(
        Radius.circular(12),
      ),
    );
    const outDecoration = BoxDecoration(
      color: outBg,
      borderRadius: BorderRadius.all(
        Radius.circular(12),
      ),
    );
    final time = _formatTime(message.createdAt, loc);
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Align(
        alignment: align,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.8,
          ),
          child: DecoratedBox(
            decoration: isOut ? outDecoration : inDecoration,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment:
                    isOut ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.text,
                    style: t.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const Gap(3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: isOut ? MainAxisAlignment.end : MainAxisAlignment.start,
                    children: [
                      Text(
                        time,
                        style: t.textTheme.labelSmall?.copyWith(
                          color: AppTheme.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                      if (isOut) ...[
                        const Gap(4),
                        Icon(
                          Icons.done_all,
                          size: 14,
                          color: message.readByUser
                              ? const Color(0xFF29B6F6)
                              : AppTheme.textSecondary,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime d, String loc) {
    try {
      return DateFormat('HH:mm', loc).format(d.toLocal());
    } catch (_) {
      return DateFormat('HH:mm').format(d.toLocal());
    }
  }
}
