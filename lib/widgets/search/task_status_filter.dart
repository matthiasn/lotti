import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/search/filter_choice_chip.dart';
import 'package:quiver/collection.dart';

class TaskStatusFilter extends StatelessWidget {
  const TaskStatusFilter({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            Text(
              context.messages.taskStatusLabel,
              style: context.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Wrap(
              runSpacing: 10,
              spacing: 5,
              children: [
                ...snapshot.taskStatuses.map(
                  (status) => TaskStatusChip(
                    status,
                    onlySelected: false,
                  ),
                ),
                const TaskStatusAllChip(),
                const SizedBox(width: 5),
              ],
            ),
          ],
        );
      },
    );
  }
}

class TaskStatusChip extends StatelessWidget {
  const TaskStatusChip(
    this.status, {
    required this.onlySelected,
    super.key,
  });

  final String status;
  final bool onlySelected;

  @override
  Widget build(BuildContext context) {
    final localizationLookup = {
      'OPEN': context.messages.taskStatusOpen,
      'GROOMED': context.messages.taskStatusGroomed,
      'IN PROGRESS': context.messages.taskStatusInProgress,
      'BLOCKED': context.messages.taskStatusBlocked,
      'ON HOLD': context.messages.taskStatusOnHold,
      'DONE': context.messages.taskStatusDone,
      'REJECTED': context.messages.taskStatusRejected,
    };

    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        final cubit = context.read<JournalPageCubit>();

        void onTap() {
          cubit.toggleSelectedTaskStatus(status);
          HapticFeedback.heavyImpact();
        }

        void onLongPress() {
          cubit.selectSingleTaskStatus(status);
          HapticFeedback.heavyImpact();
        }

        final isSelected = snapshot.selectedTaskStatuses.contains(status);

        if (onlySelected && !isSelected) {
          return const SizedBox.shrink();
        }

        final backgroundColor = switch (status) {
          'OPEN' => Colors.orange,
          'GROOMED' => Colors.lightGreenAccent,
          'IN PROGRESS' => Colors.blue,
          'BLOCKED' => Colors.red,
          'ON HOLD' => Colors.red,
          'DONE' => Colors.green,
          'REJECTED' => Colors.red,
          String() => Colors.grey,
        };

        return FilterChoiceChip(
          label: '${localizationLookup[status]}',
          isSelected: isSelected,
          onTap: onTap,
          onLongPress: onLongPress,
          selectedColor: backgroundColor,
        );
      },
    );
  }
}

class TaskStatusAllChip extends StatelessWidget {
  const TaskStatusAllChip({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        final cubit = context.read<JournalPageCubit>();

        final isSelected = setsEqual(
          snapshot.selectedTaskStatuses,
          snapshot.taskStatuses.toSet(),
        );

        void onTap() {
          if (isSelected) {
            cubit.clearSelectedTaskStatuses();
          } else {
            cubit.selectAllTaskStatuses();
          }
          HapticFeedback.heavyImpact();
        }

        return FilterChoiceChip(
          label: context.messages.taskStatusAll,
          isSelected: isSelected,
          selectedColor: context.colorScheme.secondary,
          onTap: onTap,
        );
      },
    );
  }
}
