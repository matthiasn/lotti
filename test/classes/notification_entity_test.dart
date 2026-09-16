import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/features/sync/vector_clock.dart';

void main() {
  group('NotificationEntityFields', () {
    test('exposes meta-derived getters for taskSuggestion', () {
      final entity = _suggestion(
        id: 'sg-1',
        linkedTaskId: 'task-1',
        title: 'Suggestion title',
        body: 'Suggestion body',
      );

      expect(entity.id, 'sg-1');
      expect(entity.meta.id, 'sg-1');
      expect(entity.title, 'Suggestion title');
      expect(entity.body, 'Suggestion body');
      expect(entity.type, 'taskSuggestion');
      expect(entity.linkedEntityId, 'task-1');
    });

    test('exposes meta-derived getters for taskOverdue', () {
      final entity = _overdue(
        id: 'od-1',
        linkedTaskId: 'task-2',
        title: 'Overdue title',
        body: 'Overdue body',
      );

      expect(entity.id, 'od-1');
      expect(entity.title, 'Overdue title');
      expect(entity.body, 'Overdue body');
      expect(entity.type, 'taskOverdue');
      expect(entity.linkedEntityId, 'task-2');
    });

    test('copyWithMeta swaps meta while preserving variant content', () {
      final entity = _suggestion(
        id: 'sg-2',
        linkedTaskId: 'task-3',
        title: 'Original',
        body: 'Body',
      );
      final replacement = entity.meta.copyWith(
        seenAt: DateTime.utc(2026, 5, 17, 11),
        vectorClock: const VectorClock({'host-b': 5}),
      );

      final updated = entity.copyWithMeta(replacement);

      expect(updated, isA<TaskSuggestionNotification>());
      final updatedSuggestion = updated as TaskSuggestionNotification;
      expect(updatedSuggestion.linkedTaskId, 'task-3');
      expect(updatedSuggestion.title, 'Original');
      expect(updatedSuggestion.body, 'Body');
      expect(updatedSuggestion.suggestionCount, 2);
      expect(updated.meta.seenAt, DateTime.utc(2026, 5, 17, 11));
      expect(updated.meta.vectorClock, const VectorClock({'host-b': 5}));
    });

    test('exposes meta-derived getters for relationshipCheckIn', () {
      final entity = _checkIn(
        id: 'ci-1',
        linkedRelationshipId: 'rel-7',
        title: 'Check in with Anna?',
        body: 'A good moment to reach out.',
      );

      expect(entity.id, 'ci-1');
      expect(entity.title, 'Check in with Anna?');
      expect(entity.body, 'A good moment to reach out.');
      expect(entity.type, 'relationshipCheckIn');
      // The shared getter answers for this variant too — which is exactly why
      // consumers must switch on the union rather than read it and assume a
      // task (see NotificationScheduler._deepLinkFor).
      expect(entity.linkedEntityId, 'rel-7');
    });

    test('copyWithMeta preserves the relationshipCheckIn variant', () {
      final entity = _checkIn(
        id: 'ci-2',
        linkedRelationshipId: 'rel-8',
        title: 'Title',
        body: 'Body',
      );
      final replacement = entity.meta.copyWith(
        deletedAt: DateTime.utc(2026, 5, 17, 16),
      );

      final updated = entity.copyWithMeta(replacement);

      expect(updated, isA<RelationshipCheckInNotification>());
      final updatedCheckIn = updated as RelationshipCheckInNotification;
      expect(updatedCheckIn.linkedRelationshipId, 'rel-8');
      expect(updatedCheckIn.title, 'Title');
      expect(updatedCheckIn.body, 'Body');
      expect(updated.meta.deletedAt, DateTime.utc(2026, 5, 17, 16));
    });

    test('a habitAutoCompleted row links no single entity', () {
      final entity = _habitAuto(id: 'ha-1', linkedHabitIds: ['h1', 'h2']);

      expect(entity.type, 'habitAutoCompleted');
      expect(entity.title, 'Title');
      expect(entity.body, 'Body');
      // A grouped row leads to the habits page, not to one habit, so the
      // shared getter must not pretend otherwise.
      expect(entity.linkedEntityId, isNull);
    });

    test('copyWithMeta preserves the habitAutoCompleted variant', () {
      final entity = _habitAuto(id: 'ha-2', linkedHabitIds: ['h1', 'h2']);
      final replacement = entity.meta.copyWith(
        seenAt: DateTime.utc(2026, 5, 17, 16),
      );

      final updated = entity.copyWithMeta(replacement);

      expect(updated, isA<HabitAutoCompletedNotification>());
      final updatedHabit = updated as HabitAutoCompletedNotification;
      expect(updatedHabit.linkedHabitIds, ['h1', 'h2']);
      expect(updatedHabit.dayKey, '2026-05-17');
      expect(updated.meta.seenAt, DateTime.utc(2026, 5, 17, 16));
    });

    test('a goalOffTrack row links the goal agent', () {
      final entity = _goalOffTrack(
        id: 'go-1',
        linkedGoalAgentId: 'goal-agent-7',
        title: 'Daily steps is off track',
        body: 'A good moment to get back on it.',
      );

      expect(entity.id, 'go-1');
      expect(entity.type, 'goalOffTrack');
      expect(entity.title, 'Daily steps is off track');
      expect(entity.body, 'A good moment to get back on it.');
      // The agent, not a journal goal id: the goal detail route is keyed by
      // the agent, and so is every register and banner the alert reflects.
      expect(entity.linkedEntityId, 'goal-agent-7');
    });

    test('copyWithMeta preserves the goalOffTrack variant', () {
      final entity = _goalOffTrack(
        id: 'go-2',
        linkedGoalAgentId: 'goal-agent-8',
        title: 'Title',
        body: 'Body',
      );
      final replacement = entity.meta.copyWith(
        actedOnAt: DateTime.utc(2026, 5, 17, 16),
      );

      final updated = entity.copyWithMeta(replacement);

      expect(updated, isA<GoalOffTrackNotification>());
      final updatedGoal = updated as GoalOffTrackNotification;
      expect(updatedGoal.linkedGoalAgentId, 'goal-agent-8');
      expect(updatedGoal.title, 'Title');
      expect(updatedGoal.body, 'Body');
      expect(updated.meta.actedOnAt, DateTime.utc(2026, 5, 17, 16));
    });

    test('a dayPlanOutcome row links the day it planned', () {
      final entity = _dayPlanOutcome(id: 'dp-1', dayId: 'dayplan-2026-07-22');

      expect(entity.type, 'dayPlanOutcome');
      expect(entity.title, 'Title');
      expect(entity.body, 'Body');
      // The day is the subject: a later outcome for the same day retracts an
      // earlier one by this id.
      expect(entity.linkedEntityId, 'dayplan-2026-07-22');
    });

    test('copyWithMeta preserves the dayPlanOutcome variant', () {
      final entity = _dayPlanOutcome(
        id: 'dp-2',
        dayId: 'dayplan-2026-07-22',
        succeeded: false,
      );
      final replacement = entity.meta.copyWith(
        seenAt: DateTime.utc(2026, 5, 17, 16),
      );

      final updated = entity.copyWithMeta(replacement);

      expect(updated, isA<DayPlanOutcomeNotification>());
      final updatedOutcome = updated as DayPlanOutcomeNotification;
      expect(updatedOutcome.dayId, 'dayplan-2026-07-22');
      expect(updatedOutcome.succeeded, isFalse);
      expect(updatedOutcome.title, 'Title');
      expect(updated.meta.seenAt, DateTime.utc(2026, 5, 17, 16));
    });

    test('a syncConflict row links the conflicts list, not an entry', () {
      final entity = _syncConflict(id: 'sc-1', conflictCount: 3);

      expect(entity.type, 'syncConflict');
      // No entry of its own — the pseudo subject is what lets a later burst
      // retract the earlier row.
      expect(entity.linkedEntityId, syncConflictsSubjectId);
    });

    test('copyWithMeta preserves the syncConflict variant', () {
      final entity = _syncConflict(id: 'sc-2', conflictCount: 3);
      final replacement = entity.meta.copyWith(
        deletedAt: DateTime.utc(2026, 5, 17, 16),
      );

      final updated = entity.copyWithMeta(replacement);

      expect(updated, isA<SyncConflictNotification>());
      expect((updated as SyncConflictNotification).conflictCount, 3);
      expect(updated.meta.deletedAt, DateTime.utc(2026, 5, 17, 16));
    });

    test("only rows about this device's own processing stay local", () {
      // Exhaustive over the union: a peer that receives a lifecycle mark for
      // a row it never got keeps the event pending forever, so the choice is
      // load-bearing for every variant.
      final local = <String>{
        for (final entity in <NotificationEntity>[
          _suggestion(id: 'a', linkedTaskId: 't', title: 'x', body: 'y'),
          _overdue(id: 'b', linkedTaskId: 't', title: 'x', body: 'y'),
          _checkIn(id: 'c', linkedRelationshipId: 'r', title: 'x', body: 'y'),
          _habitAuto(id: 'd', linkedHabitIds: ['h']),
          _goalOffTrack(id: 'e', linkedGoalAgentId: 'g', title: 'x', body: 'y'),
          _dayPlanOutcome(id: 'f', dayId: 'day'),
          _syncConflict(id: 'g', conflictCount: 1),
        ])
          if (entity.isDeviceLocal) entity.type,
      };

      expect(local, {'dayPlanOutcome', 'syncConflict'});
    });

    test('copyWithMeta preserves the overdue variant', () {
      final entity = _overdue(
        id: 'od-2',
        linkedTaskId: 'task-4',
        title: 'Hello',
        body: 'World',
      );
      final replacement = entity.meta.copyWith(
        deletedAt: DateTime.utc(2026, 5, 17, 12),
      );

      final updated = entity.copyWithMeta(replacement);

      expect(updated, isA<TaskOverdueNotification>());
      final updatedOverdue = updated as TaskOverdueNotification;
      expect(updatedOverdue.linkedTaskId, 'task-4');
      expect(updatedOverdue.title, 'Hello');
      expect(updatedOverdue.body, 'World');
      expect(updated.meta.deletedAt, DateTime.utc(2026, 5, 17, 12));
    });
  });

  group('NotificationKinds', () {
    test('names the wire discriminator of every variant', () {
      // A producer derives its episode ids from a kind and retracts rows by
      // it, so the constants and `type` must never disagree — and the strings
      // are the sync wire format, so neither may move.
      final meta = NotificationMeta(
        id: 'k',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        scheduledFor: DateTime(2026),
        vectorClock: const VectorClock({}),
        originatingHostId: '',
      );
      final byVariant = <String, NotificationEntity>{
        'taskSuggestion': NotificationEntity.taskSuggestion(
          meta: meta,
          linkedTaskId: 't',
          suggestionCount: 1,
          title: 'a',
          body: 'b',
        ),
        'taskOverdue': NotificationEntity.taskOverdue(
          meta: meta,
          linkedTaskId: 't',
          title: 'a',
          body: 'b',
        ),
        'relationshipCheckIn': NotificationEntity.relationshipCheckIn(
          meta: meta,
          linkedRelationshipId: 'r',
          title: 'a',
          body: 'b',
        ),
        'habitAutoCompleted': NotificationEntity.habitAutoCompleted(
          meta: meta,
          linkedHabitIds: const ['h'],
          dayKey: '2026-01-01',
          title: 'a',
          body: 'b',
        ),
        'goalOffTrack': NotificationEntity.goalOffTrack(
          meta: meta,
          linkedGoalAgentId: 'g',
          title: 'a',
          body: 'b',
        ),
        'dayPlanOutcome': NotificationEntity.dayPlanOutcome(
          meta: meta,
          dayId: 'day',
          succeeded: true,
          title: 'a',
          body: 'b',
        ),
        'syncConflict': NotificationEntity.syncConflict(
          meta: meta,
          conflictCount: 2,
          title: 'a',
          body: 'b',
        ),
      };

      expect(
        byVariant['taskSuggestion']!.type,
        NotificationKinds.taskSuggestion,
      );
      expect(byVariant['taskOverdue']!.type, NotificationKinds.taskOverdue);
      expect(
        byVariant['relationshipCheckIn']!.type,
        NotificationKinds.relationshipCheckIn,
      );
      expect(
        byVariant['habitAutoCompleted']!.type,
        NotificationKinds.habitAutoCompleted,
      );
      expect(byVariant['goalOffTrack']!.type, NotificationKinds.goalOffTrack);
      expect(
        byVariant['dayPlanOutcome']!.type,
        NotificationKinds.dayPlanOutcome,
      );
      expect(byVariant['syncConflict']!.type, NotificationKinds.syncConflict);
      for (final entry in byVariant.entries) {
        expect(entry.value.type, entry.key);
      }
    });
  });

  group('NotificationMeta standalone round-trip', () {
    NotificationMeta roundTrip(NotificationMeta meta) =>
        NotificationMeta.fromJson(
          jsonDecode(jsonEncode(meta.toJson())) as Map<String, dynamic>,
        );

    test('serializes every field including the optional DateTimes', () {
      final meta = NotificationMeta(
        id: 'meta-1',
        createdAt: DateTime.utc(2026, 5, 17, 8),
        updatedAt: DateTime.utc(2026, 5, 17, 9),
        scheduledFor: DateTime.utc(2026, 5, 17, 12),
        vectorClock: const VectorClock({'host': 3, 'shared': 7}),
        originatingHostId: 'host-1',
        seenAt: DateTime.utc(2026, 5, 17, 13),
        actedOnAt: DateTime.utc(2026, 5, 17, 14),
        deletedAt: DateTime.utc(2026, 5, 17, 15),
        category: 'cat-9',
      );

      final decoded = roundTrip(meta);
      expect(decoded, meta);
      expect(decoded.scheduledFor, meta.scheduledFor);
      expect(decoded.vectorClock, meta.vectorClock);
    });

    test('optional fields survive as null', () {
      final meta = NotificationMeta(
        id: 'meta-2',
        createdAt: DateTime.utc(2026, 5, 17, 8),
        updatedAt: DateTime.utc(2026, 5, 17, 9),
        scheduledFor: DateTime.utc(2026, 5, 17, 12),
        vectorClock: const VectorClock({'host': 1}),
        originatingHostId: 'host-2',
      );

      final decoded = roundTrip(meta);
      expect(decoded, meta);
      expect(decoded.seenAt, isNull);
      expect(decoded.actedOnAt, isNull);
      expect(decoded.deletedAt, isNull);
      expect(decoded.category, isNull);
    });
  });

  group('NotificationEntity JSON round-trip', () {
    glados.Glados<_GeneratedEntity>(
      glados.any.notificationEntity,
      glados.ExploreConfig(numRuns: 80),
    ).test('round-trips through fromJson/toJson', (generated) {
      final entity = generated.entity;

      final decoded = NotificationEntity.fromJson(
        jsonDecode(jsonEncode(entity.toJson())) as Map<String, dynamic>,
      );

      expect(decoded, entity);
      expect(decoded.type, entity.type);
      expect(decoded.title, entity.title);
      expect(decoded.body, entity.body);
      expect(decoded.linkedEntityId, entity.linkedEntityId);
      expect(decoded.meta, entity.meta);
    }, tags: 'glados');
  });

  // The union discriminator is the sync wire format. Renaming a variant would
  // make every already-synced row of that kind undecodable on upgrade, so the
  // strings are pinned here rather than left to whatever freezed emits.
  group('NotificationEntity wire compatibility', () {
    test('discriminators match the persisted type column', () {
      final rows = <NotificationEntity, String>{
        _suggestion(
          id: 'a',
          linkedTaskId: 't',
          title: 'x',
          body: 'y',
        ): 'taskSuggestion',
        _overdue(
          id: 'b',
          linkedTaskId: 't',
          title: 'x',
          body: 'y',
        ): 'taskOverdue',
        _checkIn(
          id: 'c',
          linkedRelationshipId: 'r',
          title: 'x',
          body: 'y',
        ): 'relationshipCheckIn',
        _habitAuto(id: 'd', linkedHabitIds: ['h1', 'h2']): 'habitAutoCompleted',
        _goalOffTrack(
          id: 'e',
          linkedGoalAgentId: 'g',
          title: 'x',
          body: 'y',
        ): 'goalOffTrack',
        _dayPlanOutcome(id: 'f', dayId: 'd'): 'dayPlanOutcome',
        _syncConflict(id: 'g', conflictCount: 1): 'syncConflict',
      };

      for (final row in rows.entries) {
        expect(row.key.toJson()['runtimeType'], row.value);
        expect(row.key.type, row.value);
      }
    });

    test('a variant this build does not know throws rather than guessing', () {
      // This is what an older peer does when a newer one syncs a
      // relationshipCheckIn row. The sync processor turns the throw into
      // `UnrecoverableSyncPayloadException` and skips the event, so the row is
      // dropped with a log rather than retried forever — the mixed-fleet
      // degradation path this variant relies on.
      final json =
          jsonDecode(
                jsonEncode(
                  _checkIn(
                    id: 'c',
                    linkedRelationshipId: 'r',
                    title: 'x',
                    body: 'y',
                  ).toJson(),
                ),
              )
              as Map<String, dynamic>;
      json['runtimeType'] = 'somethingFromTheFuture';

      expect(() => NotificationEntity.fromJson(json), throwsA(isA<Object>()));
    });
  });

  group('NotificationEntityFields.copyWithCopy', () {
    final meta = NotificationMeta(
      id: 'row',
      createdAt: DateTime.utc(2026, 9, 16),
      updatedAt: DateTime.utc(2026, 9, 16),
      scheduledFor: DateTime.utc(2026, 9, 17, 9),
      vectorClock: const VectorClock({'host-a': 1}),
      originatingHostId: 'host-a',
    );

    /// Every variant with its own fields, so a re-wording that dropped one
    /// would show up as a changed variant or a lost field.
    final variants = <(String, NotificationEntity)>[
      (
        'taskSuggestion',
        NotificationEntity.taskSuggestion(
          meta: meta,
          linkedTaskId: 'task-1',
          suggestionCount: 3,
          title: 'old',
          body: 'old body',
        ),
      ),
      (
        'taskOverdue',
        NotificationEntity.taskOverdue(
          meta: meta,
          linkedTaskId: 'task-1',
          title: 'old',
          body: 'old body',
        ),
      ),
      (
        'relationshipCheckIn',
        NotificationEntity.relationshipCheckIn(
          meta: meta,
          linkedRelationshipId: 'rel-1',
          title: 'old',
          body: 'old body',
        ),
      ),
      (
        'habitAutoCompleted',
        NotificationEntity.habitAutoCompleted(
          meta: meta,
          linkedHabitIds: const ['h-1', 'h-2'],
          dayKey: '2026-09-16',
          title: 'old',
          body: 'old body',
        ),
      ),
      (
        'goalOffTrack',
        NotificationEntity.goalOffTrack(
          meta: meta,
          linkedGoalAgentId: 'agent-1',
          title: 'old',
          body: 'old body',
        ),
      ),
      (
        'dayPlanOutcome',
        NotificationEntity.dayPlanOutcome(
          meta: meta,
          dayId: 'day-1',
          succeeded: false,
          title: 'old',
          body: 'old body',
        ),
      ),
      (
        'syncConflict',
        NotificationEntity.syncConflict(
          meta: meta,
          conflictCount: 4,
          title: 'old',
          body: 'old body',
        ),
      ),
    ];

    for (final (name, entity) in variants) {
      test('$name keeps everything but its words', () {
        final reworded = entity.copyWithCopy(title: 'new', body: 'new body');

        expect(reworded.title, 'new');
        expect(reworded.body, 'new body');
        expect(reworded.runtimeType, entity.runtimeType);
        expect(reworded.meta, meta);
        // Same row, same fields, different words: the JSON differs in the
        // two copy keys and nowhere else.
        final before = entity.toJson()
          ..remove('title')
          ..remove('body');
        final after = reworded.toJson()
          ..remove('title')
          ..remove('body');
        expect(after, before);
      });
    }
  });
}

