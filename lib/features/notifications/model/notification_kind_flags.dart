import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/utils/consts.dart';

/// The config flag that lets [entity]'s kind reach the OS.
///
/// Exhaustive over the union: a new variant does not compile until it names
/// the preference that governs it, so no kind can slip past the Notifications
/// page unlisted. The flag decides whether the scheduler projects the row into
/// an OS alert, nothing else — the row lands in the inbox regardless.
String notificationFlagFor(NotificationEntity entity) => switch (entity) {
  // Suggestions and overdue reminders are two faces of one preference: both
  // are "an agent has something to say about a task".
  TaskSuggestionNotification() ||
  TaskOverdueNotification() => notifyTaskSuggestionsFlag,
  RelationshipCheckInNotification() => notifyCheckInRemindersFlag,
  GoalOffTrackNotification() => notifyGoalAlertsFlag,
  HabitAutoCompletedNotification() => notifyHabitAutoCompletionsFlag,
  DayPlanOutcomeNotification() => notifyDayPlanOutcomesFlag,
  SyncConflictNotification() => notifySyncConflictsFlag,
};

/// The per-kind flags that govern inbox rows. Flipping any of them re-runs
/// the scheduler's reconcile, which re-arms the rows of a kind switched on
/// and drops the alarms of one switched off.
///
/// Habit reminders are not here: they are OS alarms without a row, armed
/// straight from the habit definition, so their flag is applied by re-arming
/// or cancelling those alarms instead.
const List<String> notificationRowKindFlags = [
  notifyTaskSuggestionsFlag,
  notifyCheckInRemindersFlag,
  notifyGoalAlertsFlag,
  notifyHabitAutoCompletionsFlag,
  notifyDayPlanOutcomesFlag,
  notifySyncConflictsFlag,
];
