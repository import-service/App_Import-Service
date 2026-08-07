import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/core/ui/app_feedback_kind.dart';
import 'package:import_service_app/core/ui/app_feedback_service.dart';
import 'package:import_service_app/domain/repositories/cars_repository.dart';

/// Блок «Оставьте свою оценку» на карточке вкладки «Доставлено».
class RequestRatingBlock extends StatefulWidget {
  const RequestRatingBlock({
    super.key,
    required this.requestId,
    this.existingRating,
    this.existingComment,
  });

  final String requestId;
  final int? existingRating;
  final String? existingComment;

  @override
  State<RequestRatingBlock> createState() => _RequestRatingBlockState();
}

class _RequestRatingBlockState extends State<RequestRatingBlock> {
  static const _commentMax = 500;

  int _selected = 0;
  final _commentController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.existingRating ?? 0;
    final c = widget.existingComment?.trim() ?? '';
    if (c.isNotEmpty) {
      _commentController.text = c;
    }
  }

  @override
  void didUpdateWidget(covariant RequestRatingBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.existingRating != oldWidget.existingRating &&
        widget.existingRating != null) {
      _selected = widget.existingRating!;
    }
    if (widget.existingComment != oldWidget.existingComment) {
      final c = widget.existingComment?.trim() ?? '';
      if (_commentController.text != c) {
        _commentController.text = c;
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  bool get _alreadyRated =>
      widget.existingRating != null && widget.existingRating! >= 1;

  bool get _needsComment => !_alreadyRated && _selected >= 1 && _selected <= 3;

  Future<void> _submit() async {
    if (_submitting || _alreadyRated || _selected < 1) return;
    final strings = sl<JsonStringsService>();
    setState(() => _submitting = true);
    final result = await sl<CarsRepository>().submitRequestRating(
      requestId: widget.requestId,
      rating: _selected,
      comment: _needsComment ? _commentController.text.trim() : null,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    result.fold(
      (failure) {
        sl<AppFeedbackService>().show(
          failure.message,
          kind: AppFeedbackKind.error,
        );
      },
      (_) {
        sl<AppFeedbackService>().show(
          strings.requestRatingThanks,
          kind: AppFeedbackKind.success,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = sl<JsonStringsService>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _alreadyRated
              ? strings.requestRatingYourRating
              : strings.requestRatingLeavePrompt,
          style: theme.textTheme.labelLarge?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Gap(8),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: _alreadyRated || _submitting
                    ? null
                    : () => setState(() => _selected = i),
                icon: Icon(
                  i <= _selected ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: i <= _selected
                      ? const Color(0xFFE6A800)
                      : AppTheme.textSecondary,
                  size: 30,
                ),
              ),
          ],
        ),
        if (_needsComment) ...[
          const Gap(4),
          TextField(
            controller: _commentController,
            enabled: !_submitting,
            maxLength: _commentMax,
            maxLines: 3,
            minLines: 2,
            decoration: InputDecoration(
              hintText: strings.requestRatingWishesHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              isDense: true,
            ),
          ),
        ],
        if (_alreadyRated &&
            (widget.existingComment?.trim().isNotEmpty ?? false)) ...[
          const Gap(4),
          Text(
            widget.existingComment!.trim(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              height: 1.35,
            ),
          ),
        ],
        if (!_alreadyRated && _selected >= 1) ...[
          const Gap(8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: AppTheme.white,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(strings.requestRatingSubmit),
            ),
          ),
        ],
      ],
    );
  }
}
