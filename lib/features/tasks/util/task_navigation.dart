import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
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
void openLinkedTaskDetail({
  required BuildContext context,
  required String taskId,
}) {
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
