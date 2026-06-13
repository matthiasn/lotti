import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/repository/linked_task_context_builder.dart';
import 'package:lotti/features/daily_os/util/time_range_utils.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/features/tasks/model/task_progress_state.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

Task _task({
  required String id,
  String title = 'Task',
  DateTime? updatedAt,
  DateTime? dateFrom,
  DateTime? createdAt,
  List<String>? labelIds,
  Duration? estimate,
}) {
  final base = DateTime(2026, 2, 10);
  return Task(
    meta: Metadata(
      id: id,
      createdAt: createdAt ?? base,
      updatedAt: updatedAt ?? base,
      dateFrom: dateFrom ?? base,
      dateTo: base,
      labelIds: labelIds,
    ),
    data: TaskData(
      title: title,
      status: TaskStatus.open(
        id: 'status-$id',
        createdAt: base,
        utcOffset: 0,
      ),
      statusHistory: const [],
      dateFrom: base,
      dateTo: base,
      estimate: estimate,
    ),
  );
}

JournalEntity _timedEntry(
  String id, {
  required Duration duration,
  int startHour = 9,
}) {
  final start = DateTime(2026, 2, 10, startHour);
  return JournalEntity.journalEntry(
    meta: Metadata(
      id: id,
      createdAt: start,
      updatedAt: start,
      dateFrom: start,
      dateTo: start.add(duration),
    ),
  );
}

void main() {
  late MockJournalDb db;
  late MockTaskSummaryResolver resolver;
  late MockEntitiesCacheService cache;
  late LinkedTaskContextBuilder builder;

  setUp(() {
    db = MockJournalDb();
    resolver = MockTaskSummaryResolver();
    cache = MockEntitiesCacheService();
    builder = LinkedTaskContextBuilder(
      db: db,
      taskSummaryResolver: resolver,
      entitiesCache: cache,
    );
  });

  group('buildBatched', () {
    test('returns an empty list without touching the database', () async {
      expect(await builder.buildBatched([]), isEmpty);
      verifyNever(() => db.getBulkLinkedEntities(any()));
    });

    test('builds one context per task from a single bulk query and the '
        'summary resolver', () async {
      final taskA = _task(
        id: 'task-a',
        title: 'Task A',
        labelIds: ['label-1'],
        estimate: const Duration(hours: 2),
      );
      final taskB = _task(id: 'task-b', title: 'Task B');
      final linked = {
        'task-a': [_timedEntry('e1', duration: const Duration(minutes: 90))],
      };
      when(
        () => db.getBulkLinkedEntities({'task-a', 'task-b'}),
      ).thenAnswer((_) async => linked);
      when(
        () => resolver.resolveMany(
          {'task-a', 'task-b'},
          linkedEntitiesByTaskId: linked,
        ),
      ).thenAnswer((_) async => {'task-a': 'Summary for A'});
      when(() => cache.getLabelById('label-1')).thenReturn(
        LabelDefinition(
          id: 'label-1',
          name: 'Deep Work',
          color: '#FF0000',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          vectorClock: const VectorClock(<String, int>{}),
        ),
      );

      final contexts = await builder.buildBatched([taskA, taskB]);

      expect(contexts, hasLength(2));
      final a = contexts.first;
      expect(a.id, 'task-a');
      expect(a.title, 'Task A');
      expect(a.status, 'OPEN');
      expect(a.estimate, '02:00');
      expect(a.timeSpent, '01:30');
      expect(a.labels, [
        {'id': 'label-1', 'name': 'Deep Work'},
      ]);
      expect(a.latestSummary, 'Summary for A');

      final b = contexts.last;
      expect(b.timeSpent, '00:00');
      expect(b.labels, isEmpty);
      expect(b.latestSummary, isNull);

      // The batching contract: exactly one bulk query, no per-task queries.
      verify(() => db.getBulkLinkedEntities(any())).called(1);
    });
  });

  group('labelTuplesFromCache', () {
    test('falls back to the raw id for unknown labels', () {
      when(() => cache.getLabelById('missing')).thenReturn(null);

      expect(builder.labelTuplesFromCache(['missing']), [
        {'id': 'missing', 'name': 'missing'},
      ]);
      expect(builder.labelTuplesFromCache([]), isEmpty);
    });
  });

  group('calculateTimeSpentFromEntities', () {
    test('unions the time ranges of linked entries', () {
      // Non-overlapping entries add up...
      expect(
        calculateTimeSpentFromEntities([
          _timedEntry('e1', duration: const Duration(minutes: 30)),
          _timedEntry(
            'e2',
            duration: const Duration(minutes: 45),
            startHour: 11,
          ),
        ]),
        const Duration(minutes: 75),
      );
      // ...while overlapping ranges are merged, not double-counted.
      expect(
        calculateTimeSpentFromEntities([
          _timedEntry('e1', duration: const Duration(minutes: 30)),
          _timedEntry('e2', duration: const Duration(minutes: 45)),
        ]),
        const Duration(minutes: 45),
      );
    });
  });

  group('calculateTimeSpentWithRepo', () {
    test('feeds the fetched time ranges back into getTaskProgress', () async {
      final repo = MockTaskProgressRepository();
      final ranges = <String, TimeRange>{};
      when(
        () => repo.getTaskProgressData(id: 'task-a'),
      ).thenAnswer((_) async => (const Duration(hours: 1), ranges));
      when(
        () => repo.getTaskProgress(
          timeRanges: ranges,
          estimate: const Duration(hours: 1),
        ),
      ).thenReturn(
        const TaskProgressState(
          progress: Duration(minutes: 20),
          estimate: Duration(hours: 1),
        ),
      );

      final spent = await calculateTimeSpentWithRepo('task-a', repo);

      expect(spent, const Duration(minutes: 20));
    });
  });

  group('compareRelatedProjectTasks', () {
    test('orders by updatedAt desc, then dateFrom, createdAt, and id', () {
      final older = _task(id: 'a', updatedAt: DateTime(2026, 2));
      final newer = _task(id: 'b', updatedAt: DateTime(2026, 2, 5));
      expect(compareRelatedProjectTasks(older, newer), greaterThan(0));
      expect(compareRelatedProjectTasks(newer, older), lessThan(0));

      // Full tie falls back to id descending for stability.
      final t1 = _task(id: 'x');
      final t2 = _task(id: 'y');
      expect(compareRelatedProjectTasks(t1, t2), greaterThan(0));
      expect(compareRelatedProjectTasks(t1, t1), 0);
    });
  });
}
