import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/logic/write_on_stored.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fallbacks.dart';
import '../mocks/mocks.dart';
import '../test_data/test_data.dart';

void main() {
  late MockJournalDb journalDb;
  late MockPersistenceLogic persistenceLogic;

  final id = testTask.meta.id;

  Task storedAt(int counter, {String title = 'Stored'}) => testTask.copyWith(
    meta: testTask.meta.copyWith(vectorClock: VectorClock({'a': counter})),
    data: testTask.data.copyWith(title: title),
  );

  Task renamed(JournalEntity stored) {
    final task = stored as Task;
    return task.copyWith(
      meta: task.meta.copyWith(vectorClock: const VectorClock({'self': 9})),
      data: task.data.copyWith(title: '${task.data.title} (renamed)'),
    );
  }

  void stubWrites(List<bool?> answers) {
    final pending = [...answers];
    when(
      () => persistenceLogic.updateDbEntity(
        any(),
        linkedId: any(named: 'linkedId'),
        beforeNotify: any(named: 'beforeNotify'),
        precondition: any(named: 'precondition'),
      ),
    ).thenAnswer((_) async => pending.removeAt(0));
  }

  List<Object?> capture({
    bool entity = false,
    bool linkedId = false,
    bool beforeNotify = false,
    bool precondition = false,
  }) => verify(
    () => persistenceLogic.updateDbEntity(
      entity ? captureAny() : any(),
      linkedId: linkedId
          ? captureAny(named: 'linkedId')
          : any(named: 'linkedId'),
      beforeNotify: beforeNotify
          ? captureAny(named: 'beforeNotify')
          : any(named: 'beforeNotify'),
      precondition: precondition
          ? captureAny(named: 'precondition')
          : any(named: 'precondition'),
    ),
  ).captured;

  void verifyNoWrite() => verifyNever(
    () => persistenceLogic.updateDbEntity(
      any(),
      linkedId: any(named: 'linkedId'),
      beforeNotify: any(named: 'beforeNotify'),
      precondition: any(named: 'precondition'),
    ),
  );

  Future<bool> write({
    required Future<JournalEntity?> Function(JournalEntity stored) build,
    String? linkedId,
    Future<void> Function()? Function(JournalEntity, JournalEntity)?
    beforeNotify,
  }) => writeOnStored(
    journalDb: journalDb,
    persistenceLogic: persistenceLogic,
    id: id,
    build: build,
    linkedId: linkedId,
    beforeNotify: beforeNotify,
  );

  setUpAll(registerAllFallbackValues);

  setUp(() {
    journalDb = MockJournalDb();
    persistenceLogic = MockPersistenceLogic();
  });

  test('a missing entry is not stored and nothing is built', () async {
    when(() => journalDb.journalEntityById(id)).thenAnswer((_) async => null);
    var built = 0;

    final stored = await write(
      build: (entity) async {
        built++;
        return renamed(entity);
      },
    );

    expect(stored, isFalse);
    expect(built, 0);
    verifyNoWrite();
  });

  test(
    'a build with nothing to write counts as stored and writes nothing',
    () async {
      when(
        () => journalDb.journalEntityById(id),
      ).thenAnswer((_) async => storedAt(1));

      final stored = await write(build: (_) async => null);

      expect(stored, isTrue);
      verifyNoWrite();
    },
  );

  test('an applied write stores the version built on the stored row', () async {
    when(
      () => journalDb.journalEntityById(id),
    ).thenAnswer((_) async => storedAt(1));
    stubWrites([true]);

    final stored = await write(
      build: (entity) async => renamed(entity),
      linkedId: 'linked',
    );

    expect(stored, isTrue);
    final captured = capture(entity: true, linkedId: true);
    expect((captured[0]! as Task).data.title, 'Stored (renamed)');
    expect(captured[1], 'linked');
    verify(() => journalDb.journalEntityById(id)).called(1);
  });

  test('a refused write is built again on the row read afresh', () async {
    final reads = [storedAt(1), storedAt(2, title: 'Synced')];
    when(
      () => journalDb.journalEntityById(id),
    ).thenAnswer((_) async => reads.removeAt(0));
    stubWrites([false, true]);

    final stored = await write(build: (entity) async => renamed(entity));

    expect(stored, isTrue);
    expect(
      capture(entity: true).cast<Task>().map((task) => task.data.title),
      ['Stored (renamed)', 'Synced (renamed)'],
    );
  });

  test(
    'keeps building again for as long as the stored row keeps moving',
    () async {
      // Five versions stored while the change was being written, each
      // refusing the version built on the one before it: more than any
      // fixed attempt cap would allow.
      var counter = 0;
      when(
        () => journalDb.journalEntityById(id),
      ).thenAnswer((_) async => storedAt(++counter, title: 'v$counter'));
      stubWrites([false, false, false, false, false, true]);
      var built = 0;

      final stored = await write(
        build: (entity) async {
          built++;
          return renamed(entity);
        },
      );

      expect(stored, isTrue);
      expect(built, 6);
      expect(
        capture(entity: true).cast<Task>().map((task) => task.data.title),
        [for (var v = 1; v <= 6; v++) 'v$v (renamed)'],
      );
    },
  );

  test('stops when a refusal leaves the stored row where it was', () async {
    // Refused for another reason (a concurrent version recorded as a
    // conflict): the row read again carries the same clock, so building
    // again would only be refused again.
    when(
      () => journalDb.journalEntityById(id),
    ).thenAnswer((_) async => storedAt(1));
    stubWrites([false, true]);
    var built = 0;

    final stored = await write(
      build: (entity) async {
        built++;
        return renamed(entity);
      },
    );

    expect(stored, isFalse);
    expect(built, 1);
    expect(capture(entity: true), hasLength(1));
    verify(() => journalDb.journalEntityById(id)).called(2);
  });

  test('a write that fails (null) is not retried', () async {
    var counter = 0;
    when(
      () => journalDb.journalEntityById(id),
    ).thenAnswer((_) async => storedAt(++counter));
    stubWrites([null, true]);

    final stored = await write(build: (entity) async => renamed(entity));

    expect(stored, isFalse);
    expect(capture(entity: true), hasLength(1));
    verify(() => journalDb.journalEntityById(id)).called(1);
  });

  group('with a write of its own', () {
    test(
      'hands it the version and the precondition, and honours its answer',
      () async {
        var counter = 0;
        when(
          () => journalDb.journalEntityById(id),
        ).thenAnswer((_) async => storedAt(++counter, title: 'v$counter'));
        when(
          () => journalDb.isStoredVersion(any(), any()),
        ).thenAnswer((_) async => true);
        final answers = <bool?>[false, true];
        final written = <(String, bool)>[];

        final stored = await writeOnStored(
          journalDb: journalDb,
          persistenceLogic: persistenceLogic,
          id: id,
          build: (entity) async => renamed(entity),
          write: (updated, precondition) async {
            written.add(((updated as Task).data.title, await precondition()));
            return answers.removeAt(0);
          },
        );

        expect(stored, isTrue);
        expect(written, [('v1 (renamed)', true), ('v2 (renamed)', true)]);
        // Each precondition asks about the row its version was built on.
        verifyInOrder([
          () => journalDb.isStoredVersion(id, const VectorClock({'a': 1})),
          () => journalDb.isStoredVersion(id, const VectorClock({'a': 2})),
        ]);
        verifyNoWrite();
      },
    );

    test('its failure (null) is reported as not stored', () async {
      when(
        () => journalDb.journalEntityById(id),
      ).thenAnswer((_) async => storedAt(1));
      var writes = 0;

      final stored = await writeOnStored(
        journalDb: journalDb,
        persistenceLogic: persistenceLogic,
        id: id,
        build: (entity) async => renamed(entity),
        write: (_, _) async {
          writes++;
          return null;
        },
      );

      expect(stored, isFalse);
      expect(writes, 1);
      verifyNoWrite();
    });
  });

  test(
    "the precondition asks whether the read row's clock is still stored",
    () async {
      final row = storedAt(7);
      when(() => journalDb.journalEntityById(id)).thenAnswer((_) async => row);
      when(
        () => journalDb.isStoredVersion(any(), any()),
      ).thenAnswer((_) async => false);
      stubWrites([true]);

      await write(build: (entity) async => renamed(entity));

      final precondition =
          capture(precondition: true).single! as Future<bool> Function();
      expect(await precondition(), isFalse);
      // The clock of the row the version was built on, not the new one.
      verify(
        () => journalDb.isStoredVersion(id, const VectorClock({'a': 7})),
      ).called(1);
    },
  );

  test('the beforeNotify builder receives the stored row and the version, '
      'and its hook is handed to the write', () async {
    final row = storedAt(1);
    when(() => journalDb.journalEntityById(id)).thenAnswer((_) async => row);
    stubWrites([true]);
    final seen = <(JournalEntity, JournalEntity)>[];
    Future<void> hook() async {}

    await write(
      build: (entity) async => renamed(entity),
      beforeNotify: (stored, updated) {
        seen.add((stored, updated));
        return hook;
      },
    );

    expect(seen, hasLength(1));
    expect(seen.single.$1, row);
    expect((seen.single.$2 as Task).data.title, 'Stored (renamed)');
    expect(capture(beforeNotify: true).single, same(hook));
  });
}
