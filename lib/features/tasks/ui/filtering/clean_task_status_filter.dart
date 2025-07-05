import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/features/tasks/ui/utils.dart';
import 'package:lotti/widgets/modal/clean_filter_chip.dart';
import 'package:lotti/widgets/modal/clean_filter_section.dart';
import 'package:quiver/collection.dart';

class CleanTaskStatusFilter extends StatelessWidget {
  const CleanTaskStatusFilter({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        return CleanFilterSection(
          title: 'Status',
          subtitle: 'Filter tasks by their current status',
          children: [
            ...snapshot.taskStatuses.map(
              (status) => CleanTaskStatusChip(status: status),
            ),
            const CleanTaskStatusAllChip(),
          ],
        );
      },
    );
  }
}

class CleanTaskStatusChip extends StatelessWidget {
  const CleanTaskStatusChip({
    required this.status,
    super.key,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        final cubit = context.read<JournalPageCubit>();
        final isSelected = snapshot.selectedTaskStatuses.contains(status);
        final backgroundColor = taskColorFromStatusString(status);
        final icon = _getStatusIcon(status);

        return CleanFilterChip(
          label: taskLabelFromStatusString(status, context),
          icon: icon,
          isSelected: isSelected,
          onTap: () => cubit.toggleSelectedTaskStatus(status),
          onLongPress: () => cubit.selectSingleTaskStatus(status),
          selectedColor: backgroundColor,
        );
      },
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'OPEN':
        return Icons.radio_button_unchecked;
      case 'GROOMED':
        return Icons.brush;
      case 'IN PROGRESS':
        return Icons.play_circle_outline;
      case 'BLOCKED':
        return Icons.block;
      case 'ON HOLD':
        return Icons.pause_circle_outline;
      case 'DONE':
        return Icons.check_circle;
      case 'REJECTED':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }
}

class CleanTaskStatusAllChip extends StatelessWidget {
  const CleanTaskStatusAllChip({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        final cubit = context.read<JournalPageCubit>();
        final isSelected = setsEqual(
          snapshot.selectedTaskStatuses,
          snapshot.taskStatuses.toSet(),
        );

        return CleanFilterChip(
          label: 'All',
          icon: Icons.select_all,
          isSelected: isSelected,
          onTap: () {
            if (isSelected) {
              cubit.clearSelectedTaskStatuses();
            } else {
              cubit.selectAllTaskStatuses();
            }
          },
        );
      },
    );
  }
}
