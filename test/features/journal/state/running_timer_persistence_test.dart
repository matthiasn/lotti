import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/features/journal/state/running_timer_persistence.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../helpers/test_get_it.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

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
    when(
      () => editorStateService.draftWasStored(
        id: any(named: 'id'),
        draft: any(named: 'draft'),
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).thenAnswer((_) async {});
    when(() => editorStateService.draftOn(any(), any())).thenReturn(null);

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

    group('with an unsaved draft', () {
      const draft = r'[{"insert":"typed so far\n"}]';

      /// Holds [draft] as typed against the stored [version] of the entry.
      void holdDraftOn(DateTime version) => when(
        () => editorStateService.draftOn(timerId, version),
      ).thenReturn(draft);

      test('stores the draft as the text, with the end time', () async {
        holdDraftOn(testTextEntry.meta.updatedAt);

        await persistAtNow(testTextEntry);

        final written = writtenEntities().single;
        expect(written.entryText?.plainText, 'typed so far\n');
        expect(written.entryText?.markdown, 'typed so far\n');
        expect(written.entryText?.quill, draft);
        expect(written.meta.dateTo, now);
      });

      test('marks the stored draft saved, rather than moving it', () async {
        holdDraftOn(testTextEntry.meta.updatedAt);

        await persistAtNow(testTextEntry);

        verify(
          () => editorStateService.draftWasStored(
            id: timerId,
            draft: draft,
            from: testTextEntry.meta.updatedAt,
            to: now,
          ),
        ).called(1);
        verifyNever(
          () => editorStateService.rebaseDraft(
            id: any(named: 'id'),
            from: any(named: 'from'),
            to: any(named: 'to'),
          ),
        );
      });

      test('keeps the stored text when the draft was typed against a '
          'version sync has replaced', () async {
        holdDraftOn(
          testTextEntry.meta.updatedAt.subtract(
            const Duration(minutes: 1),
          ),
        );

        await persistAtNow(testTextEntry);

        expect(writtenEntities().single.entryText, testTextEntry.entryText);
        verifyNever(
          () => editorStateService.draftWasStored(
            id: any(named: 'id'),
            draft: any(named: 'draft'),
            from: any(named: 'from'),
            to: any(named: 'to'),
          ),
        );
      });

      test('a rebuilt write takes the draft on the version it is rebuilt '
          'on', () async {
        final synced = testTextEntry.copyWith(
          entryText: const EntryText(plainText: 'synced meanwhile'),
          meta: testTextEntry.meta.copyWith(
            updatedAt: now.subtract(const Duration(seconds: 1)),
            vectorClock: const VectorClock({'device': 7}),
          ),
        );
        var reads = 0;
        when(
          () => journalDb.journalEntityById(timerId),
        ).thenAnswer((_) async => ++reads == 1 ? testTextEntry : synced);
        var writes = 0;
        when(
          () => persistenceLogic.updateDbEntity(
            any(),
            linkedId: any(named: 'linkedId'),
            beforeNotify: any(named: 'beforeNotify'),
            precondition: any(named: 'precondition'),
          ),
        ).thenAnswer((_) async => ++writes > 1);
        // The draft was typed against the first version only.
        holdDraftOn(testTextEntry.meta.updatedAt);

        await persistAtNow(testTextEntry);

        final written = writtenEntities();
        expect(written.first.entryText?.quill, draft);
        expect(written.last.entryText, synced.entryText);
        verify(
          () => editorStateService.rebaseDraft(
            id: timerId,
            from: synced.meta.updatedAt,
            to: now,
          ),
        ).called(1);
      });

      test('the draft is not marked saved when the write does not '
          'land', () async {
        holdDraftOn(testTextEntry.meta.updatedAt);
        when(
          () => persistenceLogic.updateDbEntity(
            any(),
            linkedId: any(named: 'linkedId'),
            beforeNotify: any(named: 'beforeNotify'),
            precondition: any(named: 'precondition'),
          ),
        ).thenAnswer((_) async => null);

        await persistAtNow(testTextEntry);

        verifyNever(
          () => editorStateService.draftWasStored(
            id: any(named: 'id'),
            draft: any(named: 'draft'),
            from: any(named: 'from'),
            to: any(named: 'to'),
          ),
        );
      });
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
    /// [now], then stops the service without writing its end, so the writes
    /// left are the ones [body] caused.
    Future<void> runService(
      void Function(TimeService service, FakeAsync async) body,
    ) async {
      final async = FakeAsync(initialTime: now);
      final service = buildPersistingTimeService();
      try {
        body(service, async);
      } finally {
        async
          ..run((_) => unawaited(service.stop(persistEnd: false)))
          ..flushMicrotasks();
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

    test('stores the draft typed so far with each five-minute '
        'autosave', () async {
      const draft = r'[{"insert":"typed so far\n"}]';
      when(
        () => editorStateService.draftOn(timerId, testTextEntry.meta.updatedAt),
      ).thenReturn(draft);

      await runService((service, async) {
        async
          ..run((_) => unawaited(service.start(testTextEntry, testTask)))
          ..elapse(const Duration(minutes: 5));
      });

      final written = writtenEntities().single;
      expect(written.entryText?.quill, draft);
      expect(written.meta.dateTo, now.add(const Duration(minutes: 5)));
    });

    // Every stop writes the end: the sidebar's, a profile switch's and
    // quitting the app's (`specs/tla/RunningTimer.tla`, StopPersists).
    test('a stopped timer gets its stop time written', () async {
      await runService((service, async) {
        async
          ..run((_) => unawaited(service.start(testTextEntry, testTask)))
          ..elapse(const Duration(minutes: 7))
          ..run((_) => unawaited(service.stop()))
          ..flushMicrotasks();
      });

      expect(
        writtenEntities().map((entity) => (entity.id, entity.meta.dateTo)),
        [
          (timerId, now.add(const Duration(minutes: 5))),
          (timerId, now.add(const Duration(minutes: 7))),
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
