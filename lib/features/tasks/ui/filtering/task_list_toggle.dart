import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/themes/theme.dart';

class TaskListToggle extends StatelessWidget {
  const TaskListToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        final cubit = context.read<JournalPageCubit>();
        final iconColor = context.textTheme.titleLarge?.color;
        final inactiveIconColor = iconColor?.withAlpha(127);
        final taskAsListView = snapshot.taskAsListView;

        return Row(
          children: [
            const SizedBox(width: 15),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                cubit.toggleTaskAsListView();
              },
              segments: [
                ButtonSegment<bool>(
                  value: true,
                  label: Icon(
                    Icons.density_small_rounded,
                    color: taskAsListView ? iconColor : inactiveIconColor,
                  ),
                ),
                ButtonSegment<bool>(
                  value: false,
                  label: Icon(
                    Icons.density_medium_rounded,
                    color: taskAsListView ? inactiveIconColor : iconColor,
                  ),
                ),
              ],
              selected: {taskAsListView},
            ),
          ],
        );
      },
    );
  }
}
