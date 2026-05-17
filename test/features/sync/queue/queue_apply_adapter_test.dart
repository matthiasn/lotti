import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/queue/inbound_worker.dart';
import 'package:lotti/features/sync/queue/queue_apply_adapter.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

// Local mock: the centralized `MockSyncEventProcessor` ships concrete
// default `prepare`/`apply` overrides, so `when(() => processor.prepare(
// event: any(named: 'event')))` would call the real method and leak the
// unconsumed matcher. This file stubs both via `when()`, so it needs the
// bare-Mock variant.
class _MockSyncEventProcessor extends Mock implements SyncEventProcessor {}

class _MockPreparedSyncEvent extends Mock implements PreparedSyncEvent {}

enum _GeneratedAdapterPrepareOutcome {
  ready,
  nullPrepared,
  pendingDescriptor,
  pendingPath,
  retriableIo,
  permanentThrow,
}

enum _GeneratedAdapterApplyOutcome {
  applied,
  pendingDescriptor,
  pendingPath,
  retriableIo,
  retriableThrow,
}

enum _GeneratedAdapterMessageKind {
  journalEntity,
  entryLink,
  themingSelection,
  backfillRequest,
}

class _GeneratedAdapterScenario {
  const _GeneratedAdapterScenario({
    required this.prepareOutcome,
    required this.applyOutcome,
    required this.messageKind,
    required this.usePrepareBatch,
    required this.slot,
  });

  final _GeneratedAdapterPrepareOutcome prepareOutcome;
  final _GeneratedAdapterApplyOutcome applyOutcome;
  final _GeneratedAdapterMessageKind messageKind;
  final bool usePrepareBatch;
  final int slot;

  bool get prepareReady =>
      prepareOutcome == _GeneratedAdapterPrepareOutcome.ready;

  ApplyOutcome get expectedOutcome {
    switch (prepareOutcome) {
      case _GeneratedAdapterPrepareOutcome.ready:
        return _expectedApplyOutcome;
      case _GeneratedAdapterPrepareOutcome.nullPrepared:
      case _GeneratedAdapterPrepareOutcome.permanentThrow:
        return ApplyOutcome.permanentSkip;
      case _GeneratedAdapterPrepareOutcome.pendingDescriptor:
      case _GeneratedAdapterPrepareOutcome.pendingPath:
        return ApplyOutcome.pendingAttachment;
      case _GeneratedAdapterPrepareOutcome.retriableIo:
        return ApplyOutcome.retriable;
    }
  }

  ApplyOutcome get _expectedApplyOutcome {
    switch (applyOutcome) {
      case _GeneratedAdapterApplyOutcome.applied:
        return ApplyOutcome.applied;
      case _GeneratedAdapterApplyOutcome.pendingDescriptor:
      case _GeneratedAdapterApplyOutcome.pendingPath:
        return ApplyOutcome.pendingAttachment;
      case _GeneratedAdapterApplyOutcome.retriableIo:
      case _GeneratedAdapterApplyOutcome.retriableThrow:
        return ApplyOutcome.retriable;
    }
  }

  Object prepareException() {
    switch (prepareOutcome) {
      case _GeneratedAdapterPrepareOutcome.pendingDescriptor:
        return const FileSystemException(
          'attachment descriptor not yet available',
        );
      case _GeneratedAdapterPrepareOutcome.pendingPath:
        return FileSystemException(
          'missing',
          '/agent_entities/generated-$slot.json',
        );
      case _GeneratedAdapterPrepareOutcome.retriableIo:
        return FileSystemException('disk busy', '/tmp/generated-$slot.json');
      case _GeneratedAdapterPrepareOutcome.permanentThrow:
        return StateError('generated prepare failure');
      case _GeneratedAdapterPrepareOutcome.ready:
      case _GeneratedAdapterPrepareOutcome.nullPrepared:
        throw StateError('prepare outcome has no exception: $prepareOutcome');
    }
  }

  Object applyException() {
    switch (applyOutcome) {
      case _GeneratedAdapterApplyOutcome.pendingDescriptor:
        return const FileSystemException(
          'attachment descriptor not yet available',
        );
      case _GeneratedAdapterApplyOutcome.pendingPath:
        return FileSystemException('missing', '/images/generated-$slot.jpg');
      case _GeneratedAdapterApplyOutcome.retriableIo:
        return FileSystemException('disk busy', '/tmp/generated-$slot.json');
      case _GeneratedAdapterApplyOutcome.retriableThrow:
        return StateError('generated apply failure');
      case _GeneratedAdapterApplyOutcome.applied:
        throw StateError('apply outcome has no exception: $applyOutcome');
    }
  }

