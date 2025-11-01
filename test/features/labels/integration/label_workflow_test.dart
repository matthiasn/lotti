// ignore_for_file: avoid_redundant_argument_values

import 'dart:io';

import 'package:async/async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';

JournalEntity buildTask({
  required String id,
  List<String>? labelIds,
}) {
  final now = DateTime(2024, 1, 1);
  return JournalEntity.task(
    meta: Metadata(
      id: id,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
      labelIds: labelIds,
    ),
    data: TaskData(
      status: TaskStatus.open(
        id: 'status-$id',
        createdAt: now,
        utcOffset: now.timeZoneOffset.inMinutes,
      ),
      dateFrom: now,
      dateTo: now,
      statusHistory: const [],
      title: 'Task $id',
    ),
  );
}

Future<void> upsertLabel(JournalDb db, LabelDefinition label) {
  return db.upsertLabelDefinition(label);
}

LabelDefinition buildLabel(String id, String name, String color) {
  final now = DateTime(2024, 1, 1);
  return LabelDefinition(
    id: id,
    name: name,
    color: color,
    createdAt: now,
    updatedAt: now,
    vectorClock: const VectorClock(<String, int>{}),
  );
}

void main() {
  late JournalDb db;
  Directory? previousDirectory;

  // Ensure EntitiesCacheService can subscribe to DB watchers
  // by registering the in-memory JournalDb in getIt for these tests.
  Future<void> registerDbForCache() async {
    if (!getIt.isRegistered<JournalDb>()) {
      getIt.registerSingleton<JournalDb>(db);
    }
  }

  setUp(() {
    if (getIt.isRegistered<Directory>()) {
      previousDirectory = getIt<Directory>();
      getIt.unregister<Directory>();
    } else {
      previousDirectory = null;
    }
    getIt.registerSingleton<Directory>(Directory.systemTemp);
    db = JournalDb(inMemoryDatabase: true);
    // Some tests instantiate EntitiesCacheService; make DB available.
    if (getIt.isRegistered<JournalDb>()) {
      getIt.unregister<JournalDb>();
    }
    getIt.registerSingleton<JournalDb>(db);
  });

  tearDown(() async {
    await db.close();
    getIt.unregister<Directory>();
    if (previousDirectory != null) {
      getIt.registerSingleton<Directory>(previousDirectory!);
    }
  });

  test('full workflow: create label, assign, filter, remove', () async {
    final focusLabel = buildLabel('label-focus', 'Focus', '#FF0000');
    final bugLabel = buildLabel('label-bug', 'Bug', '#00FF00');

    await upsertLabel(db, focusLabel);
    await upsertLabel(db, bugLabel);

    final focusedTask =
        buildTask(id: 'task-focused', labelIds: ['label-focus']);
    final unlabeledTask = buildTask(id: 'task-unlabeled');

    expect(
      (await db.updateJournalEntity(focusedTask)).applied,
      isTrue,
    );
    expect(
      (await db.updateJournalEntity(unlabeledTask)).applied,
      isTrue,
    );

    final filteredByFocus = await db.getTasks(
      starredStatuses: const [true, false],
      taskStatuses: const ['OPEN', 'IN PROGRESS', 'DONE', 'GROOMED'],
      categoryIds: const [''],
      labelIds: const ['label-focus'],
    );

    expect(filteredByFocus.length, 1);
    expect(filteredByFocus.first.meta.id, 'task-focused');

    final filteredUnlabeled = await db.getTasks(
      starredStatuses: const [true, false],
      taskStatuses: const ['OPEN', 'IN PROGRESS', 'DONE', 'GROOMED'],
      categoryIds: const [''],
      labelIds: const [''],
    );

    expect(filteredUnlabeled.length, 1);
    expect(filteredUnlabeled.first.meta.id, 'task-unlabeled');

    final cleared = focusedTask.copyWith(
      meta: focusedTask.meta.copyWith(
        labelIds: null,
        updatedAt: DateTime(2024, 1, 2),
      ),
    );
    expect(
      (await db.updateJournalEntity(cleared)).applied,
      isTrue,
    );

    final labeledRows = await db.labeledForJournal(focusedTask.meta.id).get();
    expect(labeledRows, isEmpty);
  });

  test('diff-based reconciliation resolves conflicting label assignments',
      () async {
    final focusLabel = buildLabel('label-focus', 'Focus', '#FF0000');
    final bugLabel = buildLabel('label-bug', 'Bug', '#00FF00');

    await upsertLabel(db, focusLabel);
    await upsertLabel(db, bugLabel);

    final task = buildTask(id: 'task-sync', labelIds: ['label-focus']);
    expect((await db.updateJournalEntity(task)).applied, isTrue);

    final remoteUpdate = task.copyWith(
      meta: task.meta.copyWith(
        labelIds: ['label-focus', 'label-bug'],
        updatedAt: DateTime(2024, 1, 2),
      ),
    );
    expect((await db.updateJournalEntity(remoteUpdate)).applied, isTrue);

    final localUpdate = task.copyWith(
      meta: task.meta.copyWith(
        labelIds: ['label-bug'],
        updatedAt: DateTime(2024, 1, 3),
      ),
    );
    expect((await db.updateJournalEntity(localUpdate)).applied, isTrue);

    final labeledRows = await db.labeledForJournal(task.meta.id).get();
    expect(labeledRows, equals(['label-bug']));

    final filtered = await db.getTasks(
      starredStatuses: const [true, false],
      taskStatuses: const ['OPEN', 'IN PROGRESS', 'DONE', 'GROOMED'],
      categoryIds: const [''],
      labelIds: const ['label-bug'],
    );
    expect(filtered.map((task) => task.meta.id), contains('task-sync'));
  });

  test('soft-deleted labels disappear from watch streams', () async {
    final focusLabel = buildLabel('label-focus', 'Focus', '#FF0000');
    await upsertLabel(db, focusLabel);

    final queue = StreamQueue(db.watchLabelDefinitions());
    final first = await queue.next;
    expect(first.any((label) => label.id == focusLabel.id), isTrue);

    final deleted = focusLabel.copyWith(
      deletedAt: DateTime(2024, 1, 2),
      updatedAt: DateTime(2024, 1, 2),
    );
    await upsertLabel(db, deleted);

    final second = await queue.next;
    expect(second.any((label) => label.id == focusLabel.id), isFalse);
    await queue.cancel();
  });

  test('label rename propagates via watchLabelDefinitionById stream', () async {
    final focusLabel = buildLabel('label-focus', 'Focus', '#FF0000');
    await upsertLabel(db, focusLabel);

    final queue = StreamQueue(db.watchLabelDefinitionById(focusLabel.id));
    final first = await queue.next;
    expect(first?.name, 'Focus');

    final renamed = focusLabel.copyWith(
      name: 'Laser focus',
      updatedAt: DateTime(2024, 1, 2),
    );
    await upsertLabel(db, renamed);

    final second = await queue.next;
    expect(second?.name, 'Laser focus');
    await queue.cancel();
  });

  test('private flag updates emit new values mid-session', () async {
    final privateLabel = buildLabel('label-private', 'Stealth', '#222222')
        .copyWith(private: false);
    await upsertLabel(db, privateLabel);

    final queue = StreamQueue(db.watchLabelDefinitionById(privateLabel.id));
    await queue.next; // initial snapshot

    final updated = privateLabel.copyWith(
      private: true,
      updatedAt: DateTime(2024, 1, 2),
    );
    await upsertLabel(db, updated);

    final next = await queue.next;
    expect(next?.private, isTrue);
    await queue.cancel();
  });

  group('category-scoped workflows (integration)', () {
    LabelDefinition scoped(String id, String name, List<String> cats) {
      final now = DateTime(2024, 1, 1);
      return LabelDefinition(
        id: id,
        name: name,
        color: '#222222',
        createdAt: now,
        updatedAt: now,
        vectorClock: const VectorClock(<String, int>{}),
        applicableCategoryIds: cats,
      );
    }

    LabelDefinition global(String id, String name) {
      final now = DateTime(2024, 1, 1);
      return LabelDefinition(
        id: id,
        name: name,
        color: '#111111',
        createdAt: now,
        updatedAt: now,
        vectorClock: const VectorClock(<String, int>{}),
      );
    }

    Future<void> upsertCategory(String id, String name, String color) async {
      final now = DateTime(2024, 1, 1);
      final cat = CategoryDefinition(
        id: id,
        name: name,
        color: color,
        createdAt: now,
        updatedAt: now,
        vectorClock: const VectorClock(<String, int>{}),
        private: false,
        active: true,
      );
      await db.upsertCategoryDefinition(cat);
    }

    test('create scoped label → visible only in matching category', () async {
      await registerDbForCache();
      final cache = EntitiesCacheService();

      await upsertCategory('work', 'Work', '#0000FF');
      await upsertCategory('personal', 'Personal', '#00FF00');
      await upsertLabel(db, scoped('l-work', 'WorkOnly', const ['work']));

      // Let watchers deliver
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final forWork = cache.availableLabelsForCategory('work');
      final forPersonal = cache.availableLabelsForCategory('personal');
      final forNull = cache.availableLabelsForCategory(null);

      expect(forWork.map((l) => l.id), contains('l-work'));
      expect(forPersonal.map((l) => l.id), isNot(contains('l-work')));
      expect(forNull.map((l) => l.id), isNot(contains('l-work')));
    });

    test('global label appears in all categories and unscoped context',
        () async {
      await registerDbForCache();
      final cache = EntitiesCacheService();

      await upsertCategory('work', 'Work', '#0000FF');
      await upsertCategory('home', 'Home', '#00FF00');
      await upsertLabel(db, global('l-global', 'Global'));

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(cache.availableLabelsForCategory('work').map((l) => l.id),
          contains('l-global'));
      expect(cache.availableLabelsForCategory('home').map((l) => l.id),
          contains('l-global'));
      expect(cache.availableLabelsForCategory(null).map((l) => l.id),
          contains('l-global'));
    });

    test('label scoped to multiple categories appears in each', () async {
      await registerDbForCache();
      final cache = EntitiesCacheService();

      await upsertCategory('work', 'Work', '#0000FF');
      await upsertCategory('personal', 'Personal', '#00FF00');
      await upsertCategory('health', 'Health', '#FF00FF');
      await upsertLabel(
        db,
        scoped('l-multi', 'Multi', const ['work', 'personal']),
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(cache.availableLabelsForCategory('work').map((l) => l.id),
          contains('l-multi'));
      expect(cache.availableLabelsForCategory('personal').map((l) => l.id),
          contains('l-multi'));
      expect(cache.availableLabelsForCategory('health').map((l) => l.id),
          isNot(contains('l-multi')));
    });
  });
}
