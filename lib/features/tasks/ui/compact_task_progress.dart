import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/tasks/state/task_progress_controller.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';

class CompactTaskProgress extends ConsumerWidget {
  const CompactTaskProgress({
    required this.taskId,
    super.key,
  });

  final String taskId;

  String _formatDurationHoursMinutes(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state =
        ref.watch(taskProgressControllerProvider(id: taskId)).valueOrNull;

    if (state == null || state.estimate == Duration.zero) {
      return const SizedBox.shrink();
    }

    final progress = state.progress;
    final estimate = state.estimate;
    final isOvertime = progress > estimate;

    final progressValue = estimate.inSeconds > 0
        ? min(progress.inSeconds / estimate.inSeconds, 1)
        : 0.0;

    final base = context.textTheme.titleSmall;
    final textStyle = (base != null
            ? base.withTabularFigures
            : monoTabularStyle(
                fontSize: AppTheme.statusIndicatorFontSize,
                fontWeight: FontWeight.w600,
                color: context.colorScheme.onSurfaceVariant.withValues(
                  alpha: AppTheme.alphaSurfaceVariant,
                ),
              ))
        .copyWith(
      color: context.colorScheme.onSurfaceVariant.withValues(
        alpha: AppTheme.alphaSurfaceVariant,
      ),
      fontWeight: FontWeight.w600,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isDesktop) ...[
          // Time display
          Text(
            '${_formatDurationHoursMinutes(progress)} / ${_formatDurationHoursMinutes(estimate)}',
            style: textStyle.copyWith(
              color: isOvertime
                  ? context.colorScheme.error.withValues(alpha: 0.8)
                  : context.colorScheme.outline,
            ),
          ),
          const SizedBox(width: 10),
        ],
        // Progress bar
        SizedBox(
          width: 50,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressValue.toDouble(),
              backgroundColor: context.colorScheme.outline.withValues(
                alpha: 0.2,
              ),
              color: isOvertime
                  ? context.colorScheme.error.withValues(alpha: 0.7)
                  : successColor.withValues(alpha: 0.7),
              minHeight: 8,
            ),
          ),
        ),
      ],
    );
  }
}
