import 'package:assorted_layout_widgets/assorted_layout_widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';

import 'filter_choice_chip.dart';

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
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: WrapSuper(
            alignment: WrapSuperAlignment.center,
            spacing: 5,
            lineSpacing: 5,
            children: [
              ...snapshot.taskStatuses.map(TaskStatusChip.new),
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
        void onTap() {
          context.read<JournalPageCubit>().toggleSelectedTaskStatus(status);
          HapticFeedback.heavyImpact();
        }

        return FilterChoiceChip(
          label: '${localizationLookup[status]}',
          isSelected: snapshot.selectedTaskStatuses.contains(status),
          onTap: onTap,
        );
      },
    );
  }
}
