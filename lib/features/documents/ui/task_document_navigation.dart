import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/documents/ui/task_document_page.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart' show isPushedPage;
import 'package:material_ui/material_ui.dart';

/// Opens document [documentId] of task [taskId] where the task is shown —
/// the same rule `openLinkedTaskDetail` follows for a linked task.
///
/// Desktop: the detail pane shows the document over its task
/// (`NavService.desktopTaskDocument`), the task page kept mounted beneath so
/// closing the document returns to it as it was, and the list pane stays.
///
/// Mobile, or a task page that was itself pushed ([isPushedPage]): pushes
/// the document page onto the navigator, so back lands on the task.
void openTaskDocument(
  BuildContext context, {
  required String taskId,
  required String documentId,
}) {
  if (isDesktopLayout(context) && !isPushedPage(context)) {
    ProviderScope.containerOf(
      context,
      listen: false,
    ).read(navServiceProvider).desktopTaskDocument.value = (
      taskId: taskId,
      documentId: documentId,
    );
    return;
  }
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TaskDocumentPage(taskId: taskId, documentId: documentId),
    ),
  );
}
