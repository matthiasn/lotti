import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/journal/ui/pages/infinite_journal_page.dart';
import 'package:lotti/features/speech/ui/pages/record_audio_page.dart';
import 'package:lotti/features/tasks/ui/pages/task_details_page.dart';
import 'package:lotti/utils/uuid.dart';

class TasksLocation extends BeamLocation<BeamState> {
  TasksLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => [
        '/tasks',
        '/tasks/:taskId',
        '/tasks/:taskId/record_audio/:linkedId',
      ];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    bool pathContains(String s) => state.uri.path.contains(s);

    final taskId = state.pathParameters['taskId'];
    final linkedId = state.pathParameters['linkedId'];
    final categoryId = state.queryParameters['categoryId'];

    return [
      const BeamPage(
        key: ValueKey('tasks'),
        title: 'Tasks',
        child: InfiniteJournalPage(showTasks: true),
      ),
      if (isUuid(taskId))
        BeamPage(
          key: ValueKey('tasks-$taskId'),
          child: TaskDetailsPage(taskId: taskId!),
        ),
      if (pathContains('record_audio/'))
        BeamPage(
          key: ValueKey('record_audio-$linkedId'),
          child: RecordAudioPage(linkedId: linkedId, categoryId: categoryId),
        ),
    ];
  }
}
