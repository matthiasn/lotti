import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/tasks/ui/utils.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/search/filter_choice_chip.dart';
import 'package:quiver/collection.dart';

class TaskStatusFilter extends ConsumerWidget {
  const TaskStatusFilter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTasks = ref.watch(journalPageScopeProvider);
    final state = ref.watch(journalPageControllerProvider(showTasks));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        //const Divider(),
        Text(
          context.messages.taskStatusLabel,
          style: context.textTheme.bodySmall,
        ),
        const SizedBox(height: 5),
        Wrap(
          runSpacing: 8,
          spacing: 8,
          children: [
            ...state.taskStatuses.map(
              (status) => TaskStatusChip(
                status,
                onlySelected: false,
              ),
            ),
            const TaskStatusAllChip(),
          ],
        ),
      ],
    );
  }
}

class TaskStatusChip extends ConsumerWidget {
  const TaskStatusChip(
    this.status, {
    required this.onlySelected,
    super.key,
  });

  final String status;
  final bool onlySelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTasks = ref.watch(journalPageScopeProvider);
    final state = ref.watch(journalPageControllerProvider(showTasks));
    final controller =
        ref.read(journalPageControllerProvider(showTasks).notifier);

    void onTap() {
      controller.toggleSelectedTaskStatus(status);
      HapticFeedback.heavyImpact();
    }

    void onLongPress() {
      controller.selectSingleTaskStatus(status);
      HapticFeedback.heavyImpact();
    }

    final isSelected = state.selectedTaskStatuses.contains(status);

    if (onlySelected && !isSelected) {
      return const SizedBox.shrink();
    }

    final backgroundColor = taskColorFromStatusString(status);

    return FilterChoiceChip(
      label: taskLabelFromStatusString(status, context),
      isSelected: isSelected,
      onTap: onTap,
      onLongPress: onLongPress,
      selectedColor: backgroundColor,
    );
  }
}

class TaskStatusAllChip extends ConsumerWidget {
  const TaskStatusAllChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTasks = ref.watch(journalPageScopeProvider);
    final state = ref.watch(journalPageControllerProvider(showTasks));
    final controller =
        ref.read(journalPageControllerProvider(showTasks).notifier);

    final isSelected = setsEqual(
      state.selectedTaskStatuses,
      state.taskStatuses.toSet(),
    );

    void onTap() {
      if (isSelected) {
        controller.clearSelectedTaskStatuses();
      } else {
        controller.selectAllTaskStatuses();
      }
      HapticFeedback.heavyImpact();
    }

    return FilterChoiceChip(
      label: context.messages.taskStatusAll,
      isSelected: isSelected,
      selectedColor: context.colorScheme.secondary,
      onTap: onTap,
    );
  }
}
