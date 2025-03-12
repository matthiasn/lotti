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

    return Showcase.withWidget(
      tooltipPosition: TooltipPosition.top,
      overlayOpacity: 0.7,
      key: showcaseKey,
      width: 300,
      height: 100,
      container: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This badge tracks the number of overdue tasks but also serves as a central hub for task management.',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: () {
                    ShowCaseWidget.of(context).dismiss();
                  },
                  child: const Text('close'),
                ),
                ElevatedButton(
                  onPressed: () {
                    ShowCaseWidget.of(context).next();
                  },
                  child: const Text('Next'),
                ),
              ],
            ),
          ],
        ),
      ),
      child: Badge(
        label: Text('$count', style: badgeStyle),
        isLabelVisible: count != 0,
        backgroundColor: context.colorScheme.error,
        child: child,
      ),
    );
  }
}
