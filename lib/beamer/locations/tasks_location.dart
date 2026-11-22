import 'dart:async';

import 'package:beamer/beamer.dart';
import 'package:lotti/features/documents/ui/task_document_page.dart';
import 'package:lotti/features/tasks/ui/pages/task_details_page.dart';
import 'package:lotti/features/tasks/ui/pages/tasks_root_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/uuid.dart';
import 'package:material_ui/material_ui.dart';

class TasksLocation extends BeamLocation<BeamState> {
  TasksLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => [
    '/tasks',
    '/tasks/:taskId',
    '/tasks/:taskId/documents/:documentId',
  ];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    final taskId = state.pathParameters['taskId'];
    final documentId = state.pathParameters['documentId'];
    final navService = getIt<NavService>();
    final isDesktop = navService.isDesktopMode;

    if (isDesktop) {
      final desktopTaskId = isUuid(taskId) ? taskId : null;
      scheduleMicrotask(() {
        if (getIt.isRegistered<NavService>() &&
            identical(getIt<NavService>(), navService)) {
          navService.resetDesktopTaskDetail(desktopTaskId);
          // The document the URL names opens over its task in the detail
          // pane; a URL that names none returns the pane to the task.
          navService.desktopTaskDocument.value =
              desktopTaskId != null && isUuid(documentId)
              ? (taskId: desktopTaskId, documentId: documentId!)
              : null;
        }
      });
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
      if (!isDesktop && isUuid(taskId) && isUuid(documentId))
        BeamPage(
          key: ValueKey('task-document-$documentId'),
          child: TaskDocumentPage(taskId: taskId!, documentId: documentId!),
        ),
    ];
  }
}