class _GeneratedEntity {
  const _GeneratedEntity({
    required this.variantSlot,
    required this.idSlot,
    required this.suggestionCountSlot,
    required this.seenSlot,
    required this.actedSlot,
    required this.deletedSlot,
    required this.categorySlot,
  });

  final int variantSlot;
  final int idSlot;
  final int suggestionCountSlot;
  final int seenSlot;
  final int actedSlot;
  final int deletedSlot;
  final int categorySlot;

  NotificationEntity get entity {
    final created = DateTime.utc(2026, 5, 17, 8);
    final updated = DateTime.utc(2026, 5, 17, 9);
    final scheduled = DateTime.utc(2026, 5, 17, 12);
    final meta = NotificationMeta(
      id: 'gen-$idSlot',
      createdAt: created,
      updatedAt: updated,
      scheduledFor: scheduled,
      seenAt: _optional(seenSlot, 10),
      actedOnAt: _optional(actedSlot, 11),
      deletedAt: _optional(deletedSlot, 13),
      vectorClock: VectorClock({
        'host': idSlot + 1,
        'shared': suggestionCountSlot,
      }),
      originatingHostId: 'host-$idSlot',
      category: _category(categorySlot),
    );

    // Modulo the number of variants, so the generator reaches every one of
    // them — the round trip is only a property of the union if it does.
    return switch (variantSlot % 7) {
      0 => NotificationEntity.taskSuggestion(
        meta: meta,
        linkedTaskId: 'task-$idSlot',
        suggestionCount: suggestionCountSlot + 1,
        title: 'Title $idSlot',
        body: 'Body $idSlot',
      ),
      1 => NotificationEntity.taskOverdue(
        meta: meta,
        linkedTaskId: 'task-$idSlot',
        title: 'Title $idSlot',
        body: 'Body $idSlot',
      ),
      2 => NotificationEntity.relationshipCheckIn(
        meta: meta,
        linkedRelationshipId: 'rel-$idSlot',
        title: 'Title $idSlot',
        body: 'Body $idSlot',
      ),
      3 => NotificationEntity.goalOffTrack(
        meta: meta,
        linkedGoalAgentId: 'goal-$idSlot',
        title: 'Title $idSlot',
        body: 'Body $idSlot',
      ),
      4 => NotificationEntity.dayPlanOutcome(
        meta: meta,
        dayId: 'dayplan-2026-05-${10 + idSlot}',
        succeeded: suggestionCountSlot.isEven,
        title: 'Title $idSlot',
        body: 'Body $idSlot',
      ),
      5 => NotificationEntity.syncConflict(
        meta: meta,
        conflictCount: suggestionCountSlot + 1,
        title: 'Title $idSlot',
        body: 'Body $idSlot',
      ),
      _ => NotificationEntity.habitAutoCompleted(
        meta: meta,
        linkedHabitIds: [
          for (var i = 0; i <= suggestionCountSlot % 3; i++) 'habit-$i',
        ],
        dayKey: '2026-05-${10 + idSlot}',
        title: 'Title $idSlot',
        body: 'Body $idSlot',
      ),
    };
  }
}

