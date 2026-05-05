import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/tasks/state/task_focus_controller.dart';
import 'package:lotti/services/nav_service.dart';

/// Shared navigation behavior for the running-timer surfaces (the
/// mobile bottom-nav `TimeRecordingIndicator` and the desktop
/// `SidebarTimerSection`). Tapping either should resolve to the same
/// destination, so the routing is centralised here to keep them in
/// sync as the route shape evolves.
///
/// When the timer is linked to a Task, this also publishes a
/// [taskFocusControllerProvider] focus intent so the task detail page
/// scrolls the timer entry into view on arrival.
void navigateToTimerTarget({
  required JournalEntity current,
  required JournalEntity? linkedFrom,
  required WidgetRef ref,
}) {
  if (linkedFrom is Task) {
    publishTaskFocus(
      taskId: linkedFrom.meta.id,
      entryId: current.meta.id,
      ref: ref,
    );
    beamToNamed('/tasks/${linkedFrom.meta.id}');
    return;
  }
  if (linkedFrom != null) {
    beamToNamed('/journal/${linkedFrom.meta.id}');
    return;
  }
  beamToNamed('/journal/${current.meta.id}');
}