  SyncMessage syncMessage() {
    switch (messageKind) {
      case _GeneratedAdapterMessageKind.journalEntity:
        return SyncMessage.journalEntity(
          id: 'entity-$slot',
          jsonPath: '/entities/$slot.json',
          vectorClock: null,
          status: SyncEntryStatus.initial,
        );
      case _GeneratedAdapterMessageKind.entryLink:
        return SyncMessage.entryLink(
          entryLink: EntryLink.basic(
            id: 'link-$slot',
            fromId: 'from-$slot',
            toId: 'to-$slot',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          ),
          status: SyncEntryStatus.initial,
        );
      case _GeneratedAdapterMessageKind.themingSelection:
        return SyncMessage.themingSelection(
          lightThemeName: 'light-$slot',
          darkThemeName: 'dark-$slot',
          themeMode: 'system',
          updatedAt: slot,
          status: SyncEntryStatus.update,
        );
      case _GeneratedAdapterMessageKind.backfillRequest:
        return SyncMessage.backfillRequest(
          entries: const <BackfillRequestEntry>[],
          requesterId: 'host-$slot',
        );
    }
  }

  @override
  String toString() {
    return '_GeneratedAdapterScenario('
        'prepareOutcome: $prepareOutcome, '
        'applyOutcome: $applyOutcome, '
        'messageKind: $messageKind, '
        'usePrepareBatch: $usePrepareBatch, '
        'slot: $slot'
        ')';
  }
}

extension _AnyGeneratedAdapterScenario on glados.Any {
  glados.Generator<_GeneratedAdapterPrepareOutcome> get adapterPrepareOutcome =>
      glados.AnyUtils(this).choose(_GeneratedAdapterPrepareOutcome.values);

  glados.Generator<_GeneratedAdapterApplyOutcome> get adapterApplyOutcome =>
      glados.AnyUtils(this).choose(_GeneratedAdapterApplyOutcome.values);

  glados.Generator<_GeneratedAdapterMessageKind> get adapterMessageKind =>
      glados.AnyUtils(this).choose(_GeneratedAdapterMessageKind.values);

  glados.Generator<_GeneratedAdapterScenario> get adapterScenario =>
      glados.CombinableAny(this).combine5(
        adapterPrepareOutcome,
        adapterApplyOutcome,
        adapterMessageKind,
        glados.IntAnys(this).intInRange(0, 2),
        glados.IntAnys(this).intInRange(0, 8),
        (
          _GeneratedAdapterPrepareOutcome prepareOutcome,
          _GeneratedAdapterApplyOutcome applyOutcome,
          _GeneratedAdapterMessageKind messageKind,
          int usePrepareBatchSlot,
          int slot,
        ) => _GeneratedAdapterScenario(
          prepareOutcome: prepareOutcome,
          applyOutcome: applyOutcome,
          messageKind: messageKind,
          usePrepareBatch: usePrepareBatchSlot == 1,
          slot: slot,
        ),
      );
}

InboundQueueEntry _buildEntry({
  required String eventId,
  required String roomId,
  required int originTsMs,
}) {
  final content = <String, dynamic>{'msgtype': syncMessageType};
  final json = <String, dynamic>{
    'event_id': eventId,
    'room_id': roomId,
    'origin_server_ts': originTsMs,
    'type': EventTypes.Message,
    'sender': '@tester:example.org',
    'content': content,
  };
  return InboundQueueEntry(
    queueId: 1,
    eventId: eventId,
    roomId: roomId,
    originTs: originTsMs,
    producer: InboundEventProducer.live,
    enqueuedAt: originTsMs,
    attempts: 0,
    leaseUntil: 0,
    rawJson: jsonEncode(json),
  );
}

