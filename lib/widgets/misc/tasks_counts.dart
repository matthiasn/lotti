import 'package:flutter/material.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

class TaskCounts extends StatelessWidget {
  const TaskCounts({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 5,
        children: [
          Text(
            'Tasks:',
            style: searchLabelStyle(),
          ),
          TasksCountWidget(
            status: 'OPEN',
            label: context.messages.taskStatusOpen,
          ),
          TasksCountWidget(
            status: 'IN PROGRESS',
            label: context.messages.taskStatusInProgress,
          ),
          TasksCountWidget(
            status: 'ON HOLD',
            label: context.messages.taskStatusOnHold,
          ),
          TasksCountWidget(
            status: 'BLOCKED',
            label: context.messages.taskStatusBlocked,
          ),
          TasksCountWidget(
            status: 'DONE',
            label: context.messages.taskStatusDone,
          ),
        ],
      ),
    );
  }
}

class TasksCountWidget extends StatelessWidget {
  TasksCountWidget({
    required this.status,
    required this.label,
    super.key,
  });

  final String status;
  final String label;
  final JournalDb _db = getIt<JournalDb>();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _db.getTasksCount(statuses: [status]),
      builder: (
        BuildContext context,
        AsyncSnapshot<int> snapshot,
      ) {
        if (snapshot.data == null) {
          return const SizedBox.shrink();
        } else {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '${snapshot.data} $label',
              style: searchLabelStyle(),
            ),
          );
        }
      },
    );
  }
}

class FlaggedCount extends StatelessWidget {
  const FlaggedCount({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: getIt<JournalDb>().getCountImportFlagEntries(),
      builder: (
        BuildContext context,
        AsyncSnapshot<int> snapshot,
      ) {
        final count = snapshot.data;
        return Text(
          'Flagged: $count',
          style: searchLabelStyle(),
        );
      },
    );
  }
}