extension _AnyNotificationEntity on glados.Any {
  glados.Generator<int> get _slot => glados.IntAnys(this).intInRange(0, 9);

  glados.Generator<_GeneratedEntity> get notificationEntity =>
      glados.CombinableAny(this).combine7(
        _slot,
        _slot,
        _slot,
        _slot,
        _slot,
        _slot,
        _slot,
        (
          int variantSlot,
          int idSlot,
          int suggestionCountSlot,
          int seenSlot,
          int actedSlot,
          int deletedSlot,
          int categorySlot,
        ) => _GeneratedEntity(
          variantSlot: variantSlot,
          idSlot: idSlot,
          suggestionCountSlot: suggestionCountSlot,
          seenSlot: seenSlot,
          actedSlot: actedSlot,
          deletedSlot: deletedSlot,
          categorySlot: categorySlot,
        ),
      );
}

DateTime? _optional(int slot, int hour) {
  if (slot == 0) return null;
  return DateTime.utc(2026, 5, 17, hour, slot);
}

String? _category(int slot) {
  if (slot == 0) return null;
  return 'cat-$slot';
}

NotificationEntity _suggestion({
  required String id,
  required String linkedTaskId,
  required String title,
  required String body,
}) {
  final timestamp = DateTime.utc(2026, 5, 17, 8);
  return NotificationEntity.taskSuggestion(
    meta: NotificationMeta(
      id: id,
      createdAt: timestamp,
      updatedAt: timestamp,
      scheduledFor: timestamp,
      vectorClock: const VectorClock({'host-a': 1}),
      originatingHostId: 'host-a',
    ),
    linkedTaskId: linkedTaskId,
    suggestionCount: 2,
    title: title,
    body: body,
  );
}

