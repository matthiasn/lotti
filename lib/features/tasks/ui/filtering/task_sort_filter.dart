import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

class TaskSortFilter extends StatelessWidget {
  const TaskSortFilter({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        final cubit = context.read<JournalPageCubit>();

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
                  value: TaskSortOption.byPriority,
                  label: Text(context.messages.tasksSortByPriority),
                  icon: const Icon(Icons.priority_high_rounded, size: 18),
                ),
                ButtonSegment(
                  value: TaskSortOption.byDate,
                  label: Text(context.messages.tasksSortByDate),
                  icon: const Icon(Icons.calendar_today_rounded, size: 18),
                ),
              ],
              selected: {snapshot.sortOption},
              onSelectionChanged: (selection) {
                cubit.setSortOption(selection.first);
                HapticFeedback.selectionClick();
              },
            ),
          ],
        );
      },
    );
  }
}
