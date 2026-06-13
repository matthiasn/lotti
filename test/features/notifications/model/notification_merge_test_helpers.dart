import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/features/notifications/model/notification_merge.dart';
import 'package:lotti/features/sync/vector_clock.dart';

class StatePatch {
  const StatePatch({
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

class GeneratedStateMergeScenario {
  const GeneratedStateMergeScenario({
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

  NotificationEntity get base => buildNotification(
    id: 'state-merge',
    seenAt: buildOptionalTimestamp(baseSeenSlot),
    actedOnAt: buildOptionalTimestamp(baseActedSlot),
    deletedAt: buildOptionalTimestamp(baseDeletedSlot),
    vectorClock: VectorClock({
      'base': baseSeenSlot + 1,
      'shared': baseActedSlot + 1,
    }),
  );

  StatePatch get first => StatePatch(
    seenAt: buildOptionalTimestamp(firstSeenSlot),
    actedOnAt: buildOptionalTimestamp(firstActedSlot),
    deletedAt: buildOptionalTimestamp(firstDeletedSlot),
    vectorClock: VectorClock({
      'first': firstSeenSlot + 1,
      'shared': firstActedSlot + 1,
    }),
    originatingHostId: 'first-host',
  );

  StatePatch get second => StatePatch(
    seenAt: buildOptionalTimestamp(secondSeenSlot),
    actedOnAt: buildOptionalTimestamp(secondActedSlot),
    deletedAt: buildOptionalTimestamp(secondDeletedSlot),
    vectorClock: VectorClock({
      'second': secondSeenSlot + 1,
      'shared': secondActedSlot + 1,
    }),
    originatingHostId: 'second-host',
  );

  DateTime? get expectedSeenAt => earliestTimestamp([
    base.meta.seenAt,
    first.seenAt,
    second.seenAt,
  ]);

  DateTime? get expectedActedOnAt => earliestTimestamp([
    base.meta.actedOnAt,
    first.actedOnAt,
    second.actedOnAt,
  ]);

  DateTime? get expectedDeletedAt => earliestTimestamp([
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
    return 'GeneratedStateMergeScenario('
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

class GeneratedFullMergeScenario {
  const GeneratedFullMergeScenario({
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

  NotificationEntity get existing => buildNotification(
    id: 'full-merge',
    variant: variantMask.isEven
        ? NotificationVariant.suggestion
        : NotificationVariant.overdue,
    updatedAt: buildTimestamp(existingUpdatedSlot + 1),
    scheduledFor: buildTimestamp(20 + existingUpdatedSlot),
    seenAt: buildOptionalTimestamp(existingSeenSlot),
    actedOnAt: buildOptionalTimestamp(existingActedSlot),
    deletedAt: buildOptionalTimestamp(existingDeletedSlot),
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

  NotificationEntity get incoming => buildNotification(
    id: 'full-merge',
    variant: variantMask % 3 == 0
        ? NotificationVariant.overdue
        : NotificationVariant.suggestion,
    updatedAt: buildTimestamp(incomingUpdatedSlot + 1),
    scheduledFor: buildTimestamp(40 + incomingUpdatedSlot),
    seenAt: buildOptionalTimestamp(incomingSeenSlot),
    actedOnAt: buildOptionalTimestamp(incomingActedSlot),
    deletedAt: buildOptionalTimestamp(incomingDeletedSlot),
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

  DateTime? get expectedSeenAt => earliestTimestamp([
    existing.meta.seenAt,
    incoming.meta.seenAt,
  ]);

  DateTime? get expectedActedOnAt => earliestTimestamp([
    existing.meta.actedOnAt,
    incoming.meta.actedOnAt,
  ]);

  DateTime? get expectedDeletedAt => earliestTimestamp([
    existing.meta.deletedAt,
    incoming.meta.deletedAt,
  ]);

  VectorClock get expectedFullVectorClock => VectorClock.merge(
    existing.meta.vectorClock,
    incoming.meta.vectorClock,
  );

  @override
  String toString() {
    return 'GeneratedFullMergeScenario('
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

extension AnyNotificationMerge on glados.Any {
  glados.Generator<int> get _slot => glados.IntAnys(this).intInRange(0, 9);

  glados.Generator<GeneratedStateMergeScenario>
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
    ) => GeneratedStateMergeScenario(
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

  glados.Generator<GeneratedFullMergeScenario>
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
    ) => GeneratedFullMergeScenario(
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

enum NotificationVariant { suggestion, overdue }

NotificationEntity buildNotification({
  required String id,
  NotificationVariant variant = NotificationVariant.suggestion,
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
    NotificationVariant.suggestion => NotificationEntity.taskSuggestion(
      meta: meta,
      linkedTaskId: linkedTaskId,
      suggestionCount: suggestionCount,
      title: title,
      body: body,
    ),
    NotificationVariant.overdue => NotificationEntity.taskOverdue(
      meta: meta,
      linkedTaskId: linkedTaskId,
      title: title,
      body: body,
    ),
  };
}

DateTime buildTimestamp(int minute) => DateTime.utc(2026, 5, 17, 9, minute);

DateTime? buildOptionalTimestamp(int slot) {
  return slot == 0 ? null : buildTimestamp(slot);
}

DateTime? earliestTimestamp(Iterable<DateTime?> values) {
  return values.whereType<DateTime>().fold<DateTime?>(
    null,
    NotificationMerge.earliestNonNull,
  );
}

void expectStateAndClock(
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

void expectContentMatches(
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
