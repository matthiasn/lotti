import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

class TaskSortFilter extends ConsumerWidget {
  const TaskSortFilter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTasks = ref.watch(journalPageScopeProvider);
    final state = ref.watch(journalPageControllerProvider(showTasks));
    final controller =
        ref.read(journalPageControllerProvider(showTasks).notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.messages.tasksSortByLabel,
          style: context.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        SegmentedButton<TaskSortOption>(
          segments: [
            ButtonSegment(
              value: TaskSortOption.byDueDate,
              label: Text(context.messages.tasksSortByDueDate),
              icon: const Icon(Icons.event_rounded, size: 18),
            ),
            ButtonSegment(
              value: TaskSortOption.byDate,
              label: Text(context.messages.tasksSortByCreationDate),
              icon: const Icon(Icons.calendar_today_rounded, size: 18),
            ),
            ButtonSegment(
              value: TaskSortOption.byPriority,
              label: Text(context.messages.tasksSortByPriority),
              icon: const Icon(Icons.priority_high_rounded, size: 18),
            ),
          ],
          selected: {state.sortOption},
          onSelectionChanged: (selection) {
            controller.setSortOption(selection.first);
            HapticFeedback.selectionClick();
          },
        ),
      ],
    );
  }
}
