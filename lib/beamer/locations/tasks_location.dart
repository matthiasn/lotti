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
    // A version of the document, opened side by side with the one before
    // it.
    '/tasks/:taskId/documents/:documentId/review/:versionId',
  ];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    final taskId = state.pathParameters['taskId'];
    final documentId = state.pathParameters['documentId'];
    final navService = getIt<NavService>();
    final isDesktop = navService.isDesktopMode;
    final review = _review(state, taskId: taskId, documentId: documentId);

    if (isDesktop) {
      final desktopTaskId = isUuid(taskId) ? taskId : null;
      scheduleMicrotask(() {
        if (getIt.isRegistered<NavService>() &&
            identical(getIt<NavService>(), navService)) {
          navService
            ..resetDesktopTaskDetail(desktopTaskId)
            // Before the document, so the pane opening it sees the version.
            ..taskDocumentReviewRequest.value = review;
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
          child: TaskDocumentPage(
            taskId: taskId!,
            documentId: documentId!,
            initialReview: review,
          ),
        ),
    ];
  }

  /// The version the URL opens for review; null when it names none, or
  /// names one malformed.
  static ({String taskId, String documentId, String versionId})? _review(
    BeamState state, {
    String? taskId,
    String? documentId,
  }) {
    final versionId = state.pathParameters['versionId'];
    if (!isUuid(taskId) || !isUuid(documentId) || !isUuid(versionId)) {
      return null;
    }
    return (
      taskId: taskId!,
      documentId: documentId!,
      versionId: versionId!,
    );
  }
}
