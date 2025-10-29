import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/search/filter_choice_chip.dart';

class TaskPriorityFilter extends StatelessWidget {
  const TaskPriorityFilter({super.key});

  static const List<String> priorities = ['P0', 'P1', 'P2', 'P3'];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, state) {
        final cubit = context.read<JournalPageCubit>();
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
                      onTap: () => cubit.toggleSelectedPriority(code),
                    )),
                FilterChoiceChip(
                  label: context.messages.tasksPriorityFilterAll,
                  selectedColor: Colors.grey,
                  isSelected: selected.isEmpty,
                  onTap: cubit.clearSelectedPriorities,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Color _colorForPriority(BuildContext context, String code) {
    final priority = taskPriorityFromString(code);
    return priority.colorForBrightness(Theme.of(context).brightness);
  }
}
