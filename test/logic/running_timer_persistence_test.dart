import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/running_timer_persistence.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fallbacks.dart';
import '../helpers/test_get_it.dart';
import '../mocks/mocks.dart';
import '../test_data/test_data.dart';

void main() {
  late MockPersistenceLogic persistenceLogic;
  late MockJournalDb journalDb;
  late MockEditorStateService editorStateService;

  final now = DateTime(2026, 9, 28, 14, 35);
  final timerId = testTextEntry.meta.id;

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    persistenceLogic = MockPersistenceLogic();
    editorStateService = MockEditorStateService();

    // What PersistenceLogic.updateMetadata does to the fields this write
    // sets: the new end time, and a new version stamped now.
    when(
      () => persistenceLogic.updateMetadata(
        any(),
        dateTo: any(named: 'dateTo'),
      ),
    ).thenAnswer((invocation) async {
      final meta = invocation.positionalArguments.first as Metadata;
      return meta.copyWith(
        dateTo: invocation.namedArguments[#dateTo] as DateTime,
        updatedAt: clock.now(),
      );
    });
    when(
      () => persistenceLogic.updateDbEntity(
        any(),
        linkedId: any(named: 'linkedId'),
        beforeNotify: any(named: 'beforeNotify'),
        precondition: any(named: 'precondition'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => editorStateService.rebaseDraft(
        id: any(named: 'id'),
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).thenAnswer((_) async {});

    final mocks = await setUpTestGetIt(
      additionalSetup: () => getIt
        ..registerSingleton<PersistenceLogic>(persistenceLogic)
        ..registerSingleton<EditorStateService>(editorStateService),
    );
    journalDb = mocks.journalDb;
    when(
      () => journalDb.journalEntityById(timerId),
    ).thenAnswer((_) async => testTextEntry);
  });

  tearDown(tearDownTestGetIt);

  /// Every entity handed to `updateDbEntity`, in order.
  List<JournalEntity> writtenEntities() => verify(
    () => persistenceLogic.updateDbEntity(
      captureAny(),
      linkedId: any(named: 'linkedId'),
      beforeNotify: any(named: 'beforeNotify'),
      precondition: any(named: 'precondition'),
    ),
  ).captured.cast<JournalEntity>();

  Future<void> persistAtNow(JournalEntity entry) => withClock(
    Clock.fixed(now),
    () => persistRunningTimerEnd(
      entry,
      persistenceLogic: persistenceLogic,
      journalDb: journalDb,
      editorStateService: editorStateService,
    ),
  );

  group('persistRunningTimerEnd', () {
    test('writes the end time on the entry as stored, never the text of '
        'the copy the timer was started with', () async {
      final startedWith = testTextEntry.copyWith(
        entryText: const EntryText(plainText: 'as the timer started'),
      );

      await persistAtNow(startedWith);

      final written = writtenEntities().single;
      expect(written.meta.dateTo, now);
      expect(written.meta.dateFrom, testTextEntry.meta.dateFrom);
      expect(written.entryText, testTextEntry.entryText);
    });

    test('a text save landing mid-write is built on, not put '
        'back', () async {
      final saved = testTextEntry.copyWith(
        entryText: const EntryText(plainText: 'saved meanwhile'),
        meta: testTextEntry.meta.copyWith(
          updatedAt: now.subtract(const Duration(seconds: 1)),
          vectorClock: const VectorClock({'device': 7}),
        ),
      );
      var reads = 0;
      when(
        () => journalDb.journalEntityById(timerId),
      ).thenAnswer((_) async => ++reads == 1 ? testTextEntry : saved);
      var writes = 0;
      when(
        () => persistenceLogic.updateDbEntity(
          any(),
          linkedId: any(named: 'linkedId'),
          beforeNotify: any(named: 'beforeNotify'),
          precondition: any(named: 'precondition'),
        ),
      ).thenAnswer((_) async => ++writes > 1);

      await persistAtNow(testTextEntry);

      final written = writtenEntities();
      expect(written, hasLength(2));
      expect(written.last.entryText, saved.entryText);
      expect(written.last.meta.dateTo, now);
      verify(
        () => editorStateService.rebaseDraft(
          id: timerId,
          from: saved.meta.updatedAt,
          to: now,
        ),
      ).called(1);
    });

    test('moves an unsaved draft onto the version it stores, with no '
        'editor open to follow the write', () async {
      await persistAtNow(testTextEntry);

      verify(
        () => editorStateService.rebaseDraft(
          id: timerId,
          from: testTextEntry.meta.updatedAt,
          to: now,
        ),
      ).called(1);
    });

    test('leaves the draft where it is when the write does not '
        'land', () async {
      when(
        () => persistenceLogic.updateDbEntity(
          any(),
          linkedId: any(named: 'linkedId'),
          beforeNotify: any(named: 'beforeNotify'),
          precondition: any(named: 'precondition'),
        ),
      ).thenAnswer((_) async => null);

      await persistAtNow(testTextEntry);

      expect(writtenEntities(), hasLength(1));
      verifyNever(
        () => editorStateService.rebaseDraft(
          id: any(named: 'id'),
          from: any(named: 'from'),
          to: any(named: 'to'),
        ),
      );
    });

    test('writes nothing for an entry that is not a text entry', () async {
      when(
        () => journalDb.journalEntityById(testTask.meta.id),
      ).thenAnswer((_) async => testTask);

      await persistAtNow(testTask);

      verifyNever(
        () => persistenceLogic.updateDbEntity(
          any(),
          linkedId: any(named: 'linkedId'),
          beforeNotify: any(named: 'beforeNotify'),
          precondition: any(named: 'precondition'),
        ),
      );
      verifyNever(
        () => editorStateService.rebaseDraft(
          id: any(named: 'id'),
          from: any(named: 'from'),
          to: any(named: 'to'),
        ),
      );
    });
  });

  group('buildPersistingTimeService', () {
    /// Runs [body] against a fresh service under a fake clock starting at
    /// [now], then stops the service outside the fake zone — awaiting the
    /// ticker's cancellation never settles inside it.
    Future<void> runService(
      void Function(TimeService service, FakeAsync async) body,
    ) async {
      final async = FakeAsync(initialTime: now);
      final service = buildPersistingTimeService();
      try {
        body(service, async);
      } finally {
        await service.stop();
        async.flushMicrotasks();
      }
    }

    test('moves the running entry end time to now every five '
        'minutes', () async {
      await runService((service, async) {
        async
          ..run((_) => unawaited(service.start(testTextEntry, testTask)))
          ..elapse(const Duration(minutes: 10));
      });

      expect(
        writtenEntities().map((entity) => (entity.id, entity.meta.dateTo)),
        [
          (timerId, now.add(const Duration(minutes: 5))),
          (timerId, now.add(const Duration(minutes: 10))),
        ],
      );
    });

    test(
      'a replaced timer gets its stop time written, text untouched',
      () async {
        await runService((service, async) {
          async
            ..run((_) => unawaited(service.start(testTextEntry, testTask)))
            ..elapse(const Duration(minutes: 2))
            ..run((_) => unawaited(service.start(testImageEntry, testTask)))
            ..flushMicrotasks();
        });

        final written = writtenEntities().single;
        expect(written.id, timerId);
        expect(written.meta.dateTo, now.add(const Duration(minutes: 2)));
        expect(written.entryText, testTextEntry.entryText);
      },
    );
  });
}
