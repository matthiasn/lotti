import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/tasks/ui/pages/task_details_page.dart';
import 'package:lotti/features/tasks/ui/pages/tasks_root_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
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
    final navService = getIt<NavService>();
    final isDesktop = navService.isDesktopMode;

    if (isDesktop) {
      navService.resetDesktopTaskDetail(isUuid(taskId) ? taskId : null);
    }

    return [
      const BeamPage(
        key: ValueKey('tasks'),
        title: 'Tasks',
        child: TasksRootPage(),
      ),
      if (!isDesktop && isUuid(taskId))
        BeamPage(
          key: ValueKey('tasks-$taskId'),
          child: TaskDetailsPage(taskId: taskId!),
        ),
    ];
  }
}
