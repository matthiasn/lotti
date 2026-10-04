import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/logic/persistence_update_ops.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fallbacks.dart';
import '../mocks/mocks.dart';
import '../test_data/test_data.dart';
import '../widget_test_utils.dart';

/// Mirror test for [PersistenceUpdateOps].
///
/// The update builders must look entities up via the journal DB but perform
/// the metadata refresh and the DB write through the injected facade, so test
/// subclasses overriding `updateMetadata`/`updateDbEntity` still intercept the
/// calls. These tests assert that routing and the not-found short circuits.
void main() {
  late MockPersistenceLogic logic;
  late PersistenceUpdateOps ops;
  late TestGetItMocks mocks;

  setUp(() async {
    registerAllFallbackValues();
    mocks = await setUpTestGetIt();
    logic = MockPersistenceLogic();
    ops = PersistenceUpdateOps(logic);

    when(
      () => logic.updateMetadata(
        any(),
        dateFrom: any(named: 'dateFrom'),
        dateTo: any(named: 'dateTo'),
        categoryId: any(named: 'categoryId'),
        clearCategoryId: any(named: 'clearCategoryId'),
        deletedAt: any(named: 'deletedAt'),
        labelIds: any(named: 'labelIds'),
        clearLabelIds: any(named: 'clearLabelIds'),
      ),
    ).thenAnswer((invocation) async {
      return invocation.positionalArguments.first as Metadata;
    });
    when(
      () => logic.updateDbEntity(
        any(),
        linkedId: any(named: 'linkedId'),
        enqueueSync: any(named: 'enqueueSync'),
        beforeNotify: any(named: 'beforeNotify'),
        precondition: any(named: 'precondition'),
      ),
    ).thenAnswer((_) async => true);
  });

  tearDown(tearDownTestGetIt);

  test(
    'updateJournalEntryImpl refreshes metadata and writes via the facade',
    () async {
      when(
        () => mocks.journalDb.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);

      final result = await ops.updateJournalEntryImpl(
        journalEntityId: testTextEntry.meta.id,
        entryText: const EntryText(plainText: 'updated'),
      );

      expect(result, isTrue);
      verify(
        () => logic.updateMetadata(
          testTextEntry.meta,
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
        ),
      ).called(1);
      final written =
          verify(
                () => logic.updateDbEntity(captureAny()),
              ).captured.single
              as JournalEntry;
      expect(written.entryText?.plainText, 'updated');
    },
  );

  group('updateJournalEntityTextImpl flag handling', () {
    for (final (label, entity) in <(String, JournalEntity)>[
      ('audio', testAudioEntry),
      ('image', testImageEntry),
    ]) {
      for (final (flag, expected) in [
        (EntryFlag.import, EntryFlag.none),
        (EntryFlag.followUpNeeded, EntryFlag.followUpNeeded),
        (null, null),
      ]) {
        test('$label entry with flag $flag is written with flag $expected '
            '(editing text clears only the import marker)', () async {
          final flagged = entity.copyWith(
            meta: entity.meta.copyWith(flag: flag),
          );
          when(
            () => mocks.journalDb.journalEntityById(flagged.meta.id),
          ).thenAnswer((_) async => flagged);

          final result = await ops.updateJournalEntityTextImpl(
            flagged.meta.id,
            const EntryText(plainText: 'Penguins waddled to the shore.'),
            DateTime(2024, 3, 15, 10),
          );

          expect(result, isTrue);
          final written =
              verify(
                    () => logic.updateDbEntity(captureAny()),
                  ).captured.single
                  as JournalEntity;
          expect(written.meta.flag, expected);
          expect(
            written.entryText?.plainText,
            'Penguins waddled to the shore.',
          );
        });
      }
    }
  });

  test('updateJournalEntryImpl returns false when no fields change', () async {
    final result = await ops.updateJournalEntryImpl(
      journalEntityId: testTextEntry.meta.id,
    );

    expect(result, isFalse);
    verifyNever(
      () => logic.updateDbEntity(
        any(),
        linkedId: any(named: 'linkedId'),
        enqueueSync: any(named: 'enqueueSync'),
        beforeNotify: any(named: 'beforeNotify'),
      ),
    );
  });

  test(
    'updateTaskImpl writes the task with a priority-column beforeNotify hook',
    () async {
      final task = testTask;
      when(
        () => mocks.journalDb.journalEntityById(task.meta.id),
      ).thenAnswer((_) async => task);
      when(
        () => mocks.journalDb.updateTaskPriorityColumn(
          id: any(named: 'id'),
          priority: any(named: 'priority'),
          rank: any(named: 'rank'),
        ),
      ).thenAnswer((_) async => 1);

      final next = task.data.priority == TaskPriority.p1High
          ? TaskPriority.p3Low
          : TaskPriority.p1High;

      final written = await ops.updateTaskImpl(
        journalEntityId: task.meta.id,
        change: (stored) => stored.copyWith(priority: next),
      );

      expect(written?.data.priority, next);
      // The priority changed, so a beforeNotify hook must accompany the write,
      // and it writes the new priority's column values.
      final beforeNotify =
          verify(
                () => logic.updateDbEntity(
                  any(),
                  beforeNotify: captureAny(named: 'beforeNotify'),
                  precondition: any(named: 'precondition'),
                ),
              ).captured.single
              as Future<void> Function()?;
      expect(beforeNotify, isNotNull);
      verifyNever(
        () => mocks.journalDb.updateTaskPriorityColumn(
          id: any(named: 'id'),
          priority: any(named: 'priority'),
          rank: any(named: 'rank'),
        ),
      );
      await beforeNotify!();
      verify(
        () => mocks.journalDb.updateTaskPriorityColumn(
          id: task.meta.id,
          priority: next.short,
          rank: next.rank,
        ),
      ).called(1);
    },
  );

  test(
    'updateTaskImpl writes no priority column when the priority stays',
    () async {
      when(
        () => mocks.journalDb.journalEntityById(testTask.meta.id),
      ).thenAnswer((_) async => testTask);

      await ops.updateTaskImpl(
        journalEntityId: testTask.meta.id,
        change: (stored) => stored.copyWith(title: 'renamed'),
      );

      final beforeNotify = verify(
        () => logic.updateDbEntity(
          any(),
          beforeNotify: captureAny(named: 'beforeNotify'),
          precondition: any(named: 'precondition'),
        ),
      ).captured.single;
      expect(beforeNotify, isNull);
    },
  );

  test(
    'updateTaskImpl applies the change to the data as stored, so a field set '
    'there after the caller read the task is kept, and returns the task as '
    'written (TaskFieldWrites.tla, NoLostFieldEdit)',
    () async {
      // The caller read testTask; since then sync set the title and the
      // priority on the stored row.
      final stored = testTask.copyWith(
        data: testTask.data.copyWith(
          title: 'Set by sync',
          priority: TaskPriority.p0Urgent,
        ),
      );
      when(
        () => mocks.journalDb.journalEntityById(stored.meta.id),
      ).thenAnswer((_) async => stored);
      TaskData? handed;

      final result = await ops.updateTaskImpl(
        journalEntityId: stored.meta.id,
        change: (data) {
          handed = data;
          return data.copyWith(estimate: const Duration(minutes: 45));
        },
      );

      expect(handed, stored.data);
      final written =
          verify(
                () => logic.updateDbEntity(
                  captureAny(),
                  beforeNotify: any(named: 'beforeNotify'),
                  precondition: any(named: 'precondition'),
                ),
              ).captured.single
              as Task;
      expect(
        written.data,
        stored.data.copyWith(estimate: const Duration(minutes: 45)),
      );
      expect(written.entryText, stored.entryText);
      expect(result, written);
    },
  );

  test(
    'updateTaskImpl writes nothing and returns the stored task when the '
    'change leaves it as it is',
    () async {
      when(
        () => mocks.journalDb.journalEntityById(testTask.meta.id),
      ).thenAnswer((_) async => testTask);

      final result = await ops.updateTaskImpl(
        journalEntityId: testTask.meta.id,
        change: (stored) => stored.copyWith(title: stored.title),
        entryText: testTask.entryText,
      );

      expect(result, same(testTask));
      verifyNever(
        () => logic.updateDbEntity(
          any(),
          linkedId: any(named: 'linkedId'),
          enqueueSync: any(named: 'enqueueSync'),
          beforeNotify: any(named: 'beforeNotify'),
          precondition: any(named: 'precondition'),
        ),
      );
      verifyNever(
        () => logic.updateMetadata(
          any(),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
        ),
      );
    },
  );

  test('updateTaskImpl writes the entry text only when given', () async {
    final stored = testTask.copyWith(
      entryText: const EntryText(plainText: 'stored body'),
    );
    when(
      () => mocks.journalDb.journalEntityById(stored.meta.id),
    ).thenAnswer((_) async => stored);

    final withoutText = await ops.updateTaskImpl(
      journalEntityId: stored.meta.id,
      change: (data) => data.copyWith(title: 'renamed'),
    );
    final withText = await ops.updateTaskImpl(
      journalEntityId: stored.meta.id,
      change: (data) => data,
      entryText: const EntryText(plainText: 'edited body'),
    );

    expect(withoutText?.entryText?.plainText, 'stored body');
    expect(withoutText?.data.title, 'renamed');
    // Only the text changed, and that alone is written.
    expect(withText?.entryText?.plainText, 'edited body');
    expect(withText?.data, stored.data);
    verify(
      () => logic.updateDbEntity(
        any(),
        beforeNotify: any(named: 'beforeNotify'),
        precondition: any(named: 'precondition'),
      ),
    ).called(2);
  });

  test('updateTaskImpl asks onlyIf of the stored task and writes nothing '
      'when it refuses', () async {
    final stored = testTask.copyWith(
      meta: testTask.meta.copyWith(categoryId: 'moved-away'),
    );
    when(
      () => mocks.journalDb.journalEntityById(stored.meta.id),
    ).thenAnswer((_) async => stored);
    Task? asked;

    final result = await ops.updateTaskImpl(
      journalEntityId: stored.meta.id,
      change: (data) => data.copyWith(title: 'renamed'),
      onlyIf: (task) {
        asked = task;
        return task.meta.categoryId == 'allowed';
      },
    );

    expect(asked, stored);
    expect(result, stored);
    verifyNever(
      () => logic.updateDbEntity(
        any(),
        beforeNotify: any(named: 'beforeNotify'),
        precondition: any(named: 'precondition'),
      ),
    );
  });

  group('updateTaskImpl flushes the task agent when the task becomes done', () {
    final doneStatus = TaskStatus.done(
      id: 'status-done',
      createdAt: DateTime(2024, 3, 15, 10),
      utcOffset: 0,
    );
    late List<Set<String>> notified;

    setUp(() {
      notified = [];
      when(() => mocks.updateNotifications.notify(any())).thenAnswer((
        invocation,
      ) {
        notified.add(invocation.positionalArguments.single as Set<String>);
      });
    });

    Task storedWith(TaskStatus status) =>
        testTask.copyWith(data: testTask.data.copyWith(status: status));

    Future<void> markDone(Task stored) async {
      when(
        () => mocks.journalDb.journalEntityById(stored.meta.id),
      ).thenAnswer((_) async => stored);
      await ops.updateTaskImpl(
        journalEntityId: stored.meta.id,
        change: (data) => data.copyWith(status: doneStatus, title: 'renamed'),
      );
    }

    test('an open task marked done flushes once', () async {
      expect(testTask.data.status, isNot(isA<TaskDone>()));

      await markDone(testTask);

      expect(notified, [
        {wakeFlushNotification(testTask.meta.id)},
      ]);
    });

    test('a task that was already done does not flush again', () async {
      await markDone(storedWith(doneStatus));

      expect(notified, isEmpty);
    });

    test('an agent marking the task done does not wake itself', () async {
      await runZoned(
        () => markDone(testTask),
        zoneValues: {agentExecutionZoneKey: true},
      );

      expect(notified, isEmpty);
    });

    test('a refused write flushes nothing', () async {
      when(
        () => mocks.journalDb.journalEntityById(testTask.meta.id),
      ).thenAnswer((_) async => testTask);

      await ops.updateTaskImpl(
        journalEntityId: testTask.meta.id,
        change: (data) => data.copyWith(status: doneStatus),
        onlyIf: (_) => false,
      );

      expect(notified, isEmpty);
    });
  });

  group('updateTaskImpl returns null', () {
    Future<void> expectNothingWritten(Task? result) async {
      expect(result, isNull);
      verifyNever(
        () => logic.updateDbEntity(
          any(),
          linkedId: any(named: 'linkedId'),
          enqueueSync: any(named: 'enqueueSync'),
          beforeNotify: any(named: 'beforeNotify'),
          precondition: any(named: 'precondition'),
        ),
      );
    }

    test('when the task is missing', () async {
      when(
        () => mocks.journalDb.journalEntityById('missing'),
      ).thenAnswer((_) async => null);

      await expectNothingWritten(
        await ops.updateTaskImpl(
          journalEntityId: 'missing',
          change: (stored) => stored.copyWith(title: 'x'),
        ),
      );
    });

    test('when the entity is not a task', () async {
      when(
        () => mocks.journalDb.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);

      await expectNothingWritten(
        await ops.updateTaskImpl(
          journalEntityId: testTextEntry.meta.id,
          change: (stored) => stored.copyWith(title: 'x'),
        ),
      );
    });

    test('when the change throws', () async {
      when(
        () => mocks.journalDb.journalEntityById(testTask.meta.id),
      ).thenAnswer((_) async => testTask);

      await expectNothingWritten(
        await ops.updateTaskImpl(
          journalEntityId: testTask.meta.id,
          change: (_) => throw StateError('boom'),
        ),
      );
    });

    test('when the write is not applied and the row did not move', () async {
      when(
        () => mocks.journalDb.journalEntityById(testTask.meta.id),
      ).thenAnswer((_) async => testTask);
      when(
        () => logic.updateDbEntity(
          any(),
          linkedId: any(named: 'linkedId'),
          enqueueSync: any(named: 'enqueueSync'),
          beforeNotify: any(named: 'beforeNotify'),
          precondition: any(named: 'precondition'),
        ),
      ).thenAnswer((_) async => false);

      final result = await ops.updateTaskImpl(
        journalEntityId: testTask.meta.id,
        change: (stored) => stored.copyWith(title: 'x'),
      );

      expect(result, isNull);
    });
  });

  test(
    'updateTaskImpl keeps the checklists the stored task lists, whatever the '
    "caller's copy says — a screen saving a status from a copy read before a "
    'checklist was added must not drop it (ChecklistMembership.tla)',
    () async {
      final stored = testTask.copyWith(
        data: testTask.data.copyWith(checklistIds: ['kept', 'added-later']),
      );
      when(
        () => mocks.journalDb.journalEntityById(stored.meta.id),
      ).thenAnswer((_) async => stored);

      final result = await ops.updateTaskImpl(
        journalEntityId: stored.meta.id,
        change: (data) => data.copyWith(
          checklistIds: ['kept'],
          title: 'renamed',
        ),
      );

      expect(result?.data.checklistIds, ['kept', 'added-later']);
      final written =
          verify(
                () => logic.updateDbEntity(
                  captureAny(),
                  beforeNotify: any(named: 'beforeNotify'),
                  precondition: any(named: 'precondition'),
                ),
              ).captured.single
              as Task;
      expect(written.data.title, 'renamed');
      expect(written.data.checklistIds, ['kept', 'added-later']);
    },
  );

  test(
    'updateTaskImpl keeps the stored record of applied agent changes — the '
    "screen's copy read before a change was applied must not let that "
    'change apply again over the user restoring its field (ADR 0098)',
    () async {
      final stored = testTask.copyWith(
        data: testTask.data.copyWith(appliedChangeEffects: {'set-1:0'}),
      );
      when(
        () => mocks.journalDb.journalEntityById(stored.meta.id),
      ).thenAnswer((_) async => stored);

      await ops.updateTaskImpl(
        journalEntityId: stored.meta.id,
        change: (data) =>
            data.copyWith(title: 'restored', appliedChangeEffects: null),
      );

      final written =
          verify(
                () => logic.updateDbEntity(
                  captureAny(),
                  beforeNotify: any(named: 'beforeNotify'),
                  precondition: any(named: 'precondition'),
                ),
              ).captured.single
              as Task;
      expect(written.data.title, 'restored');
      expect(written.data.appliedChangeEffects, {'set-1:0'});
    },
  );

  test(
    'updateTaskImpl builds a refused write again on the row stored meanwhile',
    () async {
      final first = testTask.copyWith(
        data: testTask.data.copyWith(checklistIds: const []),
      );
      final synced = testTask.copyWith(
        meta: testTask.meta.copyWith(
          vectorClock: const VectorClock({'peer': 1}),
        ),
        data: testTask.data.copyWith(
          checklistIds: ['synced'],
          priority: TaskPriority.p0Urgent,
        ),
      );
      final reads = [first, synced];
      when(
        () => mocks.journalDb.journalEntityById(testTask.meta.id),
      ).thenAnswer((_) async => reads.removeAt(0));
      final results = [false, true];
      when(
        () => logic.updateDbEntity(
          any(),
          linkedId: any(named: 'linkedId'),
          enqueueSync: any(named: 'enqueueSync'),
          beforeNotify: any(named: 'beforeNotify'),
          precondition: any(named: 'precondition'),
        ),
      ).thenAnswer((_) async => results.removeAt(0));

      final result = await ops.updateTaskImpl(
        journalEntityId: testTask.meta.id,
        change: (data) => data.copyWith(title: 'renamed'),
      );

      final written = verify(
        () => logic.updateDbEntity(
          captureAny(),
          beforeNotify: any(named: 'beforeNotify'),
          precondition: any(named: 'precondition'),
        ),
      ).captured.cast<Task>();
      expect(written.map((t) => t.data.checklistIds), [
        const <String>[],
        ['synced'],
      ]);
      // The change is applied again to the synced data, so the priority
      // sync set is kept alongside the title, and the retried version is
      // the one returned.
      expect(written.last.data.priority, TaskPriority.p0Urgent);
      expect(written.last.data.title, 'renamed');
      expect(result, written.last);
    },
  );

  test('updateEventImpl returns false when the entity is missing', () async {
    when(
      () => mocks.journalDb.journalEntityById('missing'),
    ).thenAnswer((_) async => null);

    final ok = await ops.updateEventImpl(
      journalEntityId: 'missing',
      data: const EventData(
        title: 'e',
        status: EventStatus.tentative,
        stars: 0,
      ),
    );

    expect(ok, isFalse);
    verifyNever(
      () => logic.updateDbEntity(
        any(),
        linkedId: any(named: 'linkedId'),
        enqueueSync: any(named: 'enqueueSync'),
        beforeNotify: any(named: 'beforeNotify'),
      ),
    );
  });
}
