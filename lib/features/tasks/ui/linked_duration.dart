import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/tasks/state/task_progress_controller.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:tinycolor2/tinycolor2.dart';

/// Progress display for the time logged against the task identified by
/// [taskId], watching `taskProgressControllerProvider`.
///
/// Renders a full-width [LinearProgressIndicator] (logged time over estimate,
/// clamped to 100%) above a row showing the formatted logged duration on the
/// left and the estimate on the right; both turn to the error colour on
/// overtime. Unlike `CompactTaskProgress`, this lays the bar out full width
/// with the two durations beneath it rather than a fixed-width inline bar.
/// Renders nothing when there is no progress state or the estimate is zero.
class LinkedDuration extends ConsumerWidget {
  const LinkedDuration({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(taskProgressControllerProvider(id: taskId)).value;

    if (state == null || state.estimate == Duration.zero) {
      return const SizedBox.shrink();
    }

    final progress = state.progress;
    final estimate = state.estimate;

    final durationStyle = tabularFigureStyle(
      fontSize: fontSizeSmall,
      color: (progress > estimate)
          ? context.colorScheme.error
          : context.colorScheme.outline,
    );

    final value = estimate.inSeconds > 0
        ? min(progress.inSeconds / estimate.inSeconds, 1)
        : 0;

    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              minHeight: 5,
              value: value.toDouble(),
              color: (progress > estimate) ? failColor : successColor,
              backgroundColor: successColor.desaturate().withAlpha(77),
            ),
          ),
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formatDuration(progress),
                  style: durationStyle,
                ),
                Text(
                  formatDuration(estimate),
                  style: durationStyle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
