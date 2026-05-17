import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/features/notifications/model/notification_merge.dart';
import 'package:lotti/features/sync/vector_clock.dart';

void main() {
  group('NotificationMerge', () {
    test('mergeState preserves vector clock when patch clock is null', () {
      final base = _notification(
        id: 'state-null-clock',
      );

      final merged = NotificationMerge.mergeState(
        base,
        seenAt: DateTime.utc(2026, 5, 17, 10),
      );

      expect(merged.meta.vectorClock, const VectorClock({'base': 1}));
      expect(merged.meta.seenAt, DateTime.utc(2026, 5, 17, 10));
    });

    glados.Glados(
      glados.any.notificationStateMergeScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'mergeState keeps earliest state fields and merged clocks',
      (scenario) {
        final firstThenSecond = NotificationMerge.mergeState(
          NotificationMerge.mergeState(
            scenario.base,
            seenAt: scenario.first.seenAt,
            actedOnAt: scenario.first.actedOnAt,
            deletedAt: scenario.first.deletedAt,
            vectorClock: scenario.first.vectorClock,
            originatingHostId: scenario.first.originatingHostId,
          ),
          seenAt: scenario.second.seenAt,
          actedOnAt: scenario.second.actedOnAt,
          deletedAt: scenario.second.deletedAt,
          vectorClock: scenario.second.vectorClock,
          originatingHostId: scenario.second.originatingHostId,
        );
        final secondThenFirst = NotificationMerge.mergeState(
          NotificationMerge.mergeState(
            scenario.base,
            seenAt: scenario.second.seenAt,
            actedOnAt: scenario.second.actedOnAt,
            deletedAt: scenario.second.deletedAt,
            vectorClock: scenario.second.vectorClock,
            originatingHostId: scenario.second.originatingHostId,
          ),
          seenAt: scenario.first.seenAt,
          actedOnAt: scenario.first.actedOnAt,
          deletedAt: scenario.first.deletedAt,
          vectorClock: scenario.first.vectorClock,
          originatingHostId: scenario.first.originatingHostId,
        );
        final firstOnce = NotificationMerge.mergeState(
          scenario.base,
          seenAt: scenario.first.seenAt,
          actedOnAt: scenario.first.actedOnAt,
          deletedAt: scenario.first.deletedAt,
          vectorClock: scenario.first.vectorClock,
          originatingHostId: scenario.first.originatingHostId,
        );
        final firstTwice = NotificationMerge.mergeState(
          firstOnce,
          seenAt: scenario.first.seenAt,
          actedOnAt: scenario.first.actedOnAt,
          deletedAt: scenario.first.deletedAt,
          vectorClock: scenario.first.vectorClock,
          originatingHostId: scenario.first.originatingHostId,
        );

        _expectStateAndClock(
          firstThenSecond,
          scenario.expectedSeenAt,
          scenario.expectedActedOnAt,
          scenario.expectedDeletedAt,
          scenario.expectedStateVectorClock,
          reason: '$scenario',
        );
        _expectStateAndClock(
          secondThenFirst,
          scenario.expectedSeenAt,
          scenario.expectedActedOnAt,
          scenario.expectedDeletedAt,
          scenario.expectedStateVectorClock,
          reason: '$scenario',
        );
        _expectContentMatches(firstThenSecond, scenario.base);
        _expectContentMatches(secondThenFirst, scenario.base);
        expect(
          NotificationMerge.same(firstOnce, firstTwice),
          isTrue,
          reason: '$scenario',
        );
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.notificationFullMergeScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test(
      'mergeFull is deterministic and merges independent state',
      (scenario) {
        final forward = NotificationMerge.mergeFull(
          scenario.existing,
          scenario.incoming,
        );
        final reverse = NotificationMerge.mergeFull(
          scenario.incoming,
          scenario.existing,
        );
        final idempotent = NotificationMerge.mergeFull(
          forward,
          scenario.incoming,
        );

        expect(
          NotificationMerge.same(forward, reverse),
          isTrue,
          reason: '$scenario',
        );
        expect(
          NotificationMerge.same(forward, idempotent),
          isTrue,
          reason: '$scenario',
        );
        _expectStateAndClock(
          forward,
          scenario.expectedSeenAt,
          scenario.expectedActedOnAt,
          scenario.expectedDeletedAt,
          scenario.expectedFullVectorClock,
          reason: '$scenario',
        );

        final expectedWinner = scenario.updatedAtWinner;
        if (expectedWinner != null) {
          _expectContentMatches(forward, expectedWinner);
          expect(
            forward.meta.originatingHostId,
            expectedWinner.meta.originatingHostId,
            reason: '$scenario',
          );
        }
      },
      tags: 'glados',
    );
  });
}

class _StatePatch {
  const _StatePatch({
    required this.seenAt,
    required this.actedOnAt,
    required this.deletedAt,
    required this.vectorClock,
    required this.originatingHostId,
  });

  final DateTime? seenAt;
  final DateTime? actedOnAt;
  final DateTime? deletedAt;
  final VectorClock vectorClock;
  final String originatingHostId;
}

class _GeneratedStateMergeScenario {
  const _GeneratedStateMergeScenario({
    required this.baseSeenSlot,
    required this.baseActedSlot,
    required this.baseDeletedSlot,
    required this.firstSeenSlot,
    required this.firstActedSlot,
    required this.firstDeletedSlot,
    required this.secondSeenSlot,
    required this.secondActedSlot,
    required this.secondDeletedSlot,
  });

  final int baseSeenSlot;
  final int baseActedSlot;
  final int baseDeletedSlot;
  final int firstSeenSlot;
  final int firstActedSlot;
  final int firstDeletedSlot;
  final int secondSeenSlot;
  final int secondActedSlot;
  final int secondDeletedSlot;

  NotificationEntity get base => _notification(
    id: 'state-merge',
    seenAt: _optionalTimestamp(baseSeenSlot),
    actedOnAt: _optionalTimestamp(baseActedSlot),
    deletedAt: _optionalTimestamp(baseDeletedSlot),
    vectorClock: VectorClock({
      'base': baseSeenSlot + 1,
      'shared': baseActedSlot + 1,
    }),
  );

  _StatePatch get first => _StatePatch(
    seenAt: _optionalTimestamp(firstSeenSlot),
    actedOnAt: _optionalTimestamp(firstActedSlot),
    deletedAt: _optionalTimestamp(firstDeletedSlot),
    vectorClock: VectorClock({
      'first': firstSeenSlot + 1,
      'shared': firstActedSlot + 1,
    }),
    originatingHostId: 'first-host',
  );

  _StatePatch get second => _StatePatch(
    seenAt: _optionalTimestamp(secondSeenSlot),
    actedOnAt: _optionalTimestamp(secondActedSlot),
    deletedAt: _optionalTimestamp(secondDeletedSlot),
    vectorClock: VectorClock({
      'second': secondSeenSlot + 1,
      'shared': secondActedSlot + 1,
    }),
    originatingHostId: 'second-host',
  );

  DateTime? get expectedSeenAt => _earliest([
    base.meta.seenAt,
    first.seenAt,
    second.seenAt,
  ]);

  DateTime? get expectedActedOnAt => _earliest([
    base.meta.actedOnAt,
    first.actedOnAt,
    second.actedOnAt,
  ]);

  DateTime? get expectedDeletedAt => _earliest([
    base.meta.deletedAt,
    first.deletedAt,
    second.deletedAt,
  ]);

  VectorClock get expectedStateVectorClock => VectorClock.merge(
    VectorClock.merge(base.meta.vectorClock, first.vectorClock),
    second.vectorClock,
  );

  @override
  String toString() {
    return '_GeneratedStateMergeScenario('
        'baseSeenSlot: $baseSeenSlot, '
        'baseActedSlot: $baseActedSlot, '
        'baseDeletedSlot: $baseDeletedSlot, '
        'firstSeenSlot: $firstSeenSlot, '
        'firstActedSlot: $firstActedSlot, '
        'firstDeletedSlot: $firstDeletedSlot, '
        'secondSeenSlot: $secondSeenSlot, '
        'secondActedSlot: $secondActedSlot, '
        'secondDeletedSlot: $secondDeletedSlot'
        ')';
  }
}

class _GeneratedFullMergeScenario {
  const _GeneratedFullMergeScenario({
    required this.existingUpdatedSlot,
    required this.incomingUpdatedSlot,
    required this.existingSeenSlot,
    required this.incomingSeenSlot,
    required this.existingActedSlot,
    required this.incomingActedSlot,
    required this.existingDeletedSlot,
    required this.incomingDeletedSlot,
    required this.variantMask,
  });

  final int existingUpdatedSlot;
  final int incomingUpdatedSlot;
  final int existingSeenSlot;
  final int incomingSeenSlot;
  final int existingActedSlot;
  final int incomingActedSlot;
  final int existingDeletedSlot;
  final int incomingDeletedSlot;
  final int variantMask;

  NotificationEntity get existing => _notification(
    id: 'full-merge',
    variant: variantMask.isEven
        ? _NotificationVariant.suggestion
        : _NotificationVariant.overdue,
    updatedAt: _timestamp(existingUpdatedSlot + 1),
    scheduledFor: _timestamp(20 + existingUpdatedSlot),
    seenAt: _optionalTimestamp(existingSeenSlot),
    actedOnAt: _optionalTimestamp(existingActedSlot),
    deletedAt: _optionalTimestamp(existingDeletedSlot),
    vectorClock: VectorClock({
      'existing': existingUpdatedSlot + 1,
      'shared': existingActedSlot + 1,
    }),
    originatingHostId: 'existing-host',
    linkedTaskId: 'existing-task',
    title: 'Existing $variantMask',
    body: 'Existing body $existingUpdatedSlot',
    suggestionCount: existingUpdatedSlot + 1,
  );

  NotificationEntity get incoming => _notification(
    id: 'full-merge',
    variant: variantMask % 3 == 0
        ? _NotificationVariant.overdue
        : _NotificationVariant.suggestion,
    updatedAt: _timestamp(incomingUpdatedSlot + 1),
    scheduledFor: _timestamp(40 + incomingUpdatedSlot),
    seenAt: _optionalTimestamp(incomingSeenSlot),
    actedOnAt: _optionalTimestamp(incomingActedSlot),
    deletedAt: _optionalTimestamp(incomingDeletedSlot),
    vectorClock: VectorClock({
      'incoming': incomingUpdatedSlot + 1,
      'shared': incomingActedSlot + 1,
    }),
    originatingHostId: 'incoming-host',
    linkedTaskId: 'incoming-task',
    title: 'Incoming $variantMask',
    body: 'Incoming body $incomingUpdatedSlot',
    suggestionCount: incomingUpdatedSlot + 10,
  );

  NotificationEntity? get updatedAtWinner {
    final comparison = existing.meta.updatedAt.compareTo(
      incoming.meta.updatedAt,
    );
    if (comparison < 0) return incoming;
    if (comparison > 0) return existing;
    return null;
  }

  DateTime? get expectedSeenAt => _earliest([
    existing.meta.seenAt,
    incoming.meta.seenAt,
  ]);

  DateTime? get expectedActedOnAt => _earliest([
    existing.meta.actedOnAt,
    incoming.meta.actedOnAt,
  ]);

  DateTime? get expectedDeletedAt => _earliest([
    existing.meta.deletedAt,
    incoming.meta.deletedAt,
  ]);

  VectorClock get expectedFullVectorClock => VectorClock.merge(
    existing.meta.vectorClock,
    incoming.meta.vectorClock,
  );

  @override
  String toString() {
    return '_GeneratedFullMergeScenario('
        'existingUpdatedSlot: $existingUpdatedSlot, '
        'incomingUpdatedSlot: $incomingUpdatedSlot, '
        'existingSeenSlot: $existingSeenSlot, '
        'incomingSeenSlot: $incomingSeenSlot, '
        'existingActedSlot: $existingActedSlot, '
        'incomingActedSlot: $incomingActedSlot, '
        'existingDeletedSlot: $existingDeletedSlot, '
        'incomingDeletedSlot: $incomingDeletedSlot, '
        'variantMask: $variantMask'
        ')';
  }
}

extension _AnyNotificationMerge on glados.Any {
  glados.Generator<int> get _slot => glados.IntAnys(this).intInRange(0, 9);

  glados.Generator<_GeneratedStateMergeScenario>
  get notificationStateMergeScenario => glados.CombinableAny(this).combine9(
    _slot,
    _slot,
    _slot,
    _slot,
    _slot,
    _slot,
    _slot,
    _slot,
    _slot,
    (
      int baseSeenSlot,
      int baseActedSlot,
      int baseDeletedSlot,
      int firstSeenSlot,
      int firstActedSlot,
      int firstDeletedSlot,
      int secondSeenSlot,
      int secondActedSlot,
      int secondDeletedSlot,
    ) => _GeneratedStateMergeScenario(
      baseSeenSlot: baseSeenSlot,
      baseActedSlot: baseActedSlot,
      baseDeletedSlot: baseDeletedSlot,
      firstSeenSlot: firstSeenSlot,
      firstActedSlot: firstActedSlot,
      firstDeletedSlot: firstDeletedSlot,
      secondSeenSlot: secondSeenSlot,
      secondActedSlot: secondActedSlot,
      secondDeletedSlot: secondDeletedSlot,
    ),
  );

  glados.Generator<_GeneratedFullMergeScenario>
  get notificationFullMergeScenario => glados.CombinableAny(this).combine9(
    _slot,
    _slot,
    _slot,
    _slot,
    _slot,
    _slot,
    _slot,
    _slot,
    _slot,
    (
      int existingUpdatedSlot,
      int incomingUpdatedSlot,
      int existingSeenSlot,
      int incomingSeenSlot,
      int existingActedSlot,
      int incomingActedSlot,
      int existingDeletedSlot,
      int incomingDeletedSlot,
      int variantMask,
    ) => _GeneratedFullMergeScenario(
      existingUpdatedSlot: existingUpdatedSlot,
      incomingUpdatedSlot: incomingUpdatedSlot,
      existingSeenSlot: existingSeenSlot,
      incomingSeenSlot: incomingSeenSlot,
      existingActedSlot: existingActedSlot,
      incomingActedSlot: incomingActedSlot,
      existingDeletedSlot: existingDeletedSlot,
      incomingDeletedSlot: incomingDeletedSlot,
      variantMask: variantMask,
    ),
  );
}

enum _NotificationVariant { suggestion, overdue }

NotificationEntity _notification({
  required String id,
  _NotificationVariant variant = _NotificationVariant.suggestion,
  DateTime? updatedAt,
  DateTime? scheduledFor,
  DateTime? seenAt,
  DateTime? actedOnAt,
  DateTime? deletedAt,
  VectorClock vectorClock = const VectorClock({'base': 1}),
  String originatingHostId = 'base-host',
  String linkedTaskId = 'task-id',
  String title = 'Task reminder',
  String body = 'Review this task',
  int suggestionCount = 1,
}) {
  final createdAt = DateTime.utc(2026, 5, 17, 8);
  final meta = NotificationMeta(
    id: id,
    createdAt: createdAt,
    updatedAt: updatedAt ?? createdAt,
    scheduledFor: scheduledFor ?? DateTime.utc(2026, 5, 17, 12),
    seenAt: seenAt,
    actedOnAt: actedOnAt,
    deletedAt: deletedAt,
    vectorClock: vectorClock,
    originatingHostId: originatingHostId,
  );

  return switch (variant) {
    _NotificationVariant.suggestion => NotificationEntity.taskSuggestion(
      meta: meta,
      linkedTaskId: linkedTaskId,
      suggestionCount: suggestionCount,
      title: title,
      body: body,
    ),
    _NotificationVariant.overdue => NotificationEntity.taskOverdue(
      meta: meta,
      linkedTaskId: linkedTaskId,
      title: title,
      body: body,
    ),
  };
}

DateTime _timestamp(int minute) => DateTime.utc(2026, 5, 17, 9, minute);

DateTime? _optionalTimestamp(int slot) {
  return slot == 0 ? null : _timestamp(slot);
}

DateTime? _earliest(Iterable<DateTime?> values) {
  return values.whereType<DateTime>().fold<DateTime?>(
    null,
    NotificationMerge.earliestNonNull,
  );
}

void _expectStateAndClock(
  NotificationEntity entity,
  DateTime? expectedSeenAt,
  DateTime? expectedActedOnAt,
  DateTime? expectedDeletedAt,
  VectorClock expectedVectorClock, {
  required String reason,
}) {
  expect(entity.meta.seenAt, expectedSeenAt, reason: reason);
  expect(entity.meta.actedOnAt, expectedActedOnAt, reason: reason);
  expect(entity.meta.deletedAt, expectedDeletedAt, reason: reason);
  expect(entity.meta.vectorClock, expectedVectorClock, reason: reason);
}

void _expectContentMatches(
  NotificationEntity actual,
  NotificationEntity expected,
) {
  expect(actual.type, expected.type);
  expect(actual.title, expected.title);
  expect(actual.body, expected.body);
  expect(actual.linkedEntityId, expected.linkedEntityId);
  expect(actual.meta.createdAt, expected.meta.createdAt);
  expect(actual.meta.updatedAt, expected.meta.updatedAt);
  expect(actual.meta.scheduledFor, expected.meta.scheduledFor);

  if (expected is TaskSuggestionNotification) {
    expect(actual, isA<TaskSuggestionNotification>());
    expect(
      (actual as TaskSuggestionNotification).suggestionCount,
      expected.suggestionCount,
    );
  } else {
    expect(actual, isA<TaskOverdueNotification>());
  }

  final actualJson = Map<String, dynamic>.from(actual.toJson())..remove('meta');
  final expectedJson = Map<String, dynamic>.from(expected.toJson())
    ..remove('meta');
  expect(jsonEncode(actualJson), jsonEncode(expectedJson));
}
