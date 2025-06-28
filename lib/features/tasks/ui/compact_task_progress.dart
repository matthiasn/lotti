import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/tasks/state/task_progress_controller.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';

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

    final textStyle = TextStyle(
      fontSize: AppTheme.statusIndicatorFontSize,
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: context.colorScheme.onSurfaceVariant.withValues(
        alpha: AppTheme.alphaSurfaceVariant,
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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
        // Progress bar
        SizedBox(
          width: 42,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progressValue.toDouble(),
              backgroundColor: context.colorScheme.outline.withValues(
                alpha: 0.2,
              ),
              color: isOvertime
                  ? context.colorScheme.error.withValues(alpha: 0.7)
                  : successColor.withValues(alpha: 0.7),
              minHeight: 12,
            ),
          ),
        ),
      ],
    );
  }
}
