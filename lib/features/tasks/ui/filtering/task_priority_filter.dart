import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/search/filter_choice_chip.dart';

class TaskPriorityFilter extends ConsumerWidget {
  const TaskPriorityFilter({super.key});

  static const List<String> priorities = ['P0', 'P1', 'P2', 'P3'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTasks = ref.watch(journalPageScopeProvider);
    final state = ref.watch(journalPageControllerProvider(showTasks));
    final controller =
        ref.read(journalPageControllerProvider(showTasks).notifier);
    final selected = state.selectedPriorities;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(context.messages.tasksPriorityFilterTitle,
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 5),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...priorities.map((code) => FilterChoiceChip(
                  label: code,
                  selectedColor: _colorForPriority(context, code),
                  isSelected: selected.contains(code),
                  onTap: () => controller.toggleSelectedPriority(code),
                )),
            FilterChoiceChip(
              label: context.messages.tasksPriorityFilterAll,
              selectedColor: Colors.grey,
              isSelected: selected.isEmpty,
              onTap: controller.clearSelectedPriorities,
            ),
          ],
        ),
      ],
    );
  }

  Color _colorForPriority(BuildContext context, String code) {
    final priority = taskPriorityFromString(code);
    return priority.colorForBrightness(Theme.of(context).brightness);
  }
}
