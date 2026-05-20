import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/features/notifications/model/notification_inbox_projection.dart';
import 'package:lotti/features/sync/vector_clock.dart';

class _GeneratedInboxSpec {
  const _GeneratedInboxSpec({
    required this.taskSlot,
    required this.createdSlot,
    required this.updatedSlot,
    required this.scheduledSlot,
  });

  final int taskSlot;
  final int createdSlot;
  final int updatedSlot;
  final int scheduledSlot;

  String get taskId => 'task-${taskSlot % 4}';

  @override
  String toString() {
    return '_GeneratedInboxSpec('
        'taskSlot: $taskSlot, '
        'createdSlot: $createdSlot, '
        'updatedSlot: $updatedSlot, '
        'scheduledSlot: $scheduledSlot)';
  }
}

class _GeneratedInboxScenario {
  const _GeneratedInboxScenario({required this.specs});

  final List<_GeneratedInboxSpec> specs;

  @override
  String toString() => '_GeneratedInboxScenario(specs: $specs)';
}

class _GeneratedBadgeSpec {
  const _GeneratedBadgeSpec({
    required this.kindSlot,
    required this.taskSlot,
    required this.seenSlot,
    required this.updatedSlot,
  });

  final int kindSlot;
  final int taskSlot;
  final int seenSlot;
  final int updatedSlot;

  bool get isSuggestion => kindSlot.isEven;
  bool get isSeen => seenSlot % 3 == 0;
  String get taskId => 'task-${taskSlot % 5}';

  @override
  String toString() {
    return '_GeneratedBadgeSpec('
        'kindSlot: $kindSlot, '
        'taskSlot: $taskSlot, '
        'seenSlot: $seenSlot, '
        'updatedSlot: $updatedSlot)';
  }
}

class _GeneratedBadgeScenario {
  const _GeneratedBadgeScenario({required this.specs});

  final List<_GeneratedBadgeSpec> specs;

  @override
  String toString() => '_GeneratedBadgeScenario(specs: $specs)';
}

extension _AnyGeneratedInboxScenario on glados.Any {
  glados.Generator<_GeneratedInboxSpec> get inboxSpec =>
      glados.CombinableAny(this).combine4(
        glados.IntAnys(this).intInRange(0, 24),
        glados.IntAnys(this).intInRange(0, 24),
        glados.IntAnys(this).intInRange(0, 24),
        glados.IntAnys(this).intInRange(0, 24),
        (
          int taskSlot,
          int createdSlot,
          int updatedSlot,
          int scheduledSlot,
        ) => _GeneratedInboxSpec(
          taskSlot: taskSlot,
          createdSlot: createdSlot,
          updatedSlot: updatedSlot,
          scheduledSlot: scheduledSlot,
        ),
      );

  glados.Generator<_GeneratedInboxScenario> get inboxScenario =>
      glados.ListAnys(
            this,
          )
          .listWithLengthInRange(0, 16, inboxSpec)
          .map(
            (specs) => _GeneratedInboxScenario(specs: specs),
          );

  glados.Generator<_GeneratedBadgeSpec> get badgeSpec =>
      glados.CombinableAny(this).combine4(
        glados.IntAnys(this).intInRange(0, 16),
        glados.IntAnys(this).intInRange(0, 16),
        glados.IntAnys(this).intInRange(0, 16),
        glados.IntAnys(this).intInRange(0, 16),
        (
          int kindSlot,
          int taskSlot,
          int seenSlot,
          int updatedSlot,
        ) => _GeneratedBadgeSpec(
          kindSlot: kindSlot,
          taskSlot: taskSlot,
          seenSlot: seenSlot,
          updatedSlot: updatedSlot,
        ),
      );

  glados.Generator<_GeneratedBadgeScenario> get badgeScenario =>
      glados.ListAnys(
            this,
          )
          .listWithLengthInRange(0, 20, badgeSpec)
          .map(
            (specs) => _GeneratedBadgeScenario(specs: specs),
          );
}

