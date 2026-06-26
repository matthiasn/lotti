import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/tasks/state/task_focus_controller.dart';
import 'package:lotti/features/tasks/ui/pages/task_details_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';

/// Navigation helper used when the user taps a linked task from inside
/// another task's details surface.
///
/// Desktop: pushes onto `NavService.desktopTaskDetailStack` so the
/// linked task is shown on top of the base task *strictly within the
/// right-hand details pane*. The list pane on the left stays visible.
///
/// Mobile: pushes a [MaterialPageRoute] onto the navigator. On mobile
/// the navigator stack and the visible navigation stack are the same
/// thing, so this is the natural way to layer the linked task.
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

  if (isDesktopLayout(context)) {
    getIt<NavService>().pushDesktopTaskDetail(taskId);
    return;
  }
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => TaskDetailsPage(taskId: taskId),
    ),
  );
}
