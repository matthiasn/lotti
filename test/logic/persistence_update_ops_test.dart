import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/logic/persistence_update_ops.dart';
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
        overrideComparison: any(named: 'overrideComparison'),
        beforeNotify: any(named: 'beforeNotify'),
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
        overrideComparison: any(named: 'overrideComparison'),
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

      final changed = task.data.copyWith(
        priority: task.data.priority == TaskPriority.p1High
            ? TaskPriority.p3Low
            : TaskPriority.p1High,
      );

      final ok = await ops.updateTaskImpl(
        journalEntityId: task.meta.id,
        taskData: changed,
      );

      expect(ok, isTrue);
      // The priority changed, so a beforeNotify hook must accompany the write.
      final beforeNotify =
          verify(
                () => logic.updateDbEntity(
                  any(),
                  beforeNotify: captureAny(named: 'beforeNotify'),
                ),
              ).captured.single
              as Future<void> Function()?;
      expect(beforeNotify, isNotNull);
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
        overrideComparison: any(named: 'overrideComparison'),
        beforeNotify: any(named: 'beforeNotify'),
      ),
    );
  });
}
