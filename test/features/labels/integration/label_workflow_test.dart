// ignore_for_file: avoid_redundant_argument_values

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';

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

  test('soft-deleted labels disappear from getAllLabelDefinitions', () async {
    final focusLabel = buildLabel('label-focus', 'Focus', '#FF0000');
    await upsertLabel(db, focusLabel);

    final first = await db.getAllLabelDefinitions();
    expect(first.any((LabelDefinition label) => label.id == focusLabel.id),
        isTrue);

    final deleted = focusLabel.copyWith(
      deletedAt: DateTime(2024, 1, 2),
      updatedAt: DateTime(2024, 1, 2),
    );
    await upsertLabel(db, deleted);

    final second = await db.getAllLabelDefinitions();
    expect(second.any((LabelDefinition label) => label.id == focusLabel.id),
        isFalse);
  });

  test('label rename is reflected in getLabelDefinitionById', () async {
    final focusLabel = buildLabel('label-focus', 'Focus', '#FF0000');
    await upsertLabel(db, focusLabel);

    final first = await db.getLabelDefinitionById(focusLabel.id);
    expect(first?.name, 'Focus');

    final renamed = focusLabel.copyWith(
      name: 'Laser focus',
      updatedAt: DateTime(2024, 1, 2),
    );
    await upsertLabel(db, renamed);

    final second = await db.getLabelDefinitionById(focusLabel.id);
    expect(second?.name, 'Laser focus');
  });

  test('private label hidden from getLabelDefinitionById without config flag',
      () async {
    final publicLabel = buildLabel('label-public', 'Visible', '#222222')
        .copyWith(private: false);
    await upsertLabel(db, publicLabel);

    // Public label is visible
    final found = await db.getLabelDefinitionById(publicLabel.id);
    expect(found?.name, 'Visible');

    // Mark label as private
    final privateVersion = publicLabel.copyWith(
      private: true,
      updatedAt: DateTime(2024, 1, 2),
    );
    await upsertLabel(db, privateVersion);

    // Without the 'private' config flag enabled, private labels are hidden
    final hidden = await db.getLabelDefinitionById(publicLabel.id);
    expect(hidden, isNull);

    // Enable private config flag so private labels become visible
    await db.upsertConfigFlag(
      const ConfigFlag(
        name: 'private',
        description: 'Show private',
        status: true,
      ),
    );

    final visible = await db.getLabelDefinitionById(publicLabel.id);
    expect(visible?.private, isTrue);
  });
}
