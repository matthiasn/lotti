import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/search/filter_choice_chip.dart';

class TaskAgentFilter extends ConsumerWidget {
  const TaskAgentFilter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTasks = ref.watch(journalPageScopeProvider);
    final state = ref.watch(journalPageControllerProvider(showTasks));
    final controller = ref.read(
      journalPageControllerProvider(showTasks).notifier,
    );
    final selected = state.agentAssignmentFilter;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          context.messages.tasksAgentFilterTitle,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 5),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChoiceChip(
              label: context.messages.tasksAgentFilterAll,
              selectedColor: Colors.grey,
              isSelected: selected == AgentAssignmentFilter.all,
              onTap: () => controller.setAgentAssignmentFilter(
                AgentAssignmentFilter.all,
              ),
            ),
            FilterChoiceChip(
              label: context.messages.tasksAgentFilterHasAgent,
              selectedColor: Colors.green,
              isSelected: selected == AgentAssignmentFilter.hasAgent,
              onTap: () => controller.setAgentAssignmentFilter(
                AgentAssignmentFilter.hasAgent,
              ),
            ),
            FilterChoiceChip(
              label: context.messages.tasksAgentFilterNoAgent,
              selectedColor: Colors.orange,
              isSelected: selected == AgentAssignmentFilter.noAgent,
              onTap: () => controller.setAgentAssignmentFilter(
                AgentAssignmentFilter.noAgent,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
