import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/themes/theme.dart';

class TaskStatusFilter extends StatefulWidget {
  const TaskStatusFilter({super.key});

  @override
  State<TaskStatusFilter> createState() => _TaskStatusFilterState();
}

class _TaskStatusFilterState extends State<TaskStatusFilter> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        return Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            ...snapshot.taskStatuses.map(TaskStatusChip.new),
          ],
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

        return GestureDetector(
          onTap: () {
            cubit.toggleSelectedTaskStatus(status);
            HapticFeedback.heavyImpact();
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ColoredBox(
                color: snapshot.selectedTaskStatuses.contains(status)
                    ? styleConfig().selectedChoiceChipColor
                    : styleConfig().unselectedChoiceChipColor,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 16,
                  ),
                  child: Text(
                    '${localizationLookup[status]}',
                    style: TextStyle(
                      fontFamily: 'Oswald',
                      fontSize: 16,
                      color: snapshot.selectedTaskStatuses.contains(status)
                          ? styleConfig().selectedChoiceChipTextColor
                          : styleConfig().unselectedChoiceChipTextColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}