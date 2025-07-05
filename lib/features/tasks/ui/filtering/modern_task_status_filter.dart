import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/features/tasks/ui/utils.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modern_filter_chip.dart';
import 'package:lotti/widgets/modal/modern_filter_section.dart';
import 'package:quiver/collection.dart';

class ModernTaskStatusFilter extends StatelessWidget {
  const ModernTaskStatusFilter({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        return ModernFilterSection(
          title: context.messages.taskStatusLabel,
          subtitle: 'Filter tasks by their current status',
          children: [
            ...snapshot.taskStatuses.map(
              (status) => ModernTaskStatusChip(status: status),
            ),
            const ModernTaskStatusAllChip(),
          ],
        );
      },
    );
  }
}

class ModernTaskStatusChip extends StatelessWidget {
  const ModernTaskStatusChip({
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

        return ModernFilterChip(
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
        return Icons.radio_button_unchecked_rounded;
      case 'GROOMED':
        return Icons.brush_rounded;
      case 'IN PROGRESS':
        return Icons.play_circle_outline_rounded;
      case 'BLOCKED':
        return Icons.block_rounded;
      case 'ON HOLD':
        return Icons.pause_circle_outline_rounded;
      case 'DONE':
        return Icons.check_circle_rounded;
      case 'REJECTED':
        return Icons.cancel_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }
}

class ModernTaskStatusAllChip extends StatelessWidget {
  const ModernTaskStatusAllChip({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        final cubit = context.read<JournalPageCubit>();
        final isSelected = setsEqual(
          snapshot.selectedTaskStatuses,
          snapshot.taskStatuses.toSet(),
        );

        return ModernFilterChip(
          label: context.messages.taskStatusAll,
          icon: Icons.select_all_rounded,
          isSelected: isSelected,
          onTap: () {
            if (isSelected) {
              cubit.clearSelectedTaskStatuses();
            } else {
              cubit.selectAllTaskStatuses();
            }
          },
          selectedColor: context.colorScheme.primary,
        );
      },
    );
  }
}
