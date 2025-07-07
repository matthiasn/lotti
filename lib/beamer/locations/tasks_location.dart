import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/ui/pages/infinite_journal_page.dart';
import 'package:lotti/features/tasks/ui/pages/premium_task_details_page_v15.dart';
import 'package:lotti/features/tasks/ui/pages/task_details_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/uuid.dart';

class TasksLocation extends BeamLocation<BeamState> {
  TasksLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => [
        '/tasks',
        '/tasks/:taskId',
      ];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    final taskId = state.pathParameters['taskId'];

    return [
      const BeamPage(
        key: ValueKey('tasks'),
        title: 'Tasks',
        child: InfiniteJournalPage(showTasks: true),
      ),
      if (isUuid(taskId))
        BeamPage(
          key: ValueKey('tasks-$taskId'),
          child: _TaskDetailsWrapper(taskId: taskId!),
        ),
    ];
  }
}

class _TaskDetailsWrapper extends StatelessWidget {
  const _TaskDetailsWrapper({
    required this.taskId,
  });

  final String taskId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: getIt<JournalDb>().getConfigFlag(enablePremiumTaskUiFlag),
      builder: (context, snapshot) {
        final usePremiumTaskUi = snapshot.data ?? false;

        return usePremiumTaskUi
            ? PremiumTaskDetailsPageV15(taskId: taskId)
            : TaskDetailsPage(taskId: taskId);
      },
    );
  }
}
