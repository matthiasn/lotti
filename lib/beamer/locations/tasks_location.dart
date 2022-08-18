import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/pages/journal/entry_details_page.dart';
import 'package:lotti/pages/tasks/tasks_page.dart';

class TasksLocation extends BeamLocation<BeamState> {
  TasksLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => ['/tasks/:taskId'];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) => [
        const BeamPage(
          key: ValueKey('tasks'),
          title: 'Tasks',
          type: BeamPageType.noTransition,
          child: TasksPage(),
        ),
        if (state.pathParameters.containsKey('taskId'))
          BeamPage(
            key: ValueKey('tasks-${state.pathParameters['taskId']}'),
            child: EntryDetailPage(
              itemId: state.pathParameters['taskId']!,
            ),
          ),
      ];
}
