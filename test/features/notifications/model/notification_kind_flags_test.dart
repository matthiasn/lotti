import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/features/notifications/model/notification_kind_flags.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/utils/consts.dart';

void main() {
  final meta = NotificationMeta(
    id: 'row',
    createdAt: DateTime(2026, 9, 16),
    updatedAt: DateTime(2026, 9, 16),
    scheduledFor: DateTime(2026, 9, 17, 9),
    vectorClock: const VectorClock({}),
    originatingHostId: 'host',
  );

  /// Every variant of the union, with the switch each one answers to.
  final cases = <(String, NotificationEntity, String)>[
    (
      'task suggestion',
      NotificationEntity.taskSuggestion(
        meta: meta,
        linkedTaskId: 'task-1',
        suggestionCount: 2,
        title: 't',
        body: 'b',
      ),
      notifyTaskSuggestionsFlag,
    ),
    (
      'overdue task',
      NotificationEntity.taskOverdue(
        meta: meta,
        linkedTaskId: 'task-1',
        title: 't',
        body: 'b',
      ),
      notifyTaskSuggestionsFlag,
    ),
    (
      'check-in reminder',
      NotificationEntity.relationshipCheckIn(
        meta: meta,
        linkedRelationshipId: 'rel-1',
        title: 't',
        body: 'b',
      ),
      notifyCheckInRemindersFlag,
    ),
    (
      'goal off track',
      NotificationEntity.goalOffTrack(
        meta: meta,
        linkedGoalAgentId: 'agent-1',
        title: 't',
        body: 'b',
      ),
      notifyGoalAlertsFlag,
    ),
    (
      'habit auto-completed',
      NotificationEntity.habitAutoCompleted(
        meta: meta,
        linkedHabitIds: const ['habit-1'],
        dayKey: '2026-09-16',
        title: 't',
        body: 'b',
      ),
      notifyHabitAutoCompletionsFlag,
    ),
    (
      'day plan outcome',
      NotificationEntity.dayPlanOutcome(
        meta: meta,
        dayId: 'day-1',
        succeeded: true,
        title: 't',
        body: 'b',
      ),
      notifyDayPlanOutcomesFlag,
    ),
    (
      'sync conflict',
      NotificationEntity.syncConflict(
        meta: meta,
        conflictCount: 1,
        title: 't',
        body: 'b',
      ),
      notifySyncConflictsFlag,
    ),
  ];

  group('notificationFlagFor', () {
    for (final (name, entity, flag) in cases) {
      test('$name answers to $flag', () {
        expect(notificationFlagFor(entity), flag);
      });
    }

    test('an overdue task shares the suggestion switch', () {
      // Both are "an agent has something to say about a task"; one switch
      // is what the page offers, so the two variants must agree.
      final suggestion = cases[0].$2;
      final overdue = cases[1].$2;
      expect(notificationFlagFor(overdue), notificationFlagFor(suggestion));
    });
  });

  group('notificationRowKindFlags', () {
    test('names every switch a row can answer to, each once', () {
      final answered = {
        for (final (_, entity, _) in cases) notificationFlagFor(entity),
      };
      expect(notificationRowKindFlags.toSet(), answered);
      expect(
        notificationRowKindFlags.toSet(),
        hasLength(notificationRowKindFlags.length),
      );
    });

    test('leaves out the switches that govern no row', () {
      // Habit reminders are alarms without a row and the badge is a count,
      // so the reconcile that these flags trigger has nothing to do for them.
      expect(
        notificationRowKindFlags,
        isNot(contains(notifyHabitRemindersFlag)),
      );
      expect(notificationRowKindFlags, isNot(contains(showTaskBadgeFlag)));
      expect(
        notificationRowKindFlags,
        isNot(contains(enableNotificationsFlag)),
      );
      // The wording switch changes what the next wake writes, never what is
      // armed now, so a flip has nothing to reconcile.
      expect(notificationRowKindFlags, isNot(contains(notifyAgentCopyFlag)));
    });
  });
}