NotificationEntity _overdue({
  required String id,
  required String linkedTaskId,
  required String title,
  required String body,
}) {
  final timestamp = DateTime.utc(2026, 5, 17, 8);
  return NotificationEntity.taskOverdue(
    meta: NotificationMeta(
      id: id,
      createdAt: timestamp,
      updatedAt: timestamp,
      scheduledFor: timestamp,
      vectorClock: const VectorClock({'host-a': 1}),
      originatingHostId: 'host-a',
    ),
    linkedTaskId: linkedTaskId,
    title: title,
    body: body,
  );
}

NotificationEntity _checkIn({
  required String id,
  required String linkedRelationshipId,
  required String title,
  required String body,
}) {
  final timestamp = DateTime.utc(2026, 5, 17, 8);
  return NotificationEntity.relationshipCheckIn(
    meta: NotificationMeta(
      id: id,
      createdAt: timestamp,
      updatedAt: timestamp,
      scheduledFor: timestamp,
      vectorClock: const VectorClock({'host-a': 1}),
      originatingHostId: 'host-a',
    ),
    linkedRelationshipId: linkedRelationshipId,
    title: title,
    body: body,
  );
}

NotificationEntity _dayPlanOutcome({
  required String id,
  required String dayId,
  bool succeeded = true,
}) {
  final timestamp = DateTime.utc(2026, 5, 17, 8);
  return NotificationEntity.dayPlanOutcome(
    meta: NotificationMeta(
      id: id,
      createdAt: timestamp,
      updatedAt: timestamp,
      scheduledFor: timestamp,
      vectorClock: const VectorClock({'host-a': 1}),
      originatingHostId: 'host-a',
    ),
    dayId: dayId,
    succeeded: succeeded,
    title: 'Title',
    body: 'Body',
  );
}

