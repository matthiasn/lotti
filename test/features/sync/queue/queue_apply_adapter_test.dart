import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/queue/inbound_worker.dart';
import 'package:lotti/features/sync/queue/queue_apply_adapter.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import 'queue_apply_adapter_test_helpers.dart';

void main() {
  late AdapterMockSyncEventProcessor processor;
  late JournalDb journalDb;
  late MockDomainLogger logging;
  late MockRoom room;

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(MockEvent());
    registerFallbackValue(AdapterMockPreparedSyncEvent());
  });

  setUp(() {
    processor = AdapterMockSyncEventProcessor();
    journalDb = JournalDb(inMemoryDatabase: true);
    logging = MockDomainLogger();
    room = MockRoom();
    when(() => room.id).thenReturn('!r:example.org');
  });

  tearDown(() async {
    await journalDb.close();
  });

  QueueApplyAdapter build() => QueueApplyAdapter(
    processor: processor,
    journalDb: journalDb,
    logging: logging,
  );

  glados.Glados(
    glados.any.adapterScenario,
    glados.ExploreConfig(numRuns: 160),
  ).test(
    'generated prepare/apply matrices classify outcomes with or without cache',
    (scenario) async {
      final localProcessor = AdapterMockSyncEventProcessor();
      final localJournalDb = JournalDb(inMemoryDatabase: true);
      final localLogging = MockDomainLogger();
      final localRoom = MockRoom();
      when(() => localRoom.id).thenReturn('!r:example.org');
      final entry = hBuildEntry(
        eventId: '\$generated-${scenario.slot}',
        roomId: '!r',
        originTsMs: scenario.slot + 1,
      );
      final prepared = AdapterMockPreparedSyncEvent();

      try {
        switch (scenario.prepareOutcome) {
          case GeneratedAdapterPrepareOutcome.ready:
            when(
              () => localProcessor.prepare(event: any(named: 'event')),
            ).thenAnswer((_) async => prepared);
            when(() => prepared.syncMessage).thenReturn(scenario.syncMessage());
            switch (scenario.applyOutcome) {
              case GeneratedAdapterApplyOutcome.applied:
                when(
                  () => localProcessor.apply(
                    prepared: prepared,
                    journalDb: localJournalDb,
                  ),
                ).thenAnswer((_) async => null);
              case GeneratedAdapterApplyOutcome.pendingDescriptor:
              case GeneratedAdapterApplyOutcome.pendingPath:
              case GeneratedAdapterApplyOutcome.retriableIo:
              case GeneratedAdapterApplyOutcome.retriableThrow:
                when(
                  () => localProcessor.apply(
                    prepared: prepared,
                    journalDb: localJournalDb,
                  ),
                ).thenThrow(scenario.applyException());
            }
          case GeneratedAdapterPrepareOutcome.nullPrepared:
            when(
              () => localProcessor.prepare(event: any(named: 'event')),
            ).thenAnswer((_) async => null);
          case GeneratedAdapterPrepareOutcome.pendingDescriptor:
          case GeneratedAdapterPrepareOutcome.pendingPath:
          case GeneratedAdapterPrepareOutcome.retriableIo:
          case GeneratedAdapterPrepareOutcome.permanentThrow:
            when(
              () => localProcessor.prepare(event: any(named: 'event')),
            ).thenThrow(scenario.prepareException());
        }

        final adapter = QueueApplyAdapter(
          processor: localProcessor,
          journalDb: localJournalDb,
          logging: localLogging,
        );
        if (scenario.usePrepareBatch) {
          await adapter.bindPrepareBatch()([entry], localRoom);
        }

        final outcome = await adapter.bind()(entry, localRoom);
        expect(outcome, scenario.expectedOutcome, reason: '$scenario');
        verify(
          () => localProcessor.prepare(event: any(named: 'event')),
        ).called(1);
        if (scenario.prepareReady) {
          verify(
            () => localProcessor.apply(
              prepared: prepared,
              journalDb: localJournalDb,
            ),
          ).called(1);
        } else {
          verifyNever(
            () => localProcessor.apply(
              prepared: any(named: 'prepared'),
              journalDb: localJournalDb,
            ),
          );
        }
      } finally {
        await localJournalDb.close();
      }
    },
    tags: 'glados',
  );

  test('undeserialisable rawJson maps to permanentSkip', () async {
    const entry = InboundQueueEntry(
      queueId: 1,
      eventId: r'$bad',
      roomId: '!r',
      originTs: 1,
      producer: InboundEventProducer.live,
      enqueuedAt: 1,
      attempts: 0,
      leaseUntil: 0,
      rawJson: 'not-json',
    );
    final outcome = await build().bind()(entry, room);
    expect(outcome, ApplyOutcome.permanentSkip);
  });

  test('prepare returning null maps to permanentSkip', () async {
    final entry = hBuildEntry(
      eventId: r'$none',
      roomId: '!r',
      originTsMs: 1,
    );
    when(
      () => processor.prepare(event: any(named: 'event')),
    ).thenAnswer((_) async => null);
    final outcome = await build().bind()(entry, room);
    expect(outcome, ApplyOutcome.permanentSkip);
    verifyNever(
      () => processor.apply(
        prepared: any(named: 'prepared'),
        journalDb: journalDb,
      ),
    );
  });

  test(
    'FileSystemException during prepare maps to retriable',
    () async {
      final entry = hBuildEntry(
        eventId: r'$fs',
        roomId: '!r',
        originTsMs: 1,
      );
      when(
        () => processor.prepare(event: any(named: 'event')),
      ).thenThrow(const FileSystemException('down'));
      final outcome = await build().bind()(entry, room);
      expect(outcome, ApplyOutcome.retriable);
    },
  );

  test('successful prepare + apply maps to applied', () async {
    final entry = hBuildEntry(
      eventId: r'$ok',
      roomId: '!r',
      originTsMs: 1,
    );
    final prepared = AdapterMockPreparedSyncEvent();
    when(
      () => processor.prepare(event: any(named: 'event')),
    ).thenAnswer((_) async => prepared);
    when(
      () => processor.apply(
        prepared: any(named: 'prepared'),
        journalDb: journalDb,
      ),
    ).thenAnswer((_) async => null);

    final outcome = await build().bind()(entry, room);
    expect(outcome, ApplyOutcome.applied);
    verify(
      () => processor.apply(
        prepared: prepared,
        journalDb: journalDb,
      ),
    ).called(1);
  });

  test('FileSystemException during apply maps to retriable', () async {
    final entry = hBuildEntry(
      eventId: r'$fsApply',
      roomId: '!r',
      originTsMs: 1,
    );
    final prepared = AdapterMockPreparedSyncEvent();
    when(
      () => processor.prepare(event: any(named: 'event')),
    ).thenAnswer((_) async => prepared);
    when(
      () => processor.apply(
        prepared: any(named: 'prepared'),
        journalDb: journalDb,
      ),
    ).thenThrow(const FileSystemException('disk full'));

    final outcome = await build().bind()(entry, room);
    expect(outcome, ApplyOutcome.retriable);
  });

  test(
    'generic exception during prepare maps to permanentSkip',
    () async {
      final entry = hBuildEntry(
        eventId: r'$preparePermanent',
        roomId: '!r',
        originTsMs: 1,
      );
      when(
        () => processor.prepare(event: any(named: 'event')),
      ).thenThrow(StateError('logic bug'));

      final outcome = await build().bind()(entry, room);
      expect(outcome, ApplyOutcome.permanentSkip);
      verify(
        () => logging.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      ).called(1);
    },
  );

  group('pendingAttachment classification', () {
    test(
      'prepare throwing the "attachment descriptor not yet available" '
      'FileSystemException maps to pendingAttachment so the queue '
      'backs off on the human-scale ladder instead of the sub-second '
      'retriable curve',
      () async {
        final entry = hBuildEntry(
          eventId: r'$waitsForDescriptor',
          roomId: '!r',
          originTsMs: 1,
        );
        when(
          () => processor.prepare(event: any(named: 'event')),
        ).thenThrow(
          const FileSystemException('attachment descriptor not yet available'),
        );

        final outcome = await build().bind()(entry, room);
        expect(outcome, ApplyOutcome.pendingAttachment);
      },
    );

    test(
      'prepare throwing PathNotFoundException inside /audio/ maps to '
      'pendingAttachment — the standard signature for a sync event '
      'that arrived before its attachment JSON landed on disk',
      () async {
        final entry = hBuildEntry(
          eventId: r'$audioRace',
          roomId: '!r',
          originTsMs: 1,
        );
        when(
          () => processor.prepare(event: any(named: 'event')),
        ).thenThrow(
          const PathNotFoundException(
            '/Users/test/Documents/audio/2026-04-21/foo.m4a.json',
            OSError('No such file or directory', 2),
          ),
        );

        final outcome = await build().bind()(entry, room);
        expect(outcome, ApplyOutcome.pendingAttachment);
      },
    );

    test(
      'prepare throwing PathNotFoundException inside /agent_entities/ '
      'also maps to pendingAttachment so agent-entity payload races '
      'share the same long-ladder retry path',
      () async {
        final entry = hBuildEntry(
          eventId: r'$agentRace',
          roomId: '!r',
          originTsMs: 1,
        );
        when(
          () => processor.prepare(event: any(named: 'event')),
        ).thenThrow(
          const PathNotFoundException(
            '/Users/test/Documents/agent_entities/abc.json',
            OSError('No such file or directory', 2),
          ),
        );

        final outcome = await build().bind()(entry, room);
        expect(outcome, ApplyOutcome.pendingAttachment);
      },
    );

    test(
      'an unrelated FileSystemException (path outside attachment '
      'directories) stays retriable, not pendingAttachment — the '
      'classification must not accidentally promote every IO '
      'failure to the long retry ladder',
      () async {
        final entry = hBuildEntry(
          eventId: r'$genericIo',
          roomId: '!r',
          originTsMs: 1,
        );
        when(
          () => processor.prepare(event: any(named: 'event')),
        ).thenThrow(
          const FileSystemException(
            'unrelated disk error',
            '/tmp/something-else.log',
          ),
        );

        final outcome = await build().bind()(entry, room);
        expect(outcome, ApplyOutcome.retriable);
      },
    );

    test(
      'apply-step throwing "attachment descriptor not yet available" '
      'also maps to pendingAttachment so the decoded payload still '
      'waits for its JSON on the long ladder',
      () async {
        final entry = hBuildEntry(
          eventId: r'$applyWaitsForDescriptor',
          roomId: '!r',
          originTsMs: 1,
        );
        final prepared = AdapterMockPreparedSyncEvent();
        when(
          () => processor.prepare(event: any(named: 'event')),
        ).thenAnswer((_) async => prepared);
        when(
          () => processor.apply(
            prepared: prepared,
            journalDb: journalDb,
          ),
        ).thenThrow(
          const FileSystemException('attachment descriptor not yet available'),
        );

        final outcome = await build().bind()(entry, room);
        expect(outcome, ApplyOutcome.pendingAttachment);
      },
    );
  });

  group('batch-parallel prepare', () {
    test(
      'prepareBatch fans prepare out via Future.wait so the slowest '
      'entry — not the sum of all prepares — is the batch critical '
      'path',
      () async {
        final a = hBuildEntry(eventId: r'$a', roomId: '!r:x', originTsMs: 1);
        final b = hBuildEntry(eventId: r'$b', roomId: '!r:x', originTsMs: 2);
        final c = hBuildEntry(eventId: r'$c', roomId: '!r:x', originTsMs: 3);

        final prepared = AdapterMockPreparedSyncEvent();
        final allStarted = Completer<void>();
        final release = Completer<void>();
        var prepareCalls = 0;
        when(() => processor.prepare(event: any(named: 'event'))).thenAnswer((
          _,
        ) async {
          prepareCalls++;
          if (prepareCalls == 3) {
            allStarted.complete();
          }
          await release.future;
          return prepared;
        });

        final adapter = build();
        final prepareBatch = adapter.bindPrepareBatch()([a, b, c], room);
        await allStarted.future;
        expect(prepareCalls, 3);
        release.complete();
        await prepareBatch;
        verify(() => processor.prepare(event: any(named: 'event'))).called(3);
      },
    );

    test(
      'apply consumes the cached prepared payload so prepare runs '
      'exactly once when the caller invoked prepareBatch first',
      () async {
        final entry = hBuildEntry(
          eventId: r'$cached',
          roomId: '!r:x',
          originTsMs: 1,
        );

        final prepared = AdapterMockPreparedSyncEvent();
        when(
          () => processor.prepare(event: any(named: 'event')),
        ).thenAnswer((_) async => prepared);
        when(
          () => processor.apply(prepared: prepared, journalDb: journalDb),
        ).thenAnswer((_) async => null);

        final adapter = build();
        await adapter.bindPrepareBatch()([entry], room);
        final outcome = await adapter.bind()(entry, room);

        expect(outcome, ApplyOutcome.applied);
        // Exactly one prepare: batched ahead of time. No inline
        // re-prepare in the apply phase.
        verify(() => processor.prepare(event: any(named: 'event'))).called(1);
        verify(
          () => processor.apply(
            prepared: prepared,
            journalDb: journalDb,
          ),
        ).called(1);
      },
    );

    test(
      'apply falls back to inline prepare when the cached entry is '
      'missing — a prepareBatch that skipped an eventId must not '
      'silently drop its apply',
      () async {
        final batched = hBuildEntry(
          eventId: r'$batched',
          roomId: '!r:x',
          originTsMs: 1,
        );
        final late = hBuildEntry(
          eventId: r'$late',
          roomId: '!r:x',
          originTsMs: 2,
        );

        final prepared = AdapterMockPreparedSyncEvent();
        when(
          () => processor.prepare(event: any(named: 'event')),
        ).thenAnswer((_) async => prepared);
        when(
          () => processor.apply(prepared: prepared, journalDb: journalDb),
        ).thenAnswer((_) async => null);

        final adapter = build();
        // prepareBatch only covers `batched` — `late` has no cache
        // entry when apply runs.
        await adapter.bindPrepareBatch()([batched], room);

        final first = await adapter.bind()(batched, room);
        final second = await adapter.bind()(late, room);
        expect(first, ApplyOutcome.applied);
        expect(second, ApplyOutcome.applied);

        // Two prepare calls total: one batched, one inline fallback.
        verify(() => processor.prepare(event: any(named: 'event'))).called(2);
      },
    );

    test(
      'a cached terminal outcome from prepareBatch is surfaced by '
      'apply without re-preparing — e.g. pendingAttachment caught at '
      'prepare time must not trigger a second prepare during apply',
      () async {
        final entry = hBuildEntry(
          eventId: r'$pending',
          roomId: '!r:x',
          originTsMs: 1,
        );

        // Prepare throws the sentinel FileSystemException that the
        // adapter classifies as pendingAttachment.
        when(() => processor.prepare(event: any(named: 'event'))).thenThrow(
          const FileSystemException('attachment descriptor not yet available'),
        );

        final adapter = build();
        await adapter.bindPrepareBatch()([entry], room);
        final outcome = await adapter.bind()(entry, room);

        expect(outcome, ApplyOutcome.pendingAttachment);
        // Exactly one prepare: the batched one. Apply consumed the
        // cached terminal outcome instead of re-trying. No apply was
        // ever attempted — the stubbed `processor.apply` was never
        // configured, so calling it would have thrown.
        verify(() => processor.prepare(event: any(named: 'event'))).called(1);
      },
    );

    test(
      'prepareBatch with an empty entry list is a no-op — safe for '
      'a worker that happens to peek an empty batch',
      () async {
        await build().bindPrepareBatch()(const [], room);
        verifyNever(() => processor.prepare(event: any(named: 'event')));
      },
    );
  });
}
