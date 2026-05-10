import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/core/util/vin_display.dart';
import 'package:import_service_app/domain/entities/request_status.dart';
import 'package:import_service_app/presentation/models/demo_car.dart';
import 'package:import_service_app/presentation/widgets/chips/request_status_pill.dart';

/// Карточка заявки. Нажатие по основному блоку (кроме «Перейти в чат») — [onOpenDetails].
class CarCard extends StatelessWidget {
  const CarCard({
    super.key,
    required this.car,
    this.onOpenDetails,
    this.onOpenChat,
  });

  final DemoCar car;
  final VoidCallback? onOpenDetails;
  final VoidCallback? onOpenChat;

  bool get _showGoToChat => car.requestStatus != RequestStatus.newRequest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.requestCardBorder),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: onOpenDetails,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  _showGoToChat ? 0 : 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      car.ownerFullName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Gap(6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                car.displayCarLine,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const Gap(4),
                              Text(
                                'VIN: ${formatVinForList(car.vin)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppTheme.requestCardStatusPillBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            child: Icon(
                              Icons.chevron_right_rounded,
                              color: AppTheme.accentRed,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Gap(10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: RequestStatusPill(label: car.statusLabel),
                    ),
                  ],
                ),
              ),
            ),
            if (_showGoToChat) ...[
              const Gap(10),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Material(
                  color: AppTheme.requestCardChatButtonBg,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: onOpenChat,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 22,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              sl<JsonStringsService>().requestCardGoToChat,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 22,
                            color: AppTheme.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
