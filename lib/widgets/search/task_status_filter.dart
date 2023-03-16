import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/widgets/search/filter_choice_chip.dart';
import 'package:quiver/collection.dart';

const horizontalChipMargin = 2.0;

class TaskStatusFilter extends StatelessWidget {
  const TaskStatusFilter({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const SizedBox(width: 5),
              ...snapshot.taskStatuses.map(
                TaskStatusChip.new,
              ),
              const TaskStatusAllChip(),
              const SizedBox(width: 5),
            ],
          ),
        );
      },
    );
  }
}

class TaskStatusChip extends StatelessWidget {
  const TaskStatusChip(
    this.status, {
    super.key,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    final localizationLookup = {
      'OPEN': localizations.taskStatusOpen,
      'GROOMED': localizations.taskStatusGroomed,
      'IN PROGRESS': localizations.taskStatusInProgress,
      'BLOCKED': localizations.taskStatusBlocked,
      'ON HOLD': localizations.taskStatusOnHold,
      'DONE': localizations.taskStatusDone,
      'REJECTED': localizations.taskStatusRejected,
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

        return FilterChoiceChip(
          label: '${localizationLookup[status]}',
          isSelected: snapshot.selectedTaskStatuses.contains(status),
          onTap: onTap,
          onLongPress: onLongPress,
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
          label: 'ALL',
          isSelected: isSelected,
          onTap: onTap,
        );
      },
    );
  }
}
