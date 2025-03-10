import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/tasks/state/tasks_count_controller.dart';
import 'package:lotti/themes/theme.dart';
import 'package:showcaseview/showcaseview.dart';

class TasksBadge extends ConsumerWidget {
  const TasksBadge({
    required this.showcaseKey, 
    required this.child,
    super.key,
  });

  final Widget child;
  final GlobalKey showcaseKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(tasksCountControllerProvider).valueOrNull ?? 0;

    return Showcase(
      titleAlignment: Alignment.topCenter,
      tooltipPosition: TooltipPosition.top,
      key: showcaseKey,
      description: 'This is the badge that shows the number of tasks that are overdue.',
      child: Badge(
        label: Text('$count', style: badgeStyle),
        isLabelVisible: count != 0,
        backgroundColor: context.colorScheme.error,
        child: child,
      ),
    );
  }
}
