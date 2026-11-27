part of 'nav_service.dart';

/// The task document the desktop detail pane shows over its task (ADR 0167):
/// which one, the draft a review route asks it to open, and closing it.
mixin _DesktopTaskDocumentPane {
  ValueNotifier<String?> get desktopSelectedTaskId;
  BeamerDelegate get tasksDelegate;
  String routeForTab(String rootPath);

  /// The task document the desktop detail pane shows over its task, which
  /// stays mounted beneath; null while the task itself shows. Set by
  /// `openTaskDocument` and the `/tasks/:taskId/documents/:documentId` route.
  final ValueNotifier<({String taskId, String documentId})?>
  desktopTaskDocument = ValueNotifier(null);

  /// A draft the `/tasks/:taskId/documents/:documentId/review/…` route asks
  /// the desktop detail pane to open for review, alongside
  /// [desktopTaskDocument]: one-shot, cleared by the document page once the
  /// review is open, so reopening the document later reads it instead.
  final ValueNotifier<
    ({String taskId, String documentId, String changeSetId, int itemIndex})?
  >
  taskDocumentReviewRequest = ValueNotifier(null);

  /// A document is shown over its own task only: selecting another task
  /// closes it, so coming back to the first never reopens it unasked.
  void _closeTaskDocumentWhenAnotherTaskIsSelected() {
    desktopSelectedTaskId.addListener(() {
      final document = desktopTaskDocument.value;
      if (document != null && document.taskId != desktopSelectedTaskId.value) {
        desktopTaskDocument.value = null;
      }
    });
  }

  /// Closes the document the desktop detail pane shows over task [taskId].
  ///
  /// The pane goes back to the task. When the tasks tab stands on a route
  /// that names a document of that task — a link opened it, the review route
  /// included — the route goes back to the task too, replacing it: the
  /// location reopens whatever document its route names on every rebuild,
  /// and the route is what the next launch restores.
  void closeDesktopTaskDocument(String taskId) {
    desktopTaskDocument.value = null;
    if (routeForTab('/tasks').startsWith('/tasks/$taskId/documents/')) {
      tasksDelegate.beamToReplacementNamed('/tasks/$taskId');
    }
  }

  void _disposeTaskDocumentPane() {
    desktopTaskDocument.dispose();
    taskDocumentReviewRequest.dispose();
  }
}
