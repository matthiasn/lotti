import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/history/domain/history_entry.dart';
import 'package:lotti/features/history/state/history_providers.dart';
import 'package:lotti/features/tasks/ui/pages/task_details_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/task_focus_controller.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart' show isPushedPage;
import 'package:material_ui/material_ui.dart';

/// Navigation helper used when the user taps a linked task from inside
/// another task's details surface.
///
/// Desktop: pushes onto `NavService.desktopTaskDetailStack` so the
/// linked task is shown on top of the base task *strictly within the
/// right-hand details pane*. The list pane on the left stays visible.
///
/// Mobile, or a task page that was itself pushed ([isPushedPage]) — over the
/// companion's chat, or the plaza, where the split pane is hidden beneath —
/// pushes a [MaterialPageRoute] onto the navigator, layering the linked task
/// on the page the user is looking at.
///
/// [focusSuggestions] publishes a task focus intent before navigation so an
/// already-mounted detail page can scroll to its task-agent proposal section,
/// and a newly-mounted detail page can consume the same intent after load.
void openLinkedTaskDetail({
  required BuildContext context,
  required String taskId,
  bool focusSuggestions = false,
}) {
  if (focusSuggestions) {
    ProviderScope.containerOf(
          context,
          listen: false,
        )
        .read(taskFocusControllerProvider(taskId).notifier)
        .publishSuggestionFocus();
  }

  if (isDesktopLayout(context) && !isPushedPage(context)) {
    getIt<NavService>().pushDesktopTaskDetail(taskId);
    return;
  }
  pushTaskDetailPage(context, taskId);
}

/// Opens [taskId]'s details as a page pushed onto the navigator, on top of
/// whatever is showing — on [rootNavigator] above a dialog such as the
/// companion's chat — so back pops it and lands where the user came from,
/// rather than on the task list.
void pushTaskDetailPage(
  BuildContext context,
  String taskId, {
  bool rootNavigator = false,
}) {
  // The push leaves the URL alone, so the history recorder — which follows
  // routes and the desktop selection — is told the task's id directly.
  ProviderScope.containerOf(context, listen: false)
      .read(historyRecorderProvider)
      ?.recordVisit(
        HistoryTarget(
          kind: HistoryEntityKind.task,
          entityId: taskId,
          route: '/tasks/$taskId',
        ),
      );
  Navigator.of(context, rootNavigator: rootNavigator).push(
    MaterialPageRoute<void>(
      builder: (context) => TaskDetailsPage(taskId: taskId),
    ),
  );
}