void main() {
  late _MockSyncEventProcessor processor;
  late JournalDb journalDb;
  late MockLoggingService logging;
  late MockRoom room;

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(MockEvent());
    registerFallbackValue(_MockPreparedSyncEvent());
  });

  setUp(() {
    processor = _MockSyncEventProcessor();
    journalDb = JournalDb(inMemoryDatabase: true);
    logging = MockLoggingService();
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
      final localProcessor = _MockSyncEventProcessor();
      final localJournalDb = JournalDb(inMemoryDatabase: true);
      final localLogging = MockLoggingService();
      final localRoom = MockRoom();
      when(() => localRoom.id).thenReturn('!r:example.org');
      final entry = _buildEntry(
        eventId: '\$generated-${scenario.slot}',
        roomId: '!r',
        originTsMs: scenario.slot + 1,
      );
      final prepared = _MockPreparedSyncEvent();

      try {
        switch (scenario.prepareOutcome) {
          case _GeneratedAdapterPrepareOutcome.ready:
            when(
              () => localProcessor.prepare(event: any(named: 'event')),
            ).thenAnswer((_) async => prepared);
            when(() => prepared.syncMessage).thenReturn(scenario.syncMessage());
            switch (scenario.applyOutcome) {
              case _GeneratedAdapterApplyOutcome.applied:
                when(
                  () => localProcessor.apply(
                    prepared: prepared,
                    journalDb: localJournalDb,
                  ),
                ).thenAnswer((_) async => null);
              case _GeneratedAdapterApplyOutcome.pendingDescriptor:
              case _GeneratedAdapterApplyOutcome.pendingPath:
              case _GeneratedAdapterApplyOutcome.retriableIo:
              case _GeneratedAdapterApplyOutcome.retriableThrow:
                when(
                  () => localProcessor.apply(
                    prepared: prepared,
                    journalDb: localJournalDb,
                  ),
                ).thenThrow(scenario.applyException());
            }
          case _GeneratedAdapterPrepareOutcome.nullPrepared:
            when(
              () => localProcessor.prepare(event: any(named: 'event')),
            ).thenAnswer((_) async => null);
          case _GeneratedAdapterPrepareOutcome.pendingDescriptor:
          case _GeneratedAdapterPrepareOutcome.pendingPath:
          case _GeneratedAdapterPrepareOutcome.retriableIo:
          case _GeneratedAdapterPrepareOutcome.permanentThrow:
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
    final entry = _buildEntry(
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
      final entry = _buildEntry(
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
    final entry = _buildEntry(
      eventId: r'$ok',
      roomId: '!r',
      originTsMs: 1,
    );
    final prepared = _MockPreparedSyncEvent();
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
    final entry = _buildEntry(
      eventId: r'$fsApply',
      roomId: '!r',
      originTsMs: 1,
    );
    final prepared = _MockPreparedSyncEvent();
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
      final entry = _buildEntry(
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
        () => logging.captureException(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
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
        final entry = _buildEntry(
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
        final entry = _buildEntry(
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
        final entry = _buildEntry(
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
        final entry = _buildEntry(
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
        final entry = _buildEntry(
          eventId: r'$applyWaitsForDescriptor',
          roomId: '!r',
          originTsMs: 1,
        );
        final prepared = _MockPreparedSyncEvent();
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
        final a = _buildEntry(eventId: r'$a', roomId: '!r:x', originTsMs: 1);
        final b = _buildEntry(eventId: r'$b', roomId: '!r:x', originTsMs: 2);
        final c = _buildEntry(eventId: r'$c', roomId: '!r:x', originTsMs: 3);

        final prepared = _MockPreparedSyncEvent();
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
        final entry = _buildEntry(
          eventId: r'$cached',
          roomId: '!r:x',
          originTsMs: 1,
        );

        final prepared = _MockPreparedSyncEvent();
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
        final batched = _buildEntry(
          eventId: r'$batched',
          roomId: '!r:x',
          originTsMs: 1,
        );
        final late = _buildEntry(
          eventId: r'$late',
          roomId: '!r:x',
          originTsMs: 2,
        );

        final prepared = _MockPreparedSyncEvent();
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
        final entry = _buildEntry(
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

  group('writesJournalDb classifies sync payload families', () {
    // These tests pin the per-variant outcome of the adapter's
    // wrap-or-bypass decision. The wrap path costs the journal writer
    // lock for the whole `apply` duration; misclassifying a
    // non-journal payload as wrapped silently re-introduces the
    // reader-stall regression we just fixed (super-slow log showed
    // hundreds of ms of queued reads behind unrelated sync applies).
    // Misclassifying a journal-writing payload as bypass would split
    // the journal upsert + linked_entries writes across two
    // transactions and break atomicity on a mid-apply crash. Locking
    // the table down per-variant means a future `SyncMessage` factory
    // without a corresponding case here will fail compilation rather
    // than silently inheriting a wrong default.

    bool wraps(SyncMessage message) =>
        QueueApplyAdapter.writesJournalDbForTesting(message);

    test('SyncJournalEntity bypasses outer wrap (owns its own narrow tx)', () {
      const message = SyncMessage.journalEntity(
        id: 'entity-id',
        jsonPath: '/entity.json',
        vectorClock: null,
        status: SyncEntryStatus.initial,
      );
      expect(wraps(message), isFalse);
    });

    test('SyncEntryLink wraps — writes to linked_entries (JournalDb)', () {
      final link = EntryLink.basic(
        id: 'link-id',
        fromId: 'from',
        toId: 'to',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );
      final message = SyncMessage.entryLink(
        entryLink: link,
        status: SyncEntryStatus.initial,
      );
      expect(wraps(message), isTrue);
    });

    test(
      'SyncEntityDefinition wraps — writes to *_definitions (JournalDb)',
      () {
        final message = SyncMessage.entityDefinition(
          entityDefinition: measurableWater,
          status: SyncEntryStatus.initial,
        );
        expect(wraps(message), isTrue);
      },
    );

    test('SyncAiConfig bypasses outer wrap (writes to ai_config_db)', () {
      final message = SyncMessage.aiConfig(
        aiConfig: fallbackAiConfig,
        status: SyncEntryStatus.initial,
      );
      expect(wraps(message), isFalse);
    });

    test('SyncAiConfigDelete bypasses outer wrap (ai_config_db)', () {
      const message = SyncMessage.aiConfigDelete(id: 'cfg-id');
      expect(wraps(message), isFalse);
    });

    test('SyncThemingSelection bypasses outer wrap (settings_db)', () {
      const message = SyncMessage.themingSelection(
        lightThemeName: 'light',
        darkThemeName: 'dark',
        themeMode: 'system',
        updatedAt: 1,
        status: SyncEntryStatus.initial,
      );
      expect(wraps(message), isFalse);
    });

    test('SyncBackfillRequest wraps conservatively', () {
      const message = SyncMessage.backfillRequest(
        entries: <BackfillRequestEntry>[],
        requesterId: 'host-1',
      );
      expect(wraps(message), isTrue);
    });

    test('SyncBackfillResponse wraps conservatively', () {
      const message = SyncMessage.backfillResponse(
        hostId: 'host-1',
        counter: 1,
        deleted: false,
        unresolvable: false,
      );
      expect(wraps(message), isTrue);
    });

    test('SyncAgentEntity bypasses outer wrap (agent_db)', () {
      const message = SyncMessage.agentEntity(
        status: SyncEntryStatus.initial,
        jsonPath: '/agent_entities/a1.json',
      );
      expect(wraps(message), isFalse);
    });

    test('SyncAgentLink bypasses outer wrap (agent_db)', () {
      const message = SyncMessage.agentLink(
        status: SyncEntryStatus.initial,
        jsonPath: '/agent_links/l1.json',
      );
      expect(wraps(message), isFalse);
    });

    test('SyncAgentBundle bypasses outer wrap (agent_db loop)', () {
      const message = SyncMessage.agentBundle(
        agentId: 'agent-1',
        wakeRunKey: 'wake-1',
      );
      expect(wraps(message), isFalse);
    });

    test('SyncNotification bypasses outer wrap (notifications_db)', () {
      const message = SyncMessage.notification(
        id: 'notification-id',
        jsonPath: '/notifications/notification-id.json',
        vectorClock: VectorClock({'host-1': 1}),
        originatingHostId: 'host-1',
      );
      expect(wraps(message), isFalse);
    });

    test(
      'SyncNotificationStateUpdate bypasses outer wrap (notifications_db)',
      () {
        const message = SyncMessage.notificationStateUpdate(
          id: 'notification-id',
          vectorClock: VectorClock({'host-1': 1}),
          originatingHostId: 'host-1',
        );
        expect(wraps(message), isFalse);
      },
    );

    test('SyncOutboxBundle wraps — unpacks into journal/linked_entries', () {
      const message = SyncMessage.outboxBundle(
        children: <SyncMessage>[],
      );
      expect(wraps(message), isTrue);
    });
  });

  group('apply respects the writesJournalDb classifier', () {
    test(
      'a journalEntity-shaped payload bypasses the outer transaction wrap '
      'so cross-DB awaits inside `apply` (sync-sequence log, pre-write '
      'reads) do not hold the journal writer lock',
      () async {
        final entry = _buildEntry(
          eventId: r'$bypass-wrap',
          roomId: '!r',
          originTsMs: 1,
        );
        final prepared = _MockPreparedSyncEvent();
        const message = SyncMessage.journalEntity(
          id: 'entity-id',
          jsonPath: '/entity.json',
          vectorClock: null,
          status: SyncEntryStatus.initial,
        );
        when(() => prepared.syncMessage).thenReturn(message);
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
        // The classifier introspected the prepared payload; the apply
        // still ran. We do not assert on transaction state directly
        // because the JournalDb is in-memory and a transaction wrap is
        // observable only via the writer lock — but the predicate test
        // group above pins the wrap/bypass decision per variant.
        verify(() => prepared.syncMessage).called(1);
      },
    );

    test(
      'a payload that throws when its syncMessage is read falls back to '
      'the safe wrapped path — the existing test mocks rely on this so '
      'the change cannot retroactively break them',
      () async {
        final entry = _buildEntry(
          eventId: r'$throws',
          roomId: '!r',
          originTsMs: 1,
        );
        final prepared = _MockPreparedSyncEvent();
        // No stub for syncMessage → mocktail throws on access.
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
      },
    );
  });
}
