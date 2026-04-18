import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/tasks/state/tasks_count_controller.dart';

/// Standalone count pill for the open-task count, rendered in a trailing slot
/// (e.g. on the desktop navigation sidebar). Shows nothing when the count is 0.
class TasksTrailingBadge extends ConsumerWidget {
  const TasksTrailingBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(tasksCountControllerProvider).value ?? 0;
    if (count == 0) {
      return const SizedBox.shrink();
    }
    return DesignSystemBadge.number(
      value: '$count',
      tone: DesignSystemBadgeTone.danger,
    );
  }
}
