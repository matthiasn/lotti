// ignore_for_file: avoid_redundant_argument_values

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';

void main() {
  late JournalDb db;
  Directory? previousDirectory;

  setUp(() {
    if (getIt.isRegistered<Directory>()) {
      previousDirectory = getIt<Directory>();
      getIt.unregister<Directory>();
    } else {
      previousDirectory = null;
    }
    getIt.registerSingleton<Directory>(Directory.systemTemp);
    db = JournalDb(inMemoryDatabase: true);
  });

  tearDown(() async {
    await db.close();
    getIt.unregister<Directory>();
    if (previousDirectory != null) {
      getIt.registerSingleton<Directory>(previousDirectory!);
    }
  });

  LabelDefinition buildLabel(int index) {
    final now = DateTime(2024, 1, 1);
    return LabelDefinition(
      id: 'label-$index',
      name: 'Label $index',
      color: '#${(index * 100000).toRadixString(16).padLeft(6, '0')}',
      createdAt: now,
      updatedAt: now,
      vectorClock: const VectorClock(<String, int>{}),
    );
  }

  JournalEntity buildTask(int index, List<String> labelIds) {
    final now = DateTime(2024, 1, 1);
    return JournalEntity.task(
      meta: Metadata(
        id: 'task-$index',
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
        labelIds: labelIds,
      ),
      data: TaskData(
        status: TaskStatus.open(
          id: 'status-$index',
          createdAt: now,
          utcOffset: now.timeZoneOffset.inMinutes,
        ),
        dateFrom: now,
        dateTo: now,
        statusHistory: const [],
        title: 'Task $index',
      ),
    );
  }

  test('filtering 1000+ tasks with 50+ labels completes under 100ms', () async {
    // Create 50 labels
    for (var i = 0; i < 50; i++) {
      await db.upsertLabelDefinition(buildLabel(i));
    }

    // Create 1000 tasks with random label assignments
    for (var i = 0; i < 1000; i++) {
      final labelIds = <String>[];
      // Assign 0-3 random labels to each task
      final labelCount = i % 4;
      for (var j = 0; j < labelCount; j++) {
        labelIds.add('label-${(i + j) % 50}');
      }
      final task = buildTask(i, labelIds);
      await db.updateJournalEntity(task);
    }

    // Benchmark filtering by a single label
    final stopwatch = Stopwatch()..start();
    final filtered = await db.getTasks(
      starredStatuses: const [true, false],
      taskStatuses: const ['OPEN', 'IN PROGRESS', 'DONE', 'GROOMED'],
      categoryIds: const [''],
      labelIds: const ['label-0'],
    );
    stopwatch.stop();

    // Verify results
    expect(filtered.isNotEmpty, isTrue);
    expect(stopwatch.elapsedMilliseconds, lessThan(100),
        reason: 'Filtering should complete under 100ms');
  });

  test('reconciliation on 1000 tasks completes under 2000ms', () async {
    // Create a label
    await db.upsertLabelDefinition(buildLabel(0));

    // Create 1000 tasks without labels
    for (var i = 0; i < 1000; i++) {
      final task = buildTask(i, []);
      await db.updateJournalEntity(task);
    }

    // Benchmark bulk reconciliation: assign label-0 to all tasks
    final stopwatch = Stopwatch()..start();
    for (var i = 0; i < 1000; i++) {
      final task = buildTask(i, ['label-0']);
      await db.updateJournalEntity(task);
    }
    stopwatch.stop();

    expect(stopwatch.elapsedMilliseconds, lessThan(2000),
        reason: 'Reconciliation should complete under 2000ms for 1000 tasks');

    // Verify labeled table populated
    final labeled = await db.labeledForJournal('task-0').get();
    expect(labeled, hasLength(1));
  });

  test('no N+1 queries when filtering by multiple labels', () async {
    // Create 10 labels
    for (var i = 0; i < 10; i++) {
      await db.upsertLabelDefinition(buildLabel(i));
    }

    // Create 100 tasks with various label combinations
    for (var i = 0; i < 100; i++) {
      final labelIds = <String>[
        'label-${i % 10}',
        'label-${(i + 1) % 10}',
      ];
      final task = buildTask(i, labelIds);
      await db.updateJournalEntity(task);
    }

    // Filter by multiple labels (OR logic)
    final stopwatch = Stopwatch()..start();
    final filtered = await db.getTasks(
      starredStatuses: const [true, false],
      taskStatuses: const ['OPEN', 'IN PROGRESS', 'DONE', 'GROOMED'],
      categoryIds: const [''],
      labelIds: const ['label-0', 'label-1', 'label-2'],
    );
    stopwatch.stop();

    expect(filtered.isNotEmpty, isTrue);
    expect(stopwatch.elapsedMilliseconds, lessThan(50),
        reason: 'Multi-label filtering should use efficient joins');
  });

  test('reconciliation handles mixed add/remove operations efficiently',
      () async {
    // Create 5 labels
    for (var i = 0; i < 5; i++) {
      await db.upsertLabelDefinition(buildLabel(i));
    }

    // Create task with 3 labels
    final task = buildTask(0, ['label-0', 'label-1', 'label-2']);
    await db.updateJournalEntity(task);

    // Benchmark: swap labels (remove 2, keep 1, add 2 new)
    final stopwatch = Stopwatch()..start();
    final updated = buildTask(0, ['label-1', 'label-3', 'label-4']);
    await db.updateJournalEntity(updated);
    stopwatch.stop();

    expect(stopwatch.elapsedMilliseconds, lessThan(10),
        reason: 'Diff-based reconciliation should be fast');

    // Verify correct labels in denormalized table
    final labelIds = await db.labeledForJournal('task-0').get();
    expect(labelIds, hasLength(3));
    expect(labelIds, containsAll(['label-1', 'label-3', 'label-4']));
    expect(labelIds, isNot(contains('label-0')));
    expect(labelIds, isNot(contains('label-2')));
  });
}