void main() {
  group('deduplicateInboxNotifications', () {
    test('keeps overdue rows distinct while collapsing task suggestions', () {
      final entries = [
        _suggestion(id: 'old', taskId: 'task-1', updatedSlot: 1),
        _suggestion(id: 'new', taskId: 'task-1', updatedSlot: 2),
        _overdue(id: 'overdue-a', taskId: 'task-1'),
        _overdue(id: 'overdue-b', taskId: 'task-1'),
      ];

      final projected = deduplicateInboxNotifications(entries);

      expect(projected.map((e) => e.id), [
        'new',
        'overdue-a',
        'overdue-b',
      ]);
    });

    test('uses stable id tie-breaker for otherwise identical suggestions', () {
      final projected = deduplicateInboxNotifications([
        _suggestion(id: 'suggestion-a', taskId: 'task-1'),
        _suggestion(id: 'suggestion-z', taskId: 'task-1'),
      ]);

      expect(projected.map((e) => e.id), ['suggestion-z']);
    });

    glados.Glados(
      glados.any.badgeScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test('counts only unseen generated user-visible inbox rows', (scenario) {
      final entries = [
        for (final indexed in scenario.specs.indexed)
          _badgeRowFromSpec(indexed.$2, index: indexed.$1),
      ];

      final expectedKeys = <String>{};
      for (final indexed in scenario.specs.indexed) {
        final spec = indexed.$2;
        if (spec.isSeen) continue;
        expectedKeys.add(
          spec.isSuggestion
              ? 'taskSuggestion:${spec.taskId}'
              : 'overdue-${indexed.$1}-${spec.taskSlot}',
        );
      }

      expect(
        countUnseenInboxNotifications(entries),
        expectedKeys.length,
        reason: '$scenario',
      );
    }, tags: 'glados');

    glados.Glados(
      glados.any.inboxScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test('collapses generated task-suggestion rows by task identity', (
      scenario,
    ) {
      final entries = [
        for (final indexed in scenario.specs.indexed)
          _suggestionFromSpec(indexed.$2, index: indexed.$1),
      ];

      final projected = deduplicateInboxNotifications(entries);
      final projectedSuggestions = projected
          .whereType<TaskSuggestionNotification>()
          .toList();

      final taskIds = projectedSuggestions.map((row) => row.linkedTaskId);
      expect(
        taskIds.toSet(),
        hasLength(taskIds.length),
        reason: '$scenario',
      );

      for (final taskId
          in entries
              .whereType<TaskSuggestionNotification>()
              .map((row) => row.linkedTaskId)
              .toSet()) {
        final expected = entries
            .whereType<TaskSuggestionNotification>()
            .where((row) => row.linkedTaskId == taskId)
            .reduce(_preferred);
        final actual = projectedSuggestions.singleWhere(
          (row) => row.linkedTaskId == taskId,
        );
        expect(actual.id, expected.id, reason: '$scenario');
      }

      expect(
        projected.map((row) => row.meta.scheduledFor).toList(),
        orderedEquals(
          [...projected.map((row) => row.meta.scheduledFor)]..sort(),
        ),
        reason: '$scenario',
      );
    }, tags: 'glados');
  });
}

TaskSuggestionNotification _suggestionFromSpec(
  _GeneratedInboxSpec spec, {
  required int index,
}) {
  return _suggestion(
    id: 'suggestion-$index-${spec.taskSlot}',
    taskId: spec.taskId,
    createdSlot: spec.createdSlot,
    updatedSlot: spec.updatedSlot,
    scheduledSlot: spec.scheduledSlot,
  );
}

NotificationEntity _badgeRowFromSpec(
  _GeneratedBadgeSpec spec, {
  required int index,
}) {
  final id = spec.isSuggestion
      ? 'suggestion-$index-${spec.taskSlot}'
      : 'overdue-$index-${spec.taskSlot}';
  final seenAt = spec.isSeen ? DateTime.utc(2026, 5, 17, 12) : null;
  if (spec.isSuggestion) {
    return _suggestion(
      id: id,
      taskId: spec.taskId,
      updatedSlot: spec.updatedSlot,
      seenAt: seenAt,
    );
  }
  return _overdue(
    id: id,
    taskId: spec.taskId,
    updatedSlot: spec.updatedSlot,
    seenAt: seenAt,
  );
}

TaskSuggestionNotification _suggestion({
  required String id,
  required String taskId,
  int createdSlot = 0,
  int updatedSlot = 0,
  int scheduledSlot = 0,
  DateTime? seenAt,
}) {
  final base = DateTime.utc(2026, 5, 17, 10);
  return NotificationEntity.taskSuggestion(
        meta: NotificationMeta(
          id: id,
          createdAt: base.add(Duration(minutes: createdSlot)),
          updatedAt: base.add(Duration(minutes: updatedSlot)),
          scheduledFor: base.add(Duration(minutes: scheduledSlot)),
          seenAt: seenAt,
          vectorClock: const VectorClock({'host': 1}),
          originatingHostId: 'host',
        ),
        linkedTaskId: taskId,
        suggestionCount: 1,
        title: 'Suggestion',
        body: taskId,
      )
      as TaskSuggestionNotification;
}

TaskOverdueNotification _overdue({
  required String id,
  required String taskId,
  int updatedSlot = 0,
  DateTime? seenAt,
}) {
  final base = DateTime.utc(2026, 5, 17, 11);
  return NotificationEntity.taskOverdue(
        meta: NotificationMeta(
          id: id,
          createdAt: base,
          updatedAt: base.add(Duration(minutes: updatedSlot)),
          scheduledFor: base,
          seenAt: seenAt,
          vectorClock: const VectorClock({'host': 1}),
          originatingHostId: 'host',
        ),
        linkedTaskId: taskId,
        title: 'Overdue',
        body: taskId,
      )
      as TaskOverdueNotification;
}

TaskSuggestionNotification _preferred(
  TaskSuggestionNotification a,
  TaskSuggestionNotification b,
) {
  final updated = a.meta.updatedAt.compareTo(b.meta.updatedAt);
  if (updated != 0) return updated > 0 ? a : b;

  final created = a.meta.createdAt.compareTo(b.meta.createdAt);
  if (created != 0) return created > 0 ? a : b;

  final scheduled = a.meta.scheduledFor.compareTo(b.meta.scheduledFor);
  if (scheduled != 0) return scheduled > 0 ? a : b;

  return a.id.compareTo(b.id) > 0 ? a : b;
}