NotificationEntity _syncConflict({
  required String id,
  required int conflictCount,
}) {
  final timestamp = DateTime.utc(2026, 5, 17, 8);
  return NotificationEntity.syncConflict(
    meta: NotificationMeta(
      id: id,
      createdAt: timestamp,
      updatedAt: timestamp,
      scheduledFor: timestamp,
      vectorClock: const VectorClock({'host-a': 1}),
      originatingHostId: 'host-a',
    ),
    conflictCount: conflictCount,
    title: 'Title',
    body: 'Body',
  );
}

NotificationEntity _goalOffTrack({
  required String id,
  required String linkedGoalAgentId,
  required String title,
  required String body,
}) {
  final timestamp = DateTime.utc(2026, 5, 17, 8);
  return NotificationEntity.goalOffTrack(
    meta: NotificationMeta(
      id: id,
      createdAt: timestamp,
      updatedAt: timestamp,
      scheduledFor: timestamp,
      vectorClock: const VectorClock({'host-a': 1}),
      originatingHostId: 'host-a',
    ),
    linkedGoalAgentId: linkedGoalAgentId,
    title: title,
    body: body,
  );
}

NotificationEntity _habitAuto({
  required String id,
  required List<String> linkedHabitIds,
}) {
  final timestamp = DateTime.utc(2026, 5, 17, 8);
  return NotificationEntity.habitAutoCompleted(
    meta: NotificationMeta(
      id: id,
      createdAt: timestamp,
      updatedAt: timestamp,
      scheduledFor: timestamp,
      vectorClock: const VectorClock({'host-a': 1}),
      originatingHostId: 'host-a',
    ),
    linkedHabitIds: linkedHabitIds,
    dayKey: '2026-05-17',
    title: 'Title',
    body: 'Body',
  );
}
