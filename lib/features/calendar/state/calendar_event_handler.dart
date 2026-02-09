import 'dart:developer';

import 'package:calendar_view/calendar_view.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/calendar/state/calendar_event.dart';
import 'package:lotti/features/calendar/ui/pages/day_view_page.dart';
import 'package:lotti/features/journal/state/journal_focus_controller.dart';
import 'package:lotti/features/tasks/state/task_focus_controller.dart';
import 'package:lotti/services/nav_service.dart';

/// Handles calendar event tap interactions by publishing focus intents
/// and navigating to the appropriate page.
///
/// The [ref] parameter accepts both WidgetRef (for widgets) and
/// ProviderContainer (for tests).
void handleCalendarEventTap(
  List<CalendarEventData<Object?>> events,
  DateTime date,
  dynamic ref,
) {
  final event = events.firstOrNull?.event as CalendarEvent?;
  final id = event?.entity.id;
  final linkedFrom = event?.linkedFrom;

  if (id == null) return;

  log('CAL_TAP entity=${event?.entity.runtimeType} id=$id '
      'linkedFrom=${linkedFrom?.runtimeType}:${linkedFrom?.meta.id}');

  // Skip RatingEntry parents — ratings are children of time entries,
  // not meaningful navigation targets from the calendar.
  final effectiveLinkedFrom = (linkedFrom is RatingEntry) ? null : linkedFrom;

  if (effectiveLinkedFrom != null) {
    if (effectiveLinkedFrom is Task) {
      // Publish task focus intent before navigation
      // ignore: avoid_dynamic_calls
      ref
          .read(
            taskFocusControllerProvider(id: effectiveLinkedFrom.meta.id)
                .notifier,
          )
          .publishTaskFocus(entryId: id, alignment: kDefaultScrollAlignment);
      beamToNamed('/tasks/${effectiveLinkedFrom.meta.id}');
    } else {
      // Publish journal focus intent before navigation
      // ignore: avoid_dynamic_calls
      ref
          .read(
            journalFocusControllerProvider(id: effectiveLinkedFrom.meta.id)
                .notifier,
          )
          .publishJournalFocus(entryId: id, alignment: kDefaultScrollAlignment);
      beamToNamed('/journal/${effectiveLinkedFrom.meta.id}');
    }
  } else {
    beamToNamed('/journal/$id');
  }
}
