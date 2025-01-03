import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/tasks/state/tasks_count_controller.dart';
import 'package:lotti/themes/theme.dart';

class TasksBadge extends ConsumerWidget {
  const TasksBadge({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(tasksCountControllerProvider).valueOrNull ?? 0;

    return Badge(
      label: Text('$count', style: badgeStyle),
      isLabelVisible: count != 0,
      backgroundColor: context.colorScheme.error,
      child: child,
    );
  }
}
