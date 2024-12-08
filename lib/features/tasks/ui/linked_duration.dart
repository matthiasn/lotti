import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/tasks/model/task_progress_state.dart';
import 'package:lotti/features/tasks/state/task_progress_controller.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:tinycolor2/tinycolor2.dart';

class LinkedDuration extends ConsumerWidget {
  const LinkedDuration({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state =
        ref.watch(taskProgressControllerProvider(id: taskId)).valueOrNull ??
            const TaskProgressState(
              progress: Duration.zero,
              estimate: Duration.zero,
            );

    final progress = state.progress;
    final estimate = state.estimate;

    final durationStyle = monospaceTextStyleSmall.copyWith(
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
              backgroundColor: successColor.desaturate().withOpacity(0.3),
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
